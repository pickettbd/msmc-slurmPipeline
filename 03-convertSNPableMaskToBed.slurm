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
	SUCCESS_FAIL_STATUS_SUBDIR="${1:-success}"

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
module load python/3.9.0

# needed input things
CONVERSION_SCRIPT="${1}"
INPUT_FASTA_MASK="${2}"
OUTPUT_BED_MASK_PFX="${3}"
OUTPUT_BED_MASK_SFX="${4}"

OUTPUT_DIR=$(readlink -n -m `dirname "${OUTPUT_BED_MASK_PFX}"`)
OUTPUT_BASE=`basename "${OUTPUT_BED_MASK_PFX}"`

# 	check for existence of input file(s)
#		We assume the conversion script is capable of recognizing
#		whether the files it requires exist.

# 	check for existence of expected output file(s)
#		We assume this has already been checked. If permissions
#		allow, existing output files will be overwritten.

#	create output directory, if needed
mkdir -p "${OUTPUT_DIR}" &> /dev/null

#	run the program of interest
time python3 "${CONVERSION_SCRIPT}" \
	-i "${INPUT_FASTA_MASK}" \
	-od "${OUTPUT_DIR}" \
	-op "${OUTPUT_BASE}" \
	-os "${OUTPUT_BED_MASK_SFX}" &

wait `jobs -p`
EXIT_CODE=$?

#	cleanup and exit
if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${OUTPUT_BED_MASK_PFX}"*"${OUTPUT_BED_MASK_SFX}" &> /dev/null
	cleanup "success"
else
	rm -f "${OUTPUT_BED_MASK_PFX}"*"${OUTPUT_BED_MASK_SFX}" &> /dev/null
	cleanup "failed"
fi

exit ${EXIT_CODE}

