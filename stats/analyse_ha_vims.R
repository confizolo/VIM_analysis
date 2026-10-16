#!/usr/bin/env Rscript
# --- analyse_ha_vims.R ---
# Evaluates empirical power under HA (alternative hypothesis).
# Accurately mirrors getallmain.R (Main Effects) and getallint.R (Interactions)
# Handles 1D VIMs and 2D paired VIMs (matrices).

library(dplyr)

args <- commandArgs(trailingOnly = TRUE)
output_dir <- if(length(args) > 0) args[1] else Sys.getenv("VIM_OUTPUT_DIR")

ha_main_scenarios <- c("weak0305", "weak0390", "strong0305", "strong0390", 
                       "weak3305", "weak3390", "strong3305", "strong3390")
ha_int_scenarios <- c("weakint0305", "weakint0390", "strongint0305", "strongint0390", 
                      "weakint3305", "weakint3390", "strongint3305", "strongint3390")

all_ha_scenarios <- c(ha_main_scenarios, ha_int_scenarios)

# VIMs that cannot be treated as variable-level importance scores
skip_vims <- c("VIM_RFlocalfdr",   # FDR-based significance test, not a VIM score
               "VIMSRC_AntiJoint",  # Global forest-level scalar (length 1)
               "VIMSRC_PermJoint",  # Global forest-level scalar (length 1)
               "VIMSRC_RanJoint")   # Global forest-level scalar (length 1)

# Helper to normalise 1D VIMs to a length-100 named vector
normalize_1d <- function(val, v_name = "") {
  # All VIMs (including TreeSHAP, SMD, and H2O) are now pre-compacted 
  # into pure named numeric vectors during the generation stage, 
  # so we no longer need to manually parse data frames or hidden lists.

  # FIRM: tibble with (variable, importance) columns
  if (is.data.frame(val)) {
    if (ncol(val) >= 2) {
      res <- val[, 2, drop = TRUE]
      if (!is.null(val[, 1])) names(res) <- val[, 1, drop = TRUE]
    } else {
      res <- val[, 1, drop = TRUE]
    }
    return(res)
  }

  return(as.vector(val))
}

results_summary <- data.frame()

