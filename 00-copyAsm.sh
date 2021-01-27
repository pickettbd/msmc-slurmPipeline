#! /bin/bash

tail -n +9 "${BASH_SOURCE[0]}" | head -n -1 | fold -s

exit 0

# Everything below this line is simple documentation
:'
This should really be done manually. You just need to get the input assembly accessible.
it needs to be located at data/assembly/asm.fa[.gz]. This can be a symbolic link. This is what I did:
	mkdir -p data/assembly
	cd data/assembly
	ln -s /path/to/my/scaffolds.fa asm.fa
	cd ../..
Please note that this process assumes a specific directory structure, starting with a main project directory (can be called anything). There should be a data directory (with subdirectories, as needed), a job_files directory for SLURM output files, and a directory for the scripts that matches the pattern "scripts*". All scripts are expected to be run from the main project directory, _not_ from  the scripts* directory or data directory.
'
