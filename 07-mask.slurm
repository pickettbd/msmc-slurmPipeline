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

if [ -z "${SLURM_ARRAY_TASK_ID}" ]
then
	printf "%s\n" "ERROR: SLURM_ARRAY_TASK_ID not defined." 1>&2
	control_c
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
}

control_c()
{
	kill -SIGINT `jobs -p`
	cleanup "failed"
	exit 1
}

trap control_c SIGHUP SIGINT SIGTERM SIGQUIT

moveTempFilesBackToNetworkStorage()
{
	if [ -n $WORK_DIR ] && [ -e $WORK_DIR ] && [ -d $WORK_DIR ]
	then
		time rsync -utpv "${TMP_OUT_BED}" "${OUT_MASK_BED_GZ}" 1>&2
		if [ $? -eq 0 ]
		then
			touch "${OUT_MASK_BED_GZ}.ok"
		fi

		time rsync -utpv "${TMP_OUT_VCF}" "${OUT_MASK_VCF_GZ}" 1>&2
		if [ $? -eq 0 ]
		then
			touch "${OUT_MASK_VCF_GZ}.ok"
		fi
	fi
}

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
module load bcftools/1.11
module load python/3.9.0
module load msmc-tools/20201030-123791f

#	setup variables for the job
#ASM_SEQ_NUM=`printf "%02u" "${SLURM_ARRAY_TASK_ID}"`
ASM_SEQ_NUM="${SLURM_ARRAY_TASK_ID}"

# needed input things
ASM_FA="${1}"
ALN_BAM="${2}"
DEPTH="${3}"
ASM_SEQ_IDS_LIST="${4}"
OUT_PFX="${5}"
OUT_BED_SFX="${6}"
OUT_VCF_SFX="${7}"

ASM_SEQ_ID=`head -n ${ASM_SEQ_NUM} "${ASM_SEQ_IDS_LIST}" | tail -n 1 | cut -d '	' -f 1 | tr -d '\n'`
OUT_MASK_BED_GZ="${OUT_PFX}${ASM_SEQ_ID}${OUT_BED_SFX}"
OUT_MASK_VCF_GZ="${OUT_PFX}${ASM_SEQ_ID}${OUT_VCF_SFX}"

OUTPUT_DIR=$(readlink -n -m `dirname "${OUT_PFX}"`)
OUTPUT_FILES=("${OUT_MASK_BED_GZ}" "${OUT_MASK_VCF_GZ}")

# set thread counts
MPILEUP_EXTRA_THREADS=$((${SLURM_NTASKS}-4))
if [[ ${MPILEUP_EXTRA_THREADS} -lt 0 ]]
then
	MPILEUP_EXTRA_TRHEADS=0
fi

# 	check for existence of input file(s)
#		We assume bcftools & bamCaller.py are capable of recognizing whether the files
#		they require exist.

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

#		create /tmp output directory and copy existing files
WORK_DIR="/tmp/${SLURM_ARRAY_JOB_ID}-${SPLIT_NUM}"
mkdir -p "${WORK_DIR}" &> /dev/null
#			files
TMP_FA="${WORK_DIR}/`basename ${ASM_FA}`"
TMP_BAM="${WORK_DIR}/`basename ${ALN_BAM}`"
time rsync -uLtpv "${ASM_FA}" "${ALN_BAM}" "${WORK_DIR}"/ 1>&2

# write tmp info for later cleanup, if needed
#	get the lock
dotlockfile -l "${SLURM_SUBMIT_DIR}/.cleanup.tsv.lock"
printf "%s\t%s\n" "${SLURM_JOB_NODELIST}" "${SLURM_ARRAY_JOB_ID}-${SLURM_ARRAY_TASK_ID}" >> "${SLURM_SUBMIT_DIR}/cleanup.tsv"
dotlockfile -u "${SLURM_SUBMIT_DIR}/.cleanup.tsv.lock"

#	establish tmp out files
TMP_OUT_BED="${WORK_DIR}/`basename ${OUT_MASK_BED_GZ}`"
TMP_OUT_VCF="${WORK_DIR}/`basename ${OUT_MASK_VCF_GZ}`"

#	run the program of interest (4+ threads ideal: (1) bcftools mpileup, (2) bcftools call, (3) bamCaller.py, & (4) bzip
set -o pipefail
bcftools mpileup --threads "${MPILEUP_EXTRA_THREADS}" -B -q 20 -C 0 -r ${ASM_SEQ_ID} -f "${ASM_FA}" "${ALN_BAM}" \
	| bcftools call --threads "${MPILEUP_EXTRA_THREADS}" -c -V indels \
	| bamCaller.py ${DEPTH} "${TMP_OUT_BED}" --minMapQ 20 --minConsQ 20 \
	| gzip -c \
	> "${TMP_OUT_VCF}" &

wait `jobs -p`
EXIT_CODE=$?
set +o pipefail

moveTempFilesBackToNetworkStorage

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

