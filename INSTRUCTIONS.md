# Step-by-step Instructions

## Table of Contents
0. [Copy Assembly](#copyAsm)
1. [Index Assembly](#indexAsm)
2. [Copy SNPable Mask](#copyMask)
3. [Convert SNPable Mask](#convertMask)
4. [Subset Assembly](#subsetAsm)
5. [Link Long Assembly](#linkLong)
6. [Index Long Assembly](#indexLong)
7. [Create Samples List](#samples)
8. [Copy Per-Sample Alignments](#copyAlns)
9. [Approximate Depth](#approxDepth)
10. [Mask](#mask)
11. [Multihetsep](#multihetsep)
12. [MSMC](#MSMC)
13. [Generate Random Seed](#randomSeed)
14. [Multihetsep](#multihetsepBoot)
15. [MSMC](#MSMCboot)
16. [Combine Bootstrap Results](#combineBoot)
17. [Plot](#plot)

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
Then run as follows: `./scripts-msmc/01-indexAsm.sh`

## SNPable Mask
If you have multiple samples, you will need a SNPable mask.
If you have only one sample, please skip to step 04.

### 02 - Copy SNPable Mask <a name="copyMask"></a>
Similar to step 00, this step is a placeholder.
Generating a SNPable mask is beyond the scope of this repository, but you can generate one using [this repository](https://github.com/pickettbd/mappabilityMaskSNPable-slurmPipeline).
Once you have a SNPable mask, copy or link it to `data/assembly/asm_snpable-mask.fa.gz`.

```
	cd data/assembly
	ln -s /path/to/where/the/SNPable_mask/mask_35_50.fa.gz asm_snpable-mask.fa.gz
	cd -
```

### 03 - Convert SNPable Mask <a name="convertMask"></a>
MSMC requires a SNPable mask in bed format instead of fasta format.
The script associated with this step (`03-convertSNPableMaskToBed.slurm`) will run a modified version of `makeMappabilityMask.py` from [msms-tools](https://github.com/stschiff/msmc-tools).
This script will run on the SLURM-controlled cluster as a job by running the following command from the main project directory: `./scripts-msmc/03-convertSNPableMaskToBed.submit`.

## Subset Assembly
The MSMC manual suggests dropping short scaffolds/contigs from your assembly if you have contigs/scaffolds instead of chromosomes.
The next steps will create a copy of the assembly with all contigs/scaffolds dropped that are shorter than 500kb.
To change the cutoff, edit the scripts.

### 04 - Subset Assembly <a name="subsetAsm"></a>
Similar to step 01, this step runs "locally" by running `./scripts-msmc/04-subsetAsm.sh`.
It will create a copy of the assembly without the shortest sequences at `data/assembly/asm_ge500kb.fa`.
You may skip this step if you do not wish to subset your assembly or your assembly is already at such a level of contiguity.

### 05 - Link Long Assembly <a name="linkLong"></a>
This step is another placeholder. You need to put the "long" assembly at `data/assembly/asm_long.fa`.
If you followed step 04, you will need to run the following:

```
	cd data/assembly
	ln -s asm_ge500kb.fa asm_long.fa
	cd -
```

If you skipped step four because you already had a really great assembly, you would need to point to the original assembly:

```
	cd data/assembly
	ln -s asm.fa asm_long.fa
	cd -
```

More generally, wherever your assembly (with only the longest sequences) is, copy or link it:

```
	cd data/assembly
	ln -s /path/to/long_subset_assembly/asm.fa asm_long.fa
	cd -
```

### 06 - Index Long Assembly <a name="indexLong"></a>
Similar to step 01, the script associated with this step (`06-indexLongAsm.sh`) will actually complete the step for you.
The goal is to have a Samtools `faidx` index of the "long" assembly located at `data/assembly/asm_long.fa.fai`.
If you already have this (e.g., if you skipped subsetting in step 04), simply copy or link to the existing `*.fai` file.
Otherwise, run this step from the main project directory: `./scripts-msmc/06-indexLongAsm.sh`.

## Alignments of Samples
MSMC needs masks based on alignments of per-sample sequences to the assembly.
These masks are *not* the SNPable mask.
The SNPable masks are sample-independent, while these masks are generated on a per-sample basis.
The per-sample sequences can be short (e.g., Illumina) or long (e.g., PacBio) reads.
If they are PacBio reads, they should be self-corrected.
The assembly must be the "long" assembly, not the original assembly (unless they are the same, which would be fine).

### 07 - Create Samples List <a name="samples"></a>
For some of the remaining steps, actions are performed on a per-sample basis.
To reliably complete the correct tasks and assess their completeness, a simple list of samples must be compiled.
Create a file at called `data/samples.list`. Put one record per line. Each record is the name of the sample.
The sample names need not follow a pattern (e.g., sample1, sample2, ..., sampleN); arbitrary names (e.g., sally, bob, ..., mae) are perfectly valid.
The sample identifiers should be alphanumeric strings without whitespace.
If you have only one sample, you must still create this file!

### 08 - Copy Per-Sample Alignments <a name="copyAlns"></a>
As with the SNPable mask, the creation of it is beyond the scope of this repository; however, [this repo](https://github.com/pickettbd/minimap2AlnPacbToRef-slurmPipeline) will align self-corrected PacBio reads to a genome assembly with Minimap2.
The final alignments for each sample must be in bam format and named after the following pattern: `data/alns/${SAMPLE_NAME}-pacbio-reads_x_asm-long.bam`.
`${SAMPLE_NAME}` must match the sample identifiers in `data/samples.list` created in the previous step.
The bam index file must also be copied or linked.
They can be copied or linked (shown for a single sample called "sample1") to these locations:

```
	mkdir -p data/alns
	cd data/alns
	ln -s /path/to/my/sample1.bam sample1-pacbio-reads_x_asm-long.bam
	ln -s /path/to/my/sample1.bam.bai sample1-pacbio-reads_x_asm-long.bam.bai
	cd ../..
```

If you have them named after a pattern already in another location, you could automate this process doing something like the following:

```
	cd data/alns
	while read SAMPLE
	do
		ln -s /path/to/the/alignments/${SAMPLE}.bam ${SAMPLE}-pacbio-reads_x_asm-long.bam
		ln -s /path/to/the/alignments/${SAMPLE}.bam.bai ${SAMPLE}-pacbio-reads_x_asm-long.bam.bai
	done < ../samples.list
	cd -
```

### 09 - Approximate Depth <a name="approxDepth"></a>
Later scripts require the depth, which can be approximated, for each sample.
The script `09-approxDepth.slurm` will approximate the depth for each sample, each as a separate job on the cluster.
To submit the jobs, simply run `./scripts-msmc/09-approxDepth.submit` from the main project directory.

## MSMC Prep
To prepare to run MSMC, we need to create the input files. The next two steps do just that.

### 10 - Mask <a name="mask"></a>
The script `10-mask.slurm` will create the input mask file for a single "chromosome" (or scaffold/contig) for each sample.
Each will be a separate job on the cluster. Each sample will have the various chromosomes submitted as separate jobs via job arrays.
To submit the jobs, simply run `./scripts-msmc/10-mask.submit` from the main project directory.
The output files will be in `data/masks`.

### 11 - Multihetsep <a name="multihetsep"></a>
The script `11-multihetsep.slurm` will create the input multihetsep file for a single "chromosome" (or scaffold/contig) for all samples together.
Each will be a separate job on the cluster.
To submit the jobs, simply run `./scripts-msmc/11-multihetsep.submit` from the main project directory.
The output files will be in `data/multihetsep`. There will be one file per "chromosome" matching the filename pattern `${SEQUENCE_HEADER}.multihetsep.txt`.

## MSMC (Main)
This is what we have all been waiting for. The input files have been generated, now we just run MSMC.

### 12 - MSMC <a name="MSMC"></a>
The script `msmc.slurm` will run msmc for this set of samples on all chromosomes in a single run.
This will be run on the cluster as a job.
To submit the job, simply run `./scripts-msmc/12-msmc.submit` from the main project directory.
The output files will be in `data/msmc`.

## MSMC Bootstrap
To increase our confidence in our results, we should perform bootstrap replicates of what we already did.
That basically entails generating new multihetsep files for each bootstrap replicate.

### 13 - Generate Random Seed <a name="randomSeed"></a>
To generate random bootstrap replicates of the input data, we need a random number.
You may generate this in any way you wish, but the number must be placed in `data/random_seed-bootstrap.txt`.
This file must consist of a single line with a single number. No whitespace, non-numeric (i.e., 0-9) characters, etc.
These scripts assume a 16-bit unsigned integer, though that may not be strinctly necessary as far as the underlying programs are concerned.
The number is preserved in that file for the sake of reproducibility.
The script `13-getRandomSeed.sh` will generate a random number for you and place it in that file, formatted correctly.
To do so, simply run `./scripts-msmc/13-getRandomSeed.sh` from the main project directory.

### 14 - Multihetsep <a name="multihetsepBoot"></a>
This step generates the bootstrap replicates of the multihetsep files. Each replicate will be located in it's own directory at `data/multihetsep/bootstrap`.
If we were doing 1,000 replicates, the directories would be named `data/multihetsep/bootstrap/round_1`, `data/multihetsep/bootstrap/round_2`, ..., `data/multihetsep/bootstrap/round_1000`.
The contents of each of these directories will have identical file names to the original `data/multihetsep` directory; i.e., `${SEQUENCE_HEADER}.multihetsep.txt`, though the file contents will not be the same.
The script `14-multihetsepBootstrapPrep.slurm` will generate all of these replicates in a single go.
The default number of replicates is 1,000. To change this, edit the scripts.
To run this job on the cluster, run `./scripts-msmc/14-multihetsepBootstrapPrep.submit` from the main project directory.

### 15 - MSMC <a name="MSMCboot"></a>
Each run of `msms.slurm` will run msmc for one set of samples on all chromosomes for a single bootstrap replicate.
Each of the bootstrap replicates will run as a separate job on the cluster; to submit them, run `./scripts-msmc/15-msmcBootstrap.submit` from the main project directory.
The output files for each run will be located in separate directories matching the filepath pattern: `data/msmc/bootstrap/round_${ROUND_NUMBER}`.

### 16 - Combine Bootstrap Results <a name="combineBoot"></a>
This step will combine all the bootstrapped MSMC output files (each called `msmc.final.txt`) into a single file called `data/msmc/bootstrap/msmc-bootstrap_concat.tsv`.
An extra column "Bootstrap_Round" will be prepended to make the data "tidy" for easy use with tidy structures in R.
This step is run locally instead of as a job on the cluster because it is relatively fast (<1 minute).
To combine these bootstrap results, run `./scripts-msmc/16-concatenateMsmcBootstrap.sh` from the main project directory.

## Visualize
Finally, we need to visualize the results. Only one visualization is demonstrated here.
Data visualization is often dataset-dependent; take care to manually explore yourself instead of relying only on the automated version of the plotting script.

### 17 - Plot <a name="plot"></a>
The script `17-plot.sh` will run locally instead of as a job. It will run `plot.R` for you, creating `data/plot.pdf`.
To create the PDF, run `./scripts-msmc/17-plot.sh` from the main project directory.

