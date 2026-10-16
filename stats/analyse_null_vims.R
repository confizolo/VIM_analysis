#!/usr/bin/env Rscript
# --- analyse_null_vims.R ---
# Evaluates Type I error and distributional differences under the null hypothesis.
# Replaces legacy getallnull.R to process modern RDS outputs dynamically.

r_libs <- Sys.getenv("R_LIBS_USER")
if (r_libs != "") .libPaths(c(strsplit(r_libs, ":")[[1]], .libPaths()))
library(dplyr)
library(purrr)

# Configuration
args <- commandArgs(trailingOnly = TRUE)
output_dir <- if(length(args) > 0) args[1] else Sys.getenv("VIM_OUTPUT_DIR")
null_scenarios <- c("null0305", "null0390", "null3305", "null3390")

# VIMs that cannot be treated as variable-level importance scores
skip_vims <- c("VIM_RFlocalfdr",   # FDR-based significance test, not a VIM score
               "VIMSRC_AntiJoint",  # Global forest-level scalar (length 1)
               "VIMSRC_PermJoint",  # Global forest-level scalar (length 1)
               "VIMSRC_RanJoint")   # Global forest-level scalar (length 1)

# Helper to extract a structured vector from a VIM
extract_vim_vector <- function(val, x_names, v_name = "") {
  # All VIMs (including TreeSHAP, SMD, and H2O) are now pre-compacted 
  # into pure named numeric vectors during the generation stage, 
  # so we no longer need to manually parse data frames or hidden lists.
  if (is.null(val)) return(NULL)

  if (is.matrix(val)) {
    if (ncol(val) == nrow(val)) return(rowSums(val, na.rm = TRUE)) # Symmetric interactions
    res <- as.vector(val)
    if (!is.null(rownames(val))) names(res) <- rownames(val)
    return(res)
  }
  if (is.data.frame(val)) {
    if (ncol(val) >= 2) res <- val[, 2, drop = TRUE] else res <- val[, 1, drop = TRUE]
    return(res)
  }
  return(as.vector(val))
}

results_summary <- data.frame()

for (scenario in null_scenarios) {
  scenario_dir <- file.path(output_dir, scenario)
  if (!dir.exists(scenario_dir)) next
  
  # Determine correlation structure from scenario name
  is_3_cor <- grepl("03", scenario)
  n_corr <- if(is_3_cor) 3 else 33
  
  files <- list.files(scenario_dir, pattern = "vims_.*\\.rds$", full.names = TRUE)
  if (length(files) == 0) next
  
  cat(sprintf("Processing %s (%d files)...\n", scenario, length(files)))
  
  # Load all data for this scenario
  all_data <- lapply(files, function(f) {
    res <- tryCatch(readRDS(f), error = function(e) NULL)
    if (is.null(res)) return(NULL)
    res$scenario <- NULL; res$dataset_id <- NULL; res$is_null <- NULL
    res
  })
  all_data <- Filter(Negate(is.null), all_data)
  if (length(all_data) == 0) next
  
  # Get dynamic list of available VIMs
  vim_names <- names(all_data[[1]])
  x_names <- paste0("V", 1:100) # Standard 100 features
  
  for (v_name in vim_names) {
    # Skip VIMs that are not variable-level importance scores
    if (v_name %in% skip_vims) next
    
    corrs <- numeric()
    uncorrs <- numeric()
    
    # MinDepth, SMD, and FindIntMax: lower values indicate higher importance
    is_reverse <- grepl("MinDepth|SMD|FindIntMax", v_name)
    
    for (i in seq_along(all_data)) {
      vim_vec <- extract_vim_vector(all_data[[i]][[v_name]], x_names, v_name)
      if (is.null(vim_vec) || length(vim_vec) < 100) next
      
      corrs <- c(corrs, vim_vec[1:n_corr])
      uncorrs <- c(uncorrs, vim_vec[(n_corr+1):100])
    }
    
    if (length(corrs) == 0) next
    
    # Calculate Empirical Alpha (Type I Error) based on 95th percentile of uncorrelated
    if (is_reverse) {
      alpha_thresh <- quantile(uncorrs, probs = 0.05, na.rm = TRUE)
      type_i_error <- mean(corrs < alpha_thresh, na.rm = TRUE)
    } else {
      alpha_thresh <- quantile(uncorrs, probs = 0.95, na.rm = TRUE)
      type_i_error <- mean(corrs > alpha_thresh, na.rm = TRUE)
    }
    
    # Wilcoxon Test
    w_test <- suppressWarnings(wilcox.test(corrs, uncorrs))
    
    # Quartiles
    q_cor <- quantile(corrs, na.rm = TRUE)
    q_unc <- quantile(uncorrs, na.rm = TRUE)
    
    row <- data.frame(
      Scenario = scenario,
      VIM = v_name,
      Type_I_Error_Empirical = signif(type_i_error, 5),
      Wilcoxon_P_Value = signif(w_test$p.value, 5),
      Cor_Med = signif(q_cor[3], 5),
      Unc_Med = signif(q_unc[3], 5)
    )
    results_summary <- bind_rows(results_summary, row)
  }
}

out_file <- "results/tables/null_analysis_results.csv"
write.csv(results_summary, out_file, row.names = FALSE)
cat("Analysis complete. Results saved to:", out_file, "\n")
