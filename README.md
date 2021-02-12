# MSMC Pipeline
This is a pipeline for running MSMC on a SLURM-controlled Linux cluster. 

## Directory Structure and Installation
These scripts assume a very specific directory structure and naming scheme.  
You can modify the scripts to avoid it, but using it should also be fairly straightforward.
First, create the directory structure:
```
mkdir some_project_dir
cd some_project_dir
mkdir -p data job_files/{success,failed}
git clone https://github.com/pickettbd/msmc-slurmPipeline scripts-msmc
```
The scripts *must* from the main project directory (some_project_dir) (*not* from the scripts-msmc dir).

## Data Requirements
This project is written to work with a *de novo* genome assembly in fasta format and alignments of long reads (e.g., PacBio CLR (corrected)) to that assembly in BAM format.  
The assembly can be created with tools like [Canu](https://github.com/marbl/canu) (which can also correct the long reads, if necessary).
The alignments can be performed with a tool like [minimap2](https://github.com/lh3/minimap2).

## Software Dependencies
These scripts assume a [GNU](https://www.gnu.org) [bash](https://www.gnu.org/software/bash) shell and cluster job submission controlled by [SLURM](https://slurm.schedmd.com).
The following tools are assumed to be installed on your machine with the executables available in your $PATH.  
The project assumes they are availble via system modules (e.g., Tcl or Lua), but removing the `module purge` and `module load _____` commands would remove the dependency on system modules.
- [MSMC](https://github.com/stschiff/msmc) (v1.1.0): Implementation of the multiple sequential markovian coalescent 
- [msmc-tools](https://github.com/stschiff/msmc-tools) (commit 123791f): Tools and Utilities for msmc and msmc2 
- [samtools/bcftools](https://www.htslib.org) (v1.11): Suites of programs for interacting with high-throughput sequencing data
- [Python](https://python.org) (v3.9.0): Programming language (v3.6+ required)

## Notes
This pipeline does not support file names or paths that have whitespace in them.
This pipeline must be run for every individual separately.  
If multiple individuals exist, this pipeline could be revised to run on one or more individuals, but only a single individual is currently supported.
If multiple individuals do exist, a [SNPable](http://lh3lh3.users.sourceforge.net/snpable.shtml) mask must also be made.

