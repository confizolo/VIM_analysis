# --- analyse_vims_parallel.R ---
# Stable Two-Phase Scenario Worker. 
# Phase 1: R-VIMs in Parallel (mclapply)

r_libs <- Sys.getenv("R_LIBS_USER")
if (r_libs != "") .libPaths(c(strsplit(r_libs, ":")[[1]], .libPaths()))
library(randomForest)
library(parallel)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript analyse_vims_parallel.R <scenario_name> [dataset_id]")
scenario_name <- args[1]
dataset_id_arg <- if (length(args) >= 2) args[2] else NULL

vim_root <- Sys.getenv("VIM_ROOT")
source(file.path(vim_root, "src", "vim_core.R"))

config <- list(
  scenario    = scenario_name,
  input_base  = Sys.getenv("VIM_INPUT_BASE"),
  output_dir  = Sys.getenv("VIM_OUTPUT_DIR"),
  seed_file   = Sys.getenv("VIM_SEED_FILE"),
  n_limit     = as.integer(Sys.getenv("VIM_N_LIMIT", "500")),
  ntree       = 1000,
  mtry        = 33
)

seeds <- as.integer(readLines(config$seed_file))
input_dir <- file.path(config$input_base, config$scenario)
output_scenario_dir <- file.path(config$output_dir, config$scenario)
dir.create(output_scenario_dir, showWarnings = FALSE, recursive = TRUE)


process_r_vims <- function(file_path) {
  raw_id <- sub(".*\\.txt\\.", "", basename(file_path))
  dataset_idx <- as.integer(raw_id)
  dataset_id  <- sprintf("%03d", dataset_idx)
  
  rds_path <- file.path(output_scenario_dir, sprintf("vims_%s.rds", dataset_id))
  
  rf_keys <- c("VIMRF_Gini", "VIMRF_P", "VIMRF_Pscaled", "VIMRF_iBranchBranch", "VIMRF_iBranchTree", "VIMRF_Single")
  if (has_ipmrf) rf_keys <- c(rf_keys, "VIMRF_IPM")
  if (has_rflocalfdr) rf_keys <- c(rf_keys, "VIM_RFlocalfdr")
  if (has_vip) rf_keys <- c(rf_keys, "VIM_FIRM")

  ranger_keys <- c("VIMRanger_AIR")
  if (has_sobolmda) ranger_keys <- c(ranger_keys, "VIM_SobolMDA")
  if (has_treeshap) ranger_keys <- c(ranger_keys, "VIM_TreeSHAP")

  party_keys <- c("VIMParty_Ppre", "VIMParty_P", "VIMParty_AUC", "VIMParty_Count", "VIMParty_IPM")

  expected_keys <- c(rf_keys, ranger_keys, party_keys)
  
  res <- list(scenario = config$scenario, dataset_id = dataset_id)
  if (file.exists(rds_path)) {
    res <- readRDS(rds_path)
    if (all(expected_keys %in% names(res))) return(TRUE)
  }

  data <- try(read.table(file_path, header = TRUE))
  if (inherits(data, "try-error")) return(NULL)
  if (dataset_idx <= length(seeds)) set.seed(seeds[dataset_idx])
  
  y <- data$y
  x <- data[, -which(names(data) == "y")]
  x_names <- colnames(x)
  
  # Explicitly check conditions before running modules
  if (!all(rf_keys %in% names(res))) {
    res <- run_vims_randomForest(x, y, x_names, config, res)
  }
  
  if (!all(ranger_keys %in% names(res))) {
    res <- run_vims_ranger(x, y, config, res)
  }
  
  if (!all(party_keys %in% names(res))) {
    res <- run_vims_party_std(x, y, config, res)
  }

  saveRDS(res, rds_path)
  return(TRUE)
}

files <- list.files(input_dir, pattern = paste0(config$scenario, "\\.txt\\.[0-9]+"), full.names = TRUE)
if (!is.null(dataset_id_arg)) {
  target_pattern <- paste0("\\.txt\\.", as.integer(dataset_id_arg), "$")
  files <- files[grep(target_pattern, files)]
} else {
  files <- files[1:min(length(files), config$n_limit)]
}

if (length(files) == 0) stop(sprintf("No datasets found in %s", input_dir))

cat(sprintf("\nProcessing Light R-VIMs for %s (%d files) sequentially...\n", config$scenario, length(files)))

for (f in files) {
  process_r_vims(f)
}

cat("Done.\n")
