#!/bin/bash
# --- submit_array_heavy_strong.sh ---
# Gap-fill re-run of the heavy VIMs for the strong scenarios that needed more
# memory/runtime (CIF conditional / FCPI). Optional: only needed if
# submit_array_heavy.sh left these datasets incomplete.
# 5 scenarios * 500 datasets = 2500 tasks; results are saved incrementally.

#$ -N vim_array_heavy_gapfill
#$ -cwd
#$ -l h_rt=08:00:00
#$ -l h_vmem=16G
#$ -pe sharedmem 1
#$ -t 1-2500

# 1. Setup Environment
. /etc/profile.d/modules.sh
module load R/4.4
source ./config.sh  # submit from the repository root (qsub -cwd)
cd $VIM_ROOT || exit 1

# 2. Define Scenarios (5 scenarios requiring Party Conditional / FCPI)
SCENARIOS=(
  "strong3390"
  "strongint0305" "strongint0390" "strongint3305" "strongint3390"
)

# 3. Map Task ID to Scenario & Dataset
# SGE_TASK_ID is 1 to 2500
INDEX=$((SGE_TASK_ID - 1))
SCENARIO_IDX=$((INDEX / 500))
DATASET_IDX=$((INDEX % 500 + 1))

SCENARIO=${SCENARIOS[$SCENARIO_IDX]}

if [ -z "$SCENARIO" ]; then
  echo "Error: No scenario found for Task ID $SGE_TASK_ID"
  exit 1
fi

# 4. Execute R Worker for the specific dataset
echo "Processing Heavy Scenario: $SCENARIO | Dataset: $DATASET_IDX"
Rscript ${VIM_ROOT}/src/analyse_vims_heavy.R "$SCENARIO" "$DATASET_IDX"
