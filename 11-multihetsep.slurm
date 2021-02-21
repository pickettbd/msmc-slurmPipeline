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
module load msmc-tools/20201030-123791f
module load python/3.9.0

# needed input things
MULTIHETSEP_FILE="${1}"
SNPABLE_MASK="${2}"
shift 2
INPUT_FILES=("${@}")

if [ "${SNPABLE_MASK}" == "NA" ]
then
	SNPABLE_MASK=""
else
	if [ ! -e "${SNPABLE_MASK}" ]
	then
		printf "%s\n" "ERROR: You provided a SNPable mask, but the file did not exist." 1>&2
		cleanup "failed"
		exit 1
	fi
	SNPABLE_MASK="--mask ${SNPABLE_MASK}"
fi

# check number of input files
if [ $(($# % 2)) -ne 0 ]
then
	printf "%s\n" "ERROR: You must provide an even number of input files (not counting the output file). We expect alternatinv bed and vcf files." 1>&2
	cleanup "failed"
	exit 1
fi

# separate beds and vcfs
declare -a BED_FILES
declare -a VCF_FILES
for i in `seq 0 2 $((${#INPUT_FILES[@]}-1))`
do
	j=$((${i}+1))
	BED_FILES+=("${INPUT_FILES[${i}]}")
	VCF_FILES+=("${INPUT_FILES[${j}]}")
done

# check that we got the right number of them
if [ ${#BED_FILES[@]} -ne ${#VCF_FILES[@]} ]
then
	printf "%s\n" "ERROR: We have different number of bed and vcf files. Presumabely, this is because the number of files provided was odd, but we checked that it wasn't. Hmmm..." 1>&2
	cleanup "failed"
	exit 1
fi

# set the output directory
OUTPUT_DIR=$(readlink -n -m `dirname "${MULTIHETSEP_FILE}"`)

# 	check for existence of input file(s)
#		We assume msmc-tools is capable of recognizing whether the files
#		it requires exist.

# 	check for existence of expected output file(s)
if [ -e "${MULTIHETSEP_FILE}" ]
then
	printf "%s\n" "INFO: ${MULTIHETSEP_FILE} already exists! We assume this means we can quit this process without running the intended command. Bye!" 1>&2
	cleanup
	exit 0
fi

#	create output directory, if needed
mkdir -p "${OUTPUT_DIR}" &> /dev/null

#	run the program of interest
time generate_multihetsep.py \
	`printf -- '--mask %s ' "${BED_FILES[@]}"` \
	${SNPABLE_MASK} \
	"${VCF_FILES[@]}" \
	> "${MULTIHETSEP_FILE}" &

wait `jobs -p`
EXIT_CODE=$?

#	cleanup and exit
if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${MULTIHETSEP_FILE}" &> /dev/null
	cleanup "success"
else
	rm -f "${MULTIHETSEP_FILE}" &> /dev/null
	cleanup "failed"
fi

exit ${EXIT_CODE}

#usage: generate_multihetsep.py [-h] [--mask MASK]
#                               [--negative_mask NEGATIVE_MASK] [--trio TRIO]
#                               [--chr CHR]
#                               files [files ...]
#
#positional arguments:
#  files                 Input VCF files
#
#optional arguments:
#  -h, --help            show this help message and exit
#  --mask MASK           apply masks in bed format, should be given once for
#                        the calling mask from each individual, and in addition
#                        can be given for e.g. mappability or admixture masks.
#                        Mask can be gzipped, if indicated by .gz file ending.
#  --negative_mask NEGATIVE_MASK
#                        same as mask, but interpreted as negative mask, so
#                        places where sites should be excluded
#  --trio TRIO           declare trio-relationships. This should be a string
#                        with a format
#                        <child_index>,<father_index>,<mother_index>, where the
#                        three fields are the indices of the samples in the
#                        trio. This option will automatically phase parental
#                        and maternal haplotypes where possible and remove the
#                        child VCF file from the resulting file. Can be given
#                        multiple times if you have multiple trios.
#  --chr CHR             overwrite chromosomes in input files. Useful if
#                        chromosome names differ, such as chr1 vs. 1