for (scenario in all_ha_scenarios) {
  ha_dir <- file.path(output_dir, scenario)
  
  is_int <- grepl("int", scenario)
  is_3_cor <- grepl("03", scenario)
  base_null_name <- paste0("null", if(is_3_cor) "03" else "33", sub(".*(05|90).*", "\\1", scenario))
  null_dir <- file.path(output_dir, base_null_name)
  
  if (!dir.exists(ha_dir) || !dir.exists(null_dir)) next
  
  n_corr <- if(is_3_cor) 3 else 33
  ha_files <- list.files(ha_dir, pattern = "vims_.*\\.rds$", full.names = TRUE)
  null_files <- list.files(null_dir, pattern = "vims_.*\\.rds$", full.names = TRUE)
  
  if (length(ha_files) == 0 || length(null_files) == 0) next
  cat(sprintf("Processing HA Scenario: %s vs Null: %s\n", scenario, base_null_name))
  
  ha_data <- lapply(ha_files, function(f) tryCatch(readRDS(f), error = function(e) NULL))
  null_data <- lapply(null_files, function(f) tryCatch(readRDS(f), error = function(e) NULL))
  
  ha_data <- Filter(Negate(is.null), ha_data)
  null_data <- Filter(Negate(is.null), null_data)
  
  if (length(ha_data) == 0 || length(null_data) == 0) next
  
  vim_names <- setdiff(names(ha_data[[1]]), c("scenario", "dataset_id", "is_null"))
  
  for (v_name in vim_names) {
    # Skip VIMs that are not variable-level importance scores
    if (v_name %in% skip_vims) next
    
    # MinDepth and SMD and FindIntMax: lower values indicate higher importance
    is_reverse <- grepl("MinDepth|SMD|FindIntMax", v_name)
    
    # Check if this VIM is a matrix (paired)
    sample_val <- ha_data[[1]][[v_name]]
    is_matrix <- is.matrix(sample_val) && ncol(sample_val) > 1 && nrow(sample_val) == ncol(sample_val)
    
    alt1 <- numeric(); alt2 <- numeric(); coralt <- numeric()
    nul  <- numeric(); cnul <- numeric()
    
    for (i in seq_along(ha_data)) {
      v_ha <- ha_data[[i]][[v_name]]
      # Null dataset matching (reuse if we have fewer nulls than HAs)
      v_null <- null_data[[(i - 1) %% length(null_data) + 1]][[v_name]] 
      
      if (is_matrix) {
        # --- 2D Paired VIMs (e.g. iBranchBranch, FindIntVimp) ---
        if (is.null(v_ha) || is.null(v_null)) next
        
        # Mask only the diagonal (self-pairings), mirroring the legacy int.R approach.
        # The full symmetric matrix is kept, so column j has all 99 pairwise values
        # for variable j against every other variable.
        diag(v_ha)   <- NA
        diag(v_null) <- NA
        
        if (is_int) {
          # getallint.R Logic (mirrors legacy int.R lines 767-772)
          alt1 <- c(alt1, as.vector(v_ha[, 1]))    # All 99 pairings of V1 vs all others
          alt2 <- c(alt2, as.vector(v_ha[, 100]))  # All 99 pairings of V100 vs all others
          
          # Interaction-specific signal: the specific V1-V100 cell
          coralt <- c(coralt, v_ha[1, 100])
          
          nul  <- c(nul, as.vector(v_null))
          cnul <- c(cnul, as.vector(v_null[, 1:n_corr]))
        } else {
          # getallmain.R Logic
          alt1 <- c(alt1, as.vector(v_ha[, 1]))       # V1 vs all
          coralt <- c(coralt, as.vector(v_ha[2:n_corr, 2:n_corr])) # Correlated var pairs
          
          nul  <- c(nul, as.vector(v_null))
          cnul <- c(cnul, as.vector(v_null[, 1:n_corr]))
        }
        
      } else {
        # --- 1D Single VIMs ---
        v_ha <- normalize_1d(v_ha, v_name)
        v_null <- normalize_1d(v_null, v_name)
        if (is.null(v_ha) || is.null(v_null) || length(v_ha) < 100) next
        
        if (is_int) {
          # getallint.R Logic
          alt1 <- c(alt1, v_ha[1])
          alt2 <- c(alt2, v_ha[100])
          
          nul  <- c(nul, v_null)
          cnul <- c(cnul, v_null[1:n_corr])
          coralt <- c(coralt, v_ha[2:n_corr])
        } else {
          # getallmain.R Logic
          alt1 <- c(alt1, v_ha[1])
          
          nul  <- c(nul, v_null)
          cnul <- c(cnul, v_null[1:n_corr])
          coralt <- c(coralt, v_ha[2:n_corr])
        }
      }
    }
    
    # Remove NAs created by matrix masking
    alt1 <- alt1[!is.na(alt1)]
    alt2 <- alt2[!is.na(alt2)]
    coralt <- coralt[!is.na(coralt)]
    nul <- nul[!is.na(nul)]
    cnul <- cnul[!is.na(cnul)]
    
    if (length(alt1) == 0 || length(nul) == 0) next
    
    # Calculate Power / Error based on percentiles
    if (is_reverse) {
      thresh_all   <- quantile(nul, probs = 0.05, na.rm = TRUE)
      thresh_corr  <- quantile(cnul, probs = 0.05, na.rm = TRUE)
      thresh_other <- quantile(coralt, probs = 0.05, na.rm = TRUE)
      
      power_null1  <- mean(alt1 < thresh_all, na.rm = TRUE)
      power_cnull  <- mean(alt1 < thresh_corr, na.rm = TRUE)
      diff_ha      <- mean(alt1 < thresh_other, na.rm = TRUE)
      
      power_null2  <- if(is_int) mean(alt2 < thresh_all, na.rm = TRUE) else NA
    } else {
      thresh_all   <- quantile(nul, probs = 0.95, na.rm = TRUE)
      thresh_corr  <- quantile(cnul, probs = 0.95, na.rm = TRUE)
      thresh_other <- quantile(coralt, probs = 0.95, na.rm = TRUE)
      
      power_null1  <- mean(alt1 > thresh_all, na.rm = TRUE)
      power_cnull  <- mean(alt1 > thresh_corr, na.rm = TRUE)
      diff_ha      <- mean(alt1 > thresh_other, na.rm = TRUE)
      
      power_null2  <- if(is_int) mean(alt2 > thresh_all, na.rm = TRUE) else NA
    }
    
    # Wilcoxon Tests
    w1 <- suppressWarnings(wilcox.test(alt1, nul))
    w2 <- suppressWarnings(wilcox.test(alt1, cnul))
    
    row <- data.frame(
      Scenario = scenario,
      VIM = v_name,
      Power_Null1 = signif(power_null1, 5),
      Power_CNull = signif(power_cnull, 5),
      Diff_HA = signif(diff_ha, 5),
      W_PVal_All = signif(w1$p.value, 5),
      W_PVal_Corr = signif(w2$p.value, 5)
    )
    
    if (is_int) {
      if (length(alt2) > 0) {
        w3 <- suppressWarnings(wilcox.test(alt2, nul))
        row$Power_Null2 <- signif(power_null2, 5)
        row$W_PVal_Alt2_All <- signif(w3$p.value, 5)
      } else {
        row$Power_Null2 <- NA
        row$W_PVal_Alt2_All <- NA
      }
      
      if (is_matrix) {
        # True interaction signal test
        if (length(coralt) > 0) {
          thresh_int_null <- if (is_reverse) thresh_all else thresh_all
          power_int <- if (is_reverse) mean(coralt < thresh_all, na.rm=T) else mean(coralt > thresh_all, na.rm=T)
          w4 <- suppressWarnings(wilcox.test(coralt, nul))
          row$Power_Int <- signif(power_int, 5)
          row$W_PVal_Int_All <- signif(w4$p.value, 5)
        } else {
          row$Power_Int <- NA
          row$W_PVal_Int_All <- NA
        }
      }
    }
    
    results_summary <- bind_rows(results_summary, row)
  }
}

out_file <- "results/tables/ha_analysis_results.csv"
write.csv(results_summary, out_file, row.names = FALSE)
cat("HA Analysis complete. Results saved to:", out_file, "\n")
