# --- analyse_vims_heavy.R ---
# Heavy Memory VIM Workflow
# Processes memory-intensive VIMs (RFSRC, permimp, RFSurrogates)

r_libs <- Sys.getenv("R_LIBS_USER")
if (r_libs != "") .libPaths(c(strsplit(r_libs, ":")[[1]], .libPaths()))
library(randomForest)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript analyse_vims_heavy.R <scenario_name> [dataset_id]")
scenario_name <- args[1]
dataset_id_arg <- if (length(args) >= 2) args[2] else NULL

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

vim_root <- Sys.getenv("VIM_ROOT")
source(file.path(vim_root, "src", "vim_core.R"))

process_heavy_vims <- function(file_path) {
  raw_id <- sub(".*\\.txt\\.", "", basename(file_path))
  dataset_idx <- as.integer(raw_id)
  
  rds_f1 <- file.path(output_scenario_dir, sprintf("vims_%03d.rds", dataset_idx))
  rds_f2 <- file.path(output_scenario_dir, sprintf("results_%d.rds", dataset_idx))
  rds_path <- if (file.exists(rds_f1)) rds_f1 else if (file.exists(rds_f2)) rds_f2 else rds_f1
  
  if (!file.exists(rds_path)) return(FALSE)
  res <- readRDS(rds_path)
  
  rfsrc_keys <- c("VIMSRC_MinDepth", "VIMSRC_FindIntMax", "VIMSRC_Anti", "VIMSRC_AntiJoint", "VIMSRC_PermJoint", "VIMSRC_Random", "VIMSRC_RanJoint", "VIMSRC_Permute", "VIMSRC_FindIntVimp", "VIMSRC_Holdout")
  party_cond_keys <- c("VIMParty_Conditional", "VIMPermimp_Conditional")
  rfsurr_keys <- c("VIM_MIR", "VIM_SMD")
  
  expected_keys <- c(rfsrc_keys, party_cond_keys, rfsurr_keys)
  if (has_h2o) expected_keys <- c(expected_keys, "VIMH2O")
  if (all(expected_keys %in% names(res))) {
    cat(sprintf("All requested heavy VIMs already complete for %s (dataset %d) — skipping.\n", config$scenario, dataset_idx))
    return(TRUE)
  }
  
  data <- try(read.table(file_path, header = TRUE))
  if (inherits(data, "try-error")) return(FALSE)
  
  seed <- if (dataset_idx <= length(seeds)) seeds[dataset_idx] else NULL
  if (!is.null(seed)) set.seed(seed)
  n_threads <- as.integer(Sys.getenv("NSLOTS", "1"))
  
  y <- data$y
  x <- data[, -which(names(data) == "y")]
  x_names <- colnames(x)
  
  if (!all(rfsrc_keys %in% names(res))) {
    cat("Running RFSRC module...\n")
    res <- run_vims_rfsrc(x, y, x_names, data, config, res, n_threads)
    saveRDS(res, rds_path)
  }

  if (!all(party_cond_keys %in% names(res))) {
    cat("Running Party Conditional module...\n")
    res <- run_vims_party_conditional(x, y, config, res, n_threads)
    saveRDS(res, rds_path)
  }
  
  if (!all(rfsurr_keys %in% names(res))) {
    cat("Running RFSurrogates module...\n")
    res <- run_vims_rfsurrogates(x, y, config, res, n_threads, seed)
    saveRDS(res, rds_path)
  }
  
  if (has_h2o && !("VIMH2O" %in% names(res))) {
    cat("Running H2O module...\n")
    res <- run_vims_h2o(x, y, config, res, n_threads)
    saveRDS(res, rds_path)
  }

  return(TRUE)
}

files <- list.files(input_dir, pattern = paste0(config$scenario, "\\.txt\\.[0-9]+"), full.names = TRUE)
if (!is.null(dataset_id_arg)) {
  target_pattern <- paste0("\\.txt\\.", as.integer(dataset_id_arg), "$")
  files <- files[grep(target_pattern, files)]
} else {
  files <- files[1:min(length(files), config$n_limit)]
}

n_cores <- as.integer(Sys.getenv("NSLOTS", "1"))
cat(sprintf("\nProcessing Heavy VIMs for %s sequentially on %d threads...\n", config$scenario, n_cores))

for (f in files) {
  process_heavy_vims(f)
}

cat("Done.\n")
