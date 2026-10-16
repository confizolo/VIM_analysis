#!/bin/bash
#$ -N plot_densities
#$ -l h_vmem=64G
#$ -l h_rt=04:00:00
#$ -pe sharedmem 4
#$ -o logs/plot_densities.o
#$ -e logs/plot_densities.e
#$ -cwd

. /etc/profile.d/modules.sh
module load R/4.4
source ./config.sh  # submit from the repository root (qsub -cwd)
cd "$VIM_ROOT" || exit 1
Rscript stats/plot_densities.R "$VIM_OUTPUT_DIR"
