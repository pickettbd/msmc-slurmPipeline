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
MU="3.7e-8"
AGE_AT_MATURITY=2
AGE_MULTIPLIER=2
DATA_DIR="data"
MSMC_DIR="${DATA_DIR}/msmc"
BOOTSTRAP_DIR="${MSMC_DIR}/bootstrap"
MAIN_MSMC="${MSMC_DIR}/msmc.final.txt"
BOOTSTRAP_MSMC_CONCAT="${BOOTSTRAP_DIR}/msmc-bootstrap_concat.tsv"
OUTPUT_PLOT="${DATA_DIR}/plot.pdf"

INPUT_FILES=("${MAIN_MSMC}" "${BOOTSTRAP_MSMC_CONCAT}")

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

# exit without submitting the job, if needed
if [ $EXIT_EARLY -ne 0 ]
then
	exit ${EXIT_EARLY}
fi

# #################### #
# actually run the job #
# #################### #

# load modules
module purge
module load r/4.0

# run the program of interest
time Rscript plot.R \
	"${MU}" \
	"${AGE_AT_MATURITY}" \
	"${AGE_MULTIPLIER}" \
	"${MAIN_MSMC}" \
	"${BOOTSTRAP_MSMC_CONCAT}" \
	"${OUTPUT_PLOT}"

