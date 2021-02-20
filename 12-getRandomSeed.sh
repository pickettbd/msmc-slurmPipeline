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

#	seed
OD_BYTES=2
SEED=$(od -v -A n -N ${OD_BYTES} -t u2 < /dev/urandom | sed -r 's,^ +,,' | sed -r 's, +, ,g')

# actually write out the seed file
SEED_FILE="data/random_seed-bootstrap.txt"
rm -f "${SEED_FILE}" &> /dev/null

printf "%s" "${SEED}" > "${SEED_FILE}"

EXIT_CODE=$?

if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${SEED_FILE}" &> /dev/null
	printf "%s\n" "INFO: Successfully created seed file." 1>&2
else
	rm -f "${SEED_FILE}" &> /dev/null
	printf "%s\n" "ERROR: Failed to creat seed file." 1>&2
fi

exit ${EXIT_CODE}

