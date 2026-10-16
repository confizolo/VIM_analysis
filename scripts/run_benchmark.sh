#!/bin/bash
#$ -N custom_benchmark
#$ -cwd
#$ -pe sharedmem 8
#$ -l h_rt=12:00:00
#$ -l h_vmem=8G
#$ -o logs/custom_bench.log
#$ -e logs/custom_bench.err

# 1. Setup Environment
. /etc/profile.d/modules.sh
module load R/4.4
source ./config.sh  # submit from the repository root (qsub -cwd)
cd "$VIM_ROOT" || exit 1

# 2. Execute Custom Benchmark
Rscript src/benchmark.R ${VIM_INPUT_BASE}/strong0305/strong0305.txt.1 ${VIM_OUTPUT_DIR}/custom_benchmark_results.csv
