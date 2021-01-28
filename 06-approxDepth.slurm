#! /bin/bash

# LOAD MODULES, INSERT CODE, AND RUN YOUR PROGRAMS HERE

#	Some handy variables
#${SLURM_MEM_PER_CPU}
#${SLURM_MEM_PER_NODE}
#${SLURM_JOB_NAME}
#${SLURM_NTASKS}
#${SLURM_JOB_NUM_NODES}
#${SLURM_JOB_ID}
#${SLURM_ARRAY_JOB_ID}
#${SLURM_ARRAY_TASK_ID}
#${SLURM_ARRAY_TASK_COUNT}
#${SLURM_ARRAY_TASK_MIN}
#${SLURM_ARRAY_TASK_MAX}

if [ -n "$SLURM_JOB_ID" ] # basically, if this is managed by slurm vs being run locally
then
	if [ -n "$SLURM_JOB_NUM_NODES" ] && [ $SLURM_JOB_NUM_NODES -ne 1 ]
	then
		printf "%s\n" "This job is meant to be run with a single node" 1>&2
		exit 1
	elif [ -n "$SLURM_MEM_PER_CPU" ]
	then
		MEM_TASK_IN_MB=${SLURM_MEM_PER_CPU}
		MEM_JOB_IN_MB=$((${MEM_TASK_IN_MB}*${SLURM_NTASKS}))
		MEM_JOB_IN_GB=$((${MEM_JOB_IN_MB}/1024))
	elif [ -n "$SLURM_MEM_PER_NODE" ]
	then
		MEM_JOB_IN_MB=$((${SLURM_MEM_PER_NODE}*${SLURM_JOB_NUM_NODES}))
		MEM_JOB_IN_GB=$((${MEM_JOB_IN_MB}/1024))
		MEM_TASK_IN_MB=$(bc <<< "${MEM_JOB_IN_MB}/${SLURM_NTASKS}")
	else
		printf "%s\n" '$SLURM_MEM_PER_NODE and $SLURM_MEM_PER_CPU not specificed.' 1>&2
		exit 1
	fi
fi

#	move into the correct place
if [ -n "${SLURM_SUBMIT_DIR}" ]
then
	cd "$SLURM_SUBMIT_DIR"
else
	SLURM_SUBMIT_DIR=.
fi

# set SLURM_NTASKS
if [ -z "${SLURM_NTASKS}" ]
then
	SLURM_NTASKS=1
fi

#	manage job cleanup
cleanup()
{
	# cleanup tmp dir
	if [ -n $SLURM_JOB_ID ] && [ -e /tmp/${SLURM_JOB_ID} ]
	then
		rm -rf /tmp/${SLURM_JOB_ID} &> /dev/null
	elif [ -e /tmp/${$} ]
	then
		rm -rf /tmp/${$} &> /dev/null
	fi

	rm -rf /tmp/${SLURM_ARRAY_JOB_ID}-${SLURM_ARRAY_TASK_ID} &> /dev/null

	# move successful/failed job files to the correct place
	local SUCCESS_FAIL_STATUS_SUBDIR
	SUCCESS_FAIL_STATUS_SUBDIR="${1:=success}"

	mv ${SLURM_SUBMIT_DIR}/job_files/${SLURM_JOB_NAME}__${SLURM_ARRAY_JOB_ID}-${SLURM_ARRAY_TASK_ID}.{err,out} ${SLURM_SUBMIT_DIR}/job_files/${SUCCESS_FAIL_STATUS_SUBDIR} &> /dev/null
	mv ${SLURM_SUBMIT_DIR}/job_files/${SLURM_JOB_NAME}__${SLURM_JOB_ID}.{err,out} ${SLURM_SUBMIT_DIR}/job_files/${SUCCESS_FAIL_STATUS_SUBDIR} &> /dev/null
}

control_c()
{
	kill -SIGINT `jobs -p`
	cleanup "failed"
	exit 1
}

trap control_c SIGHUP SIGINT SIGTERM SIGQUIT

outOfTime()
{
	printf "%s\n" "This job ran out of time! SLURM sent signal USR1 and now we're trying to quite gracefully. (fingers crossed!)" 1>&2
	kill -SIGINT `jobs -p`

	printf "%s\n" "Now using 'cleanup' function with status 'success'. Be advised: this process ran out of time- you will need to run this again with more time (and/or more RAM)." 1>&2
	cleanup "success"

	exit 10 # SIGUSR1 == 10
}

trap outOfTime USR1


# 	load modules
module purge
module load samtools/1.11

# 	misc. functions
calcDepth()
{
	local RGN ALN_BAM TEMP_DEPTH TEMP_FAILS TEMP_EC

	RGN="${1}"
	ALN_BAM="${2}"
	TEMP_DEPTH="${3}"
	TEMP_FAILS="${4}"

	samtools depth \
		-r "${RGN}" \
		 "${ALN_BAM}" \
		 > "${TEMP_DEPTH}"
	
	TEMP_EC="${?}"
	printf "%s\n" "done (calcDepth ${RGN})" 1>&2
	if [ ${TEMP_EC} -ne 0 ]
	then
		printf "%s\n" "${RGN}" >> "${TEMP_FAILS}"
	fi
	return "${TEMP_EC}"
}


#	setup variables for the job
LONGEST_COUNT="${1}"
ASSEMBLY_FAI="${2}"
ALIGNMENT_BAM="${3}"
OUTPUT_DEPTHS_TSV="${4}"
AVE_DEPTH_TXT="${5}"

