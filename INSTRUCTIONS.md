# Step-by-step Instructions

## Table of Contents
0. [Copy Assembly](#copyAsm)
1. [Index Assembly](#indexAsm)

## Setup (Directory Structure)
These scripts assume a very specific directory structure and naming scheme.  
You can modify the scripts to avoid it, but using it should also be fairly straightforward.
First, create the directory structure:

```
	mkdir some_project_dir
	cd some_project_dir
	mkdir -p data job_files/{success,failed}
	git clone https://github.com/pickettbd/msmc-slurmPipeline scripts-msmc
```
When you run scripts stored in the `scripts-msmc` directory, you *must* run them from the main project directory (`some_project_dir`), *not* from the `scripts-msmc` or `data` directories.

## Setup (Input Files)
This pipeline requires a "reference" genome assembly as input. Technically, per-sample read data is also required, but this pipeline assumes you generated alignments with it previously and, thus, ignores those input reads.

### 00 - Copy Assembly <a name="copyAsm"></a>
The script associated with this step (`00-copyAsm.sh`) is just a placeholder. If you run it, it will display a brief message reminding you what needs to be done during this step. Running the script *does not* complete the step for you.
The goal is to copy the "reference" genome (a *de novo* assembly is okay) and make it accessible to the scripts in this pipeline. The final location of the assembly, in fasta format, must be located at `data/assembly/asm.fa`. To accomplish this, you could do the following:

```
	mkdir -p data/assembly
	cd data/assembly
	ln -s /path/to/my/scaffolds.fa asm.fa
	cd ../..
```

### 01 - Index Assembly <a name="indexAsm"></a>
Unlike step 00, the script associated with this step (`01-indexAsm.sh`) will actually complete the step for you.
The goal is to have a Samtools `faidx` index of the assembly located at `data/assembly/asm.fa.fai`.
If you already have this, you may simply copy or link the file to this location and skip running the script.
If not, run the script and it will generate the index for you.
This script runs the job "locally" on the node you are using because fasta indexes usually take a few seconds to create, making them not worth the overhead required for a full (SLURM) "job".
To run this script, first ensure you are in the main project directory (i.e., parent directory of `data`, `job_files`, and `scripts-msmc`).
Then run as follows: `./01-indexAsm.sh`

## SNPable Mask
### 02 - Copy SNPable Mask
### 03 - Convert SNPable Mask

## Subset Assembly
### 04 - Subset Assembly
### 05 - Link Long Assembly
### 06 - Index Long Assembly

## Alignments of Samples
### 07 - Copy Per-Sample Alignments
### 08 - Approximate Depth

## MSMC Prep
### 09 - Mask
### 10 - Multihetsep

## MSMC (Main)
### 11 - MSMC

## MSMC Bootstrap
### 12 - Generate Random Seed
### 13 - Multihetsep
### 14 - MSMC
### 15 - Combine Bootstrap Results

## Visualize
### 16 - Plot

