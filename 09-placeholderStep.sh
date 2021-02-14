#! /bin/bash

tail -n +9 "${BASH_SOURCE[0]}" | head -n -1 | fold -s

exit 0

# Everything below this line is simple documentation
:'
This is a placeholder step. There is at least one step here in which *.multihetsep.txt files were generated. This needs to be fleshed out.

2. generate msmc input file for a single diploid sample

	samtools view -H pacb_corrected-x-asm_sorted.bam \
	| awk '$1 == "@SQ" {sub("SN:", "", $2); print $2}' > scaffolds.tsv

	########
	#!/bin/bash
	#SBATCH -J "MSMC_input"
	#SBATCH --nodes=1
	#SBATCH --ntasks=1
	#SBATCH --mem-per-cpu=5120M
	#SBATCH --time=8:00:00
	#SBATCH -o BT_multihetsep.out

	module load python/3.6
	module load perl
	module load samtools

	INDIR=/fslhome/fslcollab239/compute/BTddRAD/msmc/msmc_500kb/masks
	OUTDIR=/fslhome/fslcollab239/compute/BTddRAD/msmc/msmc_500kb/msmc_input
	MAPDIR=/fslhome/fslcollab239/compute/BTddRAD/msmc/msmc_500kb

	for i in `cat scaffolds.tsv`; do  
	/fslhome/fslcollab239/bin/msmc-tools/generate_multihetsep.py --chr ${i} --mask $INDIR/mask_${i}.bed.gz \
	     $INDIR/mask_${i}.vcf.gz > $OUTDIR/${i}.multihetsep.txt
		 done
	########

	Generate an MSMC input file for a single diploid sample:
	#!/usr/bin/env bash
	##example
	INDIR=/path/to/VCF/and/mask/files
	OUTDIR=/path/to/output_files
	MAPDIR=/path/to/mappability/mask
	generate_multihetsep.py --chr 1 --mask $INDIR/NA12878.mask.bed.gz \
	    --mask $MAPDIR/hs37d5_chr1.mask.bed $INDIR/NA12878.vcf.gz > $OUTDIR/NA12878.chr1.multihetsep.txt

possibly need to combine samples (if having multiple) into a single one. This is an example with 2.
	#!/usr/bin/env bash

	INDIR=/home/wpsg/workshop_materials/03_psmc_msmc/human_vcf_bed
	OUTDIR=/home/wpsg/workshop_materials/03_psmc_msmc
	MAPDIR=/home/wpsg/workshop_materials/03_psmc_msmc
	generate_multihetsep.py --chr 1 \
		--mask $INDIR/NA12878.chr1.mask.bed.gz --mask $INDIR/NA12891.chr1.mask.bed.gz --mask $INDIR/NA12892.chr1.mask.bed.gz \
		--mask $INDIR/NA19240.chr1.mask.bed.gz --mask $INDIR/NA19238.chr1.mask.bed.gz --mask $INDIR/NA19239.chr1.mask.bed.gz \
		--mask $MAPDIR/hs37d5_chr1.mask.bed --trio 0,1,2 --trio 3,4,5 \
		$INDIR/NA12878.chr1.vcf.gz $INDIR/NA12891.chr1.vcf.gz $INDIR/NA12892.chr1.vcf.gz \
		$INDIR/NA19240.chr1.vcf.gz $INDIR/NA19238.chr1.vcf.gz $INDIR/NA19239.chr1.vcf.gz \
		> $OUTDIR/EUR_AFR.chr1.multihetsep.txt
	
the order of these msut be the same relative to eachother.

# book chapter with best details
http://link.springer.com/10.1007/978-1-0716-0199-0_7
'