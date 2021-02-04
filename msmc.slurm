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
module load msmc/1.1.0

# needed input things
OUTPUT_MSMC_PFX="${1}"
shift 1
INPUT_MULTIHETSEP_FILES=("${@}")

OUTPUT_DIR=$(readlink -n -m `dirname "${OUTPUT_MSMC_PFX}"`)
OUTPUT_FILES=("${OUTPUT_MSMC_PFX}".{log,{final,loop}.txt})

# 	check for existence of input file(s)
#		We assume msmc is capable of recognizing whether the files
#		it requires exist.

# 	check for existence of expected output file(s)
declare -a ALREADY_EXIST_OUTPUT_FILES
for OUTPUT_FILE in "${OUTPUT_FILES[@]}"
do
	if [ -e "${OUTPUT_FILE}" ]
	then
		ALREADY_EXIST_OUTPUT_FILES+=("${OUTPUT_FILE}")
	fi
done

if [ "${#ALREADY_EXIST_OUTPUT_FILES[@]}" -gt 0 ]
then
	printf "%s\n" "INFO: one or more output files already exist! We assume this means we can quit this process without running the intended command. Bye!" 1>&2
	cleanup
	exit 0
fi
unset ALREADY_EXIST_OUTPUT_FILES

#	create output directory, if needed
mkdir -p "${OUTPUT_DIR}" &> /dev/null
unset OUTPUT_DIR

#	run the program of interest
time msmc \
	-t "${SLURM_NTASKS}" \
	-R \
	-p '1*2+16*1+1*2' \
	-o "${OUTPUT_MSMC_PFX}" \
	"${INPUT_MULTIHETSEP_FILES[@]}" &

wait `jobs -p`
EXIT_CODE=$?

#	cleanup and exit
if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${OUTPUT_FILES[@]}" &> /dev/null
	cleanup "success"
else
	rm -f "${OUTPUT_FILES[@]}" &> /dev/null
	cleanup "failed"
fi

exit ${EXIT_CODE}

#This is MSMC Version 1.1.0. Usage: msmc [options] <datafiles>
#  Options:
#    -i, --maxIterations=<size_t> : number of EM-iterations [default=20]
#    -o, --outFilePrefix=<string> : file prefix to use for all output files
#    -r, --rhoOverMu=<double>: ratio of recombination rate over mutation rate. Default=0.25.
#    -t, --nrThreads=<size_t> : nr of threads to use (defaults to nr of CPUs)
#    -p, --timeSegmentPattern=<string> : pattern of fixed time segments [default=10*1+15*2]
#    -P, --subpopLabels=<string> comma-separated subpopulation labels (assume one single population by default, with 
#          number of haplotypes inferred from first input file). For cross-population analysis with 4 haplotypes, 2 
#          coming from each subpopulation, set this to 0,0,1,1
#    -R, --fixedRecombination : keep recombination rate fixed [recommended, but not set by default]
#    -I, --indices: indices (comma-separated) of alleles in the data file to run over
#    -s, --skipAmbiguous: skip sites with ambiguous phasing. Recommended for gene flow analysis
#    --unboundedCrossCoal: do not bound the relative cross coalescence rate to be <=1.
#    --loBoundLambda: Give a lower bound for lambda rates (default=0)
#    --hiBoundLambda: Give an upper bound for lambda rates (default=infinity)
#    -h, --help: show this message