OUTPUT_FILES=("${OUTPUT_DEPTHS_TSV}" "${AVE_DEPTH_TXT}")
declare -a OUTPUT_DIRS
for OUTPUT_FILE in "${OUTPUT_FILES[@]}"
do
	OUTPUT_DIRS+=( $(readlink -m -n `dirname "${OUTPUT_FILE}"`) )
done

# 	check for existence of input file(s)
#		We assume samtools is capable of recognizing whether the index it
#		requires exists. We assume the same for the input fa file.

# 	check for existence of expected output file(s)
for OUTPUT_FILE in "${OUTPUT_FILES[@]}"
do
	if [ -e "${OUTPUT_FILE}" ]
	then
		printf "%s\n" "INFO: ${OUTPUT_FILE} already exists! We assume this means we can quit this process without running the intended command. Bye!" 1>&2
		cleanup
		exit 0
	fi
done

#	create output directories, if needed
mkdir -p "${OUTPUT_DIRS[@]}" &> /dev/null

# 	create tmp dir and files
TMP_DIR="/tmp/${SLURM_JOB_ID}"
if [ -z "${SLURM_JOB_ID}" ]
then
	TMP_DIR="/tmp/$$"
fi
mkdir -p "${TMP_DIR}" &> /dev/null
TMP_REGIONS="${TMP_DIR}/tmp-${RANDOM}.list"
TMP_FAILS="${TMP_DIR}/tmp-${RANDOM}_fails.list"

#	run the programs of interest
#		get n longest seqs ids
printf "%s" "identifying longest seq ids..." 1>&2
sort -t '	' -n -r -k 2 "${ASSEMBLY_FAI}" \
	| head -n "${LONGEST_COUNT}" \
	| cut -d '	' -f 1 \
	> "${TMP_REGIONS}" &

wait `jobs -p`
EXIT_CODE=$?
printf "%s\n" "done." 1>&2
cat "${TMP_REGIONS}" | sed -r 's,^,\t,' 1>&2
if [ ${EXIT_CODE} -eq 0 ]
then
	printf "%s\n" "calculating depth for..." 1>&2
	while read REGION
	do
		TMP_DEPTH="${TMP_DIR}/tmp-${RANDOM}_${REGION}-depth.tsv"

		printf "\t%s\n" "${REGION}" 1>&2
		calcDepth "${REGION}" "${ALIGNMENT_BAM}" "${TMP_DEPTH}" "${TMP_FAILS}" &

		if [ ${SLURM_NTASKS} -eq 1 ]
		then
			wait `jobs -p`
		else
			NUM_JOBS=`jobs -p | wc -l`
			while [ ${NUM_JOBS} -ge ${SLURM_NTASKS} ]
			do
				printf "%s\n" "sleeping for 5 seconds..." 1>&2
				sleep 5
				NUM_JOBS=`jobs -p | wc -l`
			done
		fi
	done < "${TMP_REGIONS}"

	printf "%s\n" "waiting for calcDepths jobs" 1>&2
	wait `jobs -p`
	printf "%s\n" "done (waiting for calcDepths jobs)" 1>&2

	# if any calcDepth jobs failed, report and quit
	if [[ -e "${TMP_FAILS}" ]] && [[ `cat "${TMP_FAILS}" | wc -l` -gt 0 ]]
	then
		printf "%s\n" "ERROR: The calcDepth jobs failed for these regions:" 1>&2
		cat "${TMP_FAILS}" | sed -r 's,^,\t,' 1>&2
		#cleanup "failed"
		EXIT_CODE=1
	else
		# combine calcDepth outputs
		printf "%s" "combining calcDepths..." 1>&2
		cat "${TMP_DIR}"/tmp-*-depth.tsv > "${OUTPUT_DEPTHS_TSV}"
		EXIT_CODE=$?
		printf "%s\n" "done." 1>&2

		if [ ${EXIT_CODE} -eq 0 ]
		then
			chmod 444 "${OUTPUT_DEPTHS_TSV}" &> /dev/null
			# calc average depth
			awk 'BEGIN{c=0;s=0;}{c+=1;s+=$3}END{printf s/c;}' "${OUTPUT_DEPTHS_TSV}" > "${AVE_DEPTH_TXT}"
			EXIT_CODE=$?
			if [ ${EXIT_CODE} -eq 0 ]
			then
				chmod 444 "${AVE_DEPTH_TXT}" &> /dev/null
				printf "%s\n" "The average per-base alignment depth of the sampled assembly sequences was `cat ${AVE_DEPTH_TXT}`" 1>&2
				#cleanup "success"
			else
				rm -f "${AVE_DEPTH_TXT}" &> /dev/null
				#cleanup "failed"
			fi
		else
			rm -f "${OUTPUT_DEPTHS_TSV}" &> /dev/null
			printf "%s\n" "ERROR: couldn't successfully combine depth tsvs" 1>&2
			#cleanup "failed"
		fi
	fi

else
	printf "%s\n" "ERROR: failed to extract the longest ${LONGEST_COUNT} regions from the fasta index" 1>&2
	#cleanup "failed"
fi

if [ ${EXIT_CODE} -eq 0 ]
then
	cleanup "success"
else
	cleanup "failed"
fi
exit ${EXIT_CODE}

