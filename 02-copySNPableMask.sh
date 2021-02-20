#! /bin/bash

tail -n +9 "${BASH_SOURCE[0]}" | head -n -1 | fold -s

exit 0

# Everything below this line is simple documentation
:'
If you have only one sample, you may skip this step (step 02) AND the next step (step 03).
If you have multiple samples, you will need to create a SNPable mask for your assembly. This basically amounts to aligning the the assembly against itself and running SNPable from Heng Li.
If you have not yet done this, please do so (e.g., using this pipeline: https://github.com/pickettbd/mappabilityMaskSNPable-slurmPipeline).
Once you have generated this, you will need to make it available to the rest of this pipeline. You may copy it or link it (demonstrated below) as long as the resulting file name is data/assembly/asm_snpable-mask.fa.gz. Note that the input to the SNPable process should be the same assembly you are using for this pipeline, i.e., data/assembly/asm.fa.
	# we assume data/assembly already exists
	# we assume data/assembly/asm.fa already exists
	cd data/assembly
	ln -s /path/to/where/the/SNPable_mask/mask_35_50.fa.gz asm_snpable-mask.fa.gz
	cd -
Please note that this process assumes a specific directory structure, starting with a main project directory (can be called anything). There should be a data directory (with subdirectories, as needed), a job_files directory for SLURM output files, and a directory for the scripts that matches the pattern "scripts*". All scripts are expected to be run from the main project directory, _not_ from  the scripts* directory or data directory.
'
