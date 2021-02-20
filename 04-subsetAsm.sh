#! /bin/bash

# Ensure we're running from the correct location
CWD_check()
{
	#local SCRIPTS_DIR
	local MAIN_DIR
	local RUN_DIR

	SCRIPTS_DIR=$(readlink -f `dirname "${BASH_SOURCE[0]}"`)
	MAIN_DIR=$(readlink -f `dirname "${SCRIPTS_DIR}/"`)
	RUN_DIR=$(readlink -f .)

	if [ "${RUN_DIR}" != "${MAIN_DIR}" ] || ! [[ "${SCRIPTS_DIR}" =~ ^"${MAIN_DIR}"/scripts.* ]]
	then
		printf "\n\t%s\n\t%s\n\n" "Script must be run from ${MAIN_DIR}" "You are currently at:   ${RUN_DIR}" 1>&2
		exit 1
	fi
}
CWD_check

# #### #
# MAIN #
# #### #

# define key variables
CUTOFF=500 # kb
DATA_DIR="data"
ASM_DIR="${DATA_DIR}/assembly"
ASM_PATH="${ASM_DIR}/asm.fa"
ASM_IDX="${ASM_PATH%.gz}.fai"
ASM_OUT="${ASM_PATH%.fa*}_ge${CUTOFF}kb.fa"

# define key variables
INPUT_FILES=("${ASM_PATH}" "${ASM_IDX}")

# ###################################### #
# sanity check on input and output files #
# ###################################### #

EXIT_EARLY=0

# check for existence of needed input files
for INPUT_FILE in "${INPUT_FILES[@]}"
do
	if [ ! -e "${INPUT_FILE}" ]
	then
		printf "%s\n" "ERROR: Required input file does not exist: ${INPUT_FILE}" 1>&2
		EXIT_EARLY=1
	fi
done

# check for existence of expected output files
if [ -e ${ASM_OUT} ]
then
	printf "%s\n\t%s\n" "ERROR: Expected output file(s) already exist(s). If you wish to proceed anyway, please remove it/them:" "rm -f ${ASM_OUT}" 1>&2
	EXIT_EARLY=1
fi

# exit without submitting the job, if needed
if [ $EXIT_EARLY -ne 0 ]
then
	exit ${EXIT_EARLY}
fi

# #################### #
# actually run the job #
# #################### #

# load the modules
module purge
module load python/3.9.0

time python3 "${SCRIPTS_DIR}/getLongestSeqs.py" \
	"${ASM_PATH}" \
	"${ASM_IDX}" \
	"${ASM_OUT}" \
	"${CUTOFF}"

EXIT_CODE=$?

if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${ASM_OUT}" &> /dev/null
else
	rm -f "${ASM_OUT}" &> /dev/null
fi

exit ${EXIT_CODE}

