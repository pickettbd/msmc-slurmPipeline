#! /bin/bash

# Ensure we're running from the correct location
CWD_check()
{
	local SCRIPTS_DIR
	local MAIN_DIR
	local RUN_DIR

	SCRIPTS_DIR=$(readlink -f `dirname "${BASH_SOURCE[0]}"`)
	MAIN_DIR=$(readlink -f `dirname "${SCRIPTS_DIR}/"`)
	RUN_DIR=$(readlink -f .)

	if [ "${RUN_DIR}" != "${MAIN_DIR}" ] || ! [[ "${SCRIPTS_DIR}" =~ ^"${MAIN_DIR}"/scripts.* ]]
	then
		printf "\n\t%s\n\t%s\n\n" "Script must be run from \"${MAIN_DIR}\"" "You are currently at:   \"${RUN_DIR}\"" 1>&2
		exit 1
	fi
}
CWD_check

# important variables
MSMC_BOOTSTRAP_DIR=`readlink -n -m "data/msmc/bootstrap"`
CONCAT_FILE=`readlink -n -m "${MSMC_BOOTSTRAP_DIR}/msmc-bootstrap_concat.tsv"`
FIRST_FILE=0 # 0=True, 1=False

# check if output file exists already
if [ -e "${CONCAT_FILE}" ]
then
	printf "%s\n\t%s %s\n" "INFO: Output file already exists. To run this step, first remove it:" "rm -f" "${CONCAT_FILE}" 1>&2
	exit 0
fi

# identify input files (assume the neeeded input files have all been generated)
INPUT_FILES=($(find "${MSMC_BOOTSTRAP_DIR}" -mindepth 2 -maxdepth 2 -type f -name 'msmc.final.txt' -printf '%p\n' | sort -V)) # <-- get input files from `find' command (assumes all needed files exist)

# create header line
printf "%s\t" "Bootstrap_Round" > "${CONCAT_FILE}"
head -n 1 "${INPUT_FILES[0]}" >> "${CONCAT_FILE}"

# add data lines, one file at a time
for INPUT_FILE in "${INPUT_FILES[@]}"
do
	ROUND=$(basename `dirname "${INPUT_FILE}"` | tr -d '\n' | sed -r 's,^round_([0-9]+)$,\1,')
	awk 'BEGIN{OFS="\t";FS="\t";}/^[0-9]/{print '"${ROUND}"', $0;}' "${INPUT_FILE}" >> "${CONCAT_FILE}"
	EXIT_CODE=$((${EXIT_CODE}+${?}))

done

EXIT_CODE=$?

if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${CONCAT_FILE}" &> /dev/null
	printf "%s\n" "INFO: Successfully created MSMC bootstrap concatenated file." 1>&2
else
	rm -f "${CONCAT_FILE}" &> /dev/null
	printf "%s\n" "ERROR: Failed to create MSMC bootstrap concatenated file." 1>&2
fi

exit ${EXIT_CODE}

