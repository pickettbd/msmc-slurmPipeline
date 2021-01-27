#! /bin/bash

tail -n +9 "${BASH_SOURCE[0]}" | head -n -1 | fold -s

exit 0

# Everything below this line is simple documentation
:'
This should really be done manually. You just need to make the subset assembly accessible. In the previous step you should have subset the assembly to get only the longest sequences based on some cutoff (e.g., 500kb).
The subset assembly needs to be located at data/assembly/asm_long.fa[.gz]. This can be a symbolic link. This is what I did:
	mkdir -p data/assembly
	cd data/assembly
	ln -s asm_ge500kb.fa asm_long.fa
	cd ../..

	-OR, more generally-

	mkdir -p data/assembly
	cd data/assembly
	ln -s /path/to/my/scaffolds_ge500kb.fa asm_long.fa
	cd ../..

Please note that this process assumes a specific directory structure, starting with a main project directory (can be called anything). There should be a data directory (with subdirectories, as needed), a job_files directory for SLURM output files, and a directory for the scripts that matches the pattern "scripts*". All scripts are expected to be run from the main project directory, _not_ from  the scripts* directory or data directory.
'
