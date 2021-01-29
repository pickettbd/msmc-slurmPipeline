# MSMC Pipeline

## Directory Structure
These scripts assume a very specific directory structure and naming scheme. You can modify the scripts to avoid it, but using it should also be fairly straightforward. First, create the directory structure:
    mkdir some_project_dir
	cd some_project_dir
	mkdir -p data job_files/{success,failed} scripts-msmc

This repository should be contained in the scripts-msmc directory. Go to the main project directory (some_project_dir) and run the scripts from there (*not* from the script-msmc dir).