##### BCFTOOLS MPILEUP #####
#Usage: bcftools mpileup [options] in1.bam [in2.bam [...]]
#
#Input options:
#  -6, --illumina1.3+      quality is in the Illumina-1.3+ encoding
#  -A, --count-orphans     do not discard anomalous read pairs
#  -b, --bam-list FILE     list of input BAM filenames, one per line
#  -B, --no-BAQ            disable BAQ (per-Base Alignment Quality)
#  -C, --adjust-MQ INT     adjust mapping quality; recommended:50, disable:0 [0]
#  -d, --max-depth INT     max raw per-file depth; avoids excessive memory usage [250]
#  -E, --redo-BAQ          recalculate BAQ on the fly, ignore existing BQs
#  -f, --fasta-ref FILE    faidx indexed reference sequence file
#      --no-reference      do not require fasta reference file
#  -G, --read-groups FILE  select or exclude read groups listed in the file
#  -q, --min-MQ INT        skip alignments with mapQ smaller than INT [0]
#  -Q, --min-BQ INT        skip bases with baseQ/BAQ smaller than INT [13]
#  -r, --regions REG[,...] comma separated list of regions in which pileup is generated
#  -R, --regions-file FILE restrict to regions listed in a file
#      --ignore-RG         ignore RG tags (one BAM = one sample)
#  --rf, --incl-flags STR|INT  required flags: skip reads with mask bits unset []
#  --ff, --excl-flags STR|INT  filter flags: skip reads with mask bits set
#                                            [UNMAP,SECONDARY,QCFAIL,DUP]
#  -s, --samples LIST      comma separated list of samples to include
#  -S, --samples-file FILE file of samples to include
#  -t, --targets REG[,...] similar to -r but streams rather than index-jumps
#  -T, --targets-file FILE similar to -R but streams rather than index-jumps
#  -x, --ignore-overlaps   disable read-pair overlap detection
#
#Output options:
#  -a, --annotate LIST     optional tags to output; '?' to list []
#  -g, --gvcf INT[,...]    group non-variant sites into gVCF blocks according
#                          to minimum per-sample DP
#      --no-version        do not append version and command line to the header
#  -o, --output FILE       write output to FILE [standard output]
#  -O, --output-type TYPE  'b' compressed BCF; 'u' uncompressed BCF;
#                          'z' compressed VCF; 'v' uncompressed VCF [v]
#      --threads INT       use multithreading with INT worker threads [0]
#
#SNP/INDEL genotype likelihoods options:
#  -e, --ext-prob INT      Phred-scaled gap extension seq error probability [20]
#  -F, --gap-frac FLOAT    minimum fraction of gapped reads [0.002]
#  -h, --tandem-qual INT   coefficient for homopolymer errors [100]
#  -I, --skip-indels       do not perform indel calling
#  -L, --max-idepth INT    maximum per-file depth for INDEL calling [250]
#  -m, --min-ireads INT    minimum number gapped reads for indel candidates [1]
#  -o, --open-prob INT     Phred-scaled gap open seq error probability [40]
#  -p, --per-sample-mF     apply -m and -F per-sample for increased sensitivity
#  -P, --platforms STR     comma separated list of platforms for indels [all]
#
#Notes: Assuming diploid individuals.
#
#Example:
#   # See also http://samtools.github.io/bcftools/howtos/variant-calling.html
#   bcftools mpileup -Ou -f reference.fa alignments.bam | bcftools call -mv -Ob -o calls.bcf

##### BCFTOOLS CALL #####
#About:   SNP/indel variant calling from VCF/BCF. To be used in conjunction with bcftools mpileup.
#         This command replaces the former "bcftools view" caller. Some of the original
#         functionality has been temporarily lost in the process of transition to htslib,
#         but will be added back on popular demand. The original calling model can be
#         invoked with the -c option.
#Usage:   bcftools call [options] <in.vcf.gz>
#
#File format options:
#       --no-version                do not append version and command line to the header
#   -o, --output <file>             write output to a file [standard output]
#   -O, --output-type <b|u|z|v>     output type: 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
#       --ploidy <assembly>[?]      predefined ploidy, 'list' to print available settings, append '?' for details
#       --ploidy-file <file>        space/tab-delimited list of CHROM,FROM,TO,SEX,PLOIDY
#   -r, --regions <region>          restrict to comma-separated list of regions
#   -R, --regions-file <file>       restrict to regions listed in a file
#   -s, --samples <list>            list of samples to include [all samples]
#   -S, --samples-file <file>       PED file or a file with an optional column with sex (see man page for details) [all samples]
#   -t, --targets <region>          similar to -r but streams rather than index-jumps
#   -T, --targets-file <file>       similar to -R but streams rather than index-jumps
#       --threads <int>             use multithreading with <int> worker threads [0]
#
#Input/output options:
#   -A, --keep-alts                 keep all possible alternate alleles at variant sites
#   -f, --format-fields <list>      output format fields: GQ,GP (lowercase allowed) []
#   -F, --prior-freqs <AN,AC>       use prior allele frequencies
#   -G, --group-samples <file|->    group samples by population (file with "sample\tgroup") or "-" for single-sample calling
#   -g, --gvcf <int>,[...]          group non-variant sites into gVCF blocks by minimum per-sample DP
#   -i, --insert-missed             output also sites missed by mpileup but present in -T
#   -M, --keep-masked-ref           keep sites with masked reference allele (REF=N)
#   -V, --skip-variants <type>      skip indels/snps
#   -v, --variants-only             output variant sites only
#
#Consensus/variant calling options:
#   -c, --consensus-caller          the original calling method (conflicts with -m)
#   -C, --constrain <str>           one of: alleles, trio (see manual)
#   -m, --multiallelic-caller       alternative model for multiallelic and rare-variant calling (conflicts with -c)
#   -n, --novel-rate <float>,[...]  likelihood of novel mutation for constrained trio calling, see man page for details [1e-8,1e-9,1e-9]
#   -p, --pval-threshold <float>    variant if P(ref|D)<FLOAT with -c [0.5]
#   -P, --prior <float>             mutation rate (use bigger for greater sensitivity), use with -m [1.1e-3]
#
#Example:
#   # See also http://samtools.github.io/bcftools/howtos/variant-calling.html
#   bcftools mpileup -Ou -f reference.fa alignments.bam | bcftools call -mv -Ob -o calls.bcf

