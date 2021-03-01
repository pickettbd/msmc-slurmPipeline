#! /bin/bash

tail -n +9 "${BASH_SOURCE[0]}" | head -n -1 | fold -s

exit 0

# Everything below this line is simple documentation
:'
This should really be done manually. You just need to get the input alignments accessible. These alignments are the _corrected_ pacbio reads mapped against the scaffolds. Ideally, you will drop the shortest assembled sequences at some cutoff (recommended 500kb) before doing the alignment of the reads to the genome.
If you do not yet have these alignments, please generate them (e.g., using this pipeline: https://github.com/pickettbd/minimap2AlnPacbToRef-slurmPipeline).
They need to be located at data/alns/${SAMPLE_NAME}_pacbio-reads_x_asm-long.bam. This can be a symbolic link. This is what I did:
	mkdir -p data/alns
	cd data/alns
	ln -s /path/to/my/alns.bam sample1_pacbio-reads_x_asm-long.bam
	ln -s /path/to/my/alns.bam.bai sample1_pacbio-reads_x_asm-long.bam.bai
	cd ../..
If you have more than one sample, you will need to replace sample1 with the each sample name as you link to the various sets of alignments. Alignments from different samples must be in different files.
Please note that this process assumes a specific directory structure, starting with a main project directory (can be called anything). There should be a data directory (with subdirectories, as needed), a job_files directory for SLURM output files, and a directory for the scripts that matches the pattern "scripts*". All scripts are expected to be run from the main project directory, _not_ from  the scripts* directory or data directory.
'
