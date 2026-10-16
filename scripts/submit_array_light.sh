#!/bin/bash
# --- submit_array_light.sh ---
# Massive Job Array for Light VIMs.
# 20 scenarios * 500 datasets = 10000 tasks.
# Each task processes exactly 1 dataset on a single core.

#$ -N vim_array_light
#$ -cwd
#$ -l h_rt=04:00:00
#$ -l h_vmem=8G
#$ -t 1-10000

# 1. Setup Environment
. /etc/profile.d/modules.sh
module load R/4.4
source ./config.sh  # submit from the repository root (qsub -cwd)
cd "$VIM_ROOT" || exit 1

# 2. Define Scenarios (20 total)
SCENARIOS=(
  "null0305" "null0390" "null3305" "null3390"
  "weak0305" "weak0390" "weak3305" "weak3390"
  "weakint0305" "weakint0390" "weakint3305" "weakint3390"
  "strong0305" "strong0390" "strong3305" "strong3390"
  "strongint0305" "strongint0390" "strongint3305" "strongint3390"
)

# 3. Map Task ID to Scenario & Dataset
# SGE_TASK_ID is 1 to 10000
INDEX=$((SGE_TASK_ID - 1))
SCENARIO_IDX=$((INDEX / 500))
DATASET_IDX=$((INDEX % 500 + 1))

SCENARIO=${SCENARIOS[$SCENARIO_IDX]}

if [ -z "$SCENARIO" ]; then
  echo "Error: No scenario found for Task ID $SGE_TASK_ID"
  exit 1
fi

# 4. Execute R Worker for the specific dataset
echo "Processing Light Scenario: $SCENARIO | Dataset: $DATASET_IDX"
Rscript ${VIM_ROOT}/src/analyse_vims_parallel.R "$SCENARIO" "$DATASET_IDX"
