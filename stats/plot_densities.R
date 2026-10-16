#!/usr/bin/env Rscript
# --- plot_densities.R ---
# Generates density plots of VIM distributions (True vs Null vs Correlated Null).
# Replaces legacy int.R plotting logic to process modern RDS outputs dynamically.

r_libs <- Sys.getenv("R_LIBS_USER")
if (r_libs != "") .libPaths(c(strsplit(r_libs, ":")[[1]], .libPaths()))
library(ggplot2)
library(dplyr)

args <- commandArgs(trailingOnly = TRUE)
output_dir <- if(length(args) > 0) args[1] else Sys.getenv("VIM_OUTPUT_DIR")
plot_dir <- "results/figures/density_pdfs"
dir.create(plot_dir, showWarnings = FALSE, recursive = TRUE)

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
  if (is.null(val)) return(NULL)

  # TreeSHAP: 2000x100 local SHAP values → collapse to global importance
  if (grepl("TreeSHAP", v_name) && is.data.frame(val) && nrow(val) > 100) {
    res <- colMeans(abs(val))
    if (!is.null(names(res))) res <- res[order(as.integer(gsub("\\D", "", names(res))))]
    return(res)
  }

  # SMD: extract the $depth vector (surrogate minimal depth per variable)
  if (grepl("SMD", v_name) && is.list(val) && "depth" %in% names(val)) {
    return(as.vector(val$depth))
  }

  # H2O: reorder from importance-sorted to variable-order (V1..V100)
  if (is.data.frame(val) && "relative_importance" %in% names(val)) {
    res <- val$relative_importance
    names(res) <- val$variable
    var_nums <- as.integer(gsub("\\D", "", val$variable))
    res <- res[order(var_nums)]
    return(res)
  }

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
  cat(sprintf("Generating density plots for %s vs %s...\n", scenario, base_null_name))
  
  safe_read <- function(f) {
    tryCatch(readRDS(f), error = function(e) {
      warning(paste("Skipping corrupted file:", f))
      return(NULL)
    })
  }
  
  ha_data <- lapply(ha_files, safe_read)
  ha_data <- ha_data[!sapply(ha_data, is.null)]
  
  null_data <- lapply(null_files, safe_read)
  null_data <- null_data[!sapply(null_data, is.null)]
  vim_names <- setdiff(names(ha_data[[1]]), c("scenario", "dataset_id", "is_null"))
  
  for (v_name in vim_names) {
    # Skip VIMs that are not variable-level importance scores
    if (v_name %in% skip_vims) next
    
    sample_val <- ha_data[[1]][[v_name]]
    is_matrix <- is.matrix(sample_val) && ncol(sample_val) > 1 && nrow(sample_val) == ncol(sample_val)
    
    alt1 <- numeric()
    nul  <- numeric(); cnul <- numeric()
    
    for (i in seq_along(ha_data)) {
      v_ha <- ha_data[[i]][[v_name]]
      v_null <- null_data[[(i - 1) %% length(null_data) + 1]][[v_name]] 
      
      if (is_matrix) {
        if (is.null(v_ha) || is.null(v_null)) next
        v_ha[upper.tri(v_ha, diag = TRUE)] <- NA
        v_null[upper.tri(v_null, diag = TRUE)] <- NA
        alt1 <- c(alt1, as.vector(v_ha[, 1]))
        nul  <- c(nul, as.vector(v_null))
        cnul <- c(cnul, as.vector(v_null[, 1:n_corr]))
      } else {
        v_ha <- normalize_1d(v_ha, v_name)
        v_null <- normalize_1d(v_null, v_name)
        if (is.null(v_ha) || is.null(v_null) || length(v_ha) < 100) next
        alt1 <- c(alt1, v_ha[1])
        nul  <- c(nul, v_null)
        cnul <- c(cnul, v_null[1:n_corr])
      }
    }
    
    alt1 <- alt1[!is.na(alt1)]
    nul <- nul[!is.na(nul)]
    cnul <- cnul[!is.na(cnul)]
    
    if (length(alt1) == 0 || length(nul) == 0) next
    
    plotdata <- rbind(
      data.frame(VIM_values = alt1, variable = "Variable generating the signal"),
      data.frame(VIM_values = nul,  variable = "Uncorrelated noise variables"),
      data.frame(VIM_values = cnul, variable = "Correlated noise variables")
    )
    
    # Canonical publication name from single source of truth
    if (!exists("VIM_MAP")) source("utils/vim_map.R")
    pub_v_name <- if (v_name %in% names(VIM_MAP)) VIM_MAP[[v_name]] else v_name

    try({
      p <- ggplot(plotdata, aes(x = VIM_values, fill = variable)) + 
           geom_density(alpha = 0.3) +
           theme_minimal() +
           labs(title = paste("Density Plot:", pub_v_name, "in", scenario),
                x = "VIM Score", y = "Density") +
           theme(legend.position = "bottom")
      
      png_file <- file.path(plot_dir, paste0(scenario, "_", pub_v_name, "_density.png"))
      ggsave(png_file, plot = p, width = 8, height = 6, dpi = 300)
    }, silent = FALSE)
  }
}
cat("Density plots generated in", plot_dir, "\n")