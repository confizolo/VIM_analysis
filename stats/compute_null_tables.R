#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
data_dir <- if(length(args) > 0) args[1] else Sys.getenv("VIM_OUTPUT_DIR")

scenarios <- c("null0305", "null0390", "null3305", "null3390")

skip_vims <- c("VIM_RFlocalfdr", "VIMSRC_AntiJoint", "VIMSRC_PermJoint", "VIMSRC_RanJoint")

normalize_1d <- function(val, v_name = "") {
  if (is.null(val)) return(NULL)
  if (grepl("TreeSHAP", v_name) && is.data.frame(val) && nrow(val) > 100) {
    res <- colMeans(abs(val))
    if (!is.null(names(res))) res <- res[order(as.integer(gsub("\\D", "", names(res))))]
    return(res)
  }
  if (grepl("SMD", v_name) && is.list(val) && "depth" %in% names(val)) return(as.vector(val$depth))
  if (is.data.frame(val) && "relative_importance" %in% names(val)) {
    res <- val$relative_importance
    names(res) <- val$variable
    var_nums <- as.integer(gsub("\\D", "", val$variable))
    return(res[order(var_nums)])
  }
  if (is.data.frame(val)) {
    res <- if (ncol(val) >= 2) val[, 2, drop = TRUE] else val[, 1, drop = TRUE]
    if (!is.null(val[, 1]) && ncol(val) >= 2) names(res) <- val[, 1, drop = TRUE]
    return(res)
  }
  return(as.vector(val))
}

source("utils/vim_map.R")

all_results <- data.frame()

for (scenario in scenarios) {
  scen_dir <- file.path(data_dir, scenario)
  if (!dir.exists(scen_dir)) next
  files <- list.files(scen_dir, pattern = "\\.rds$", full.names = TRUE)
  if (length(files) == 0) next
  
  n_corr <- if(grepl("03", scenario)) 3 else 33
  
  # Accumulate all values for each VIM across all datasets
  vim_data <- list()
  
  for (f in files) {
    res <- tryCatch(readRDS(f), error = function(e) NULL)
    if (is.null(res)) next
    
    for (v_name in names(res)) {
      if (v_name %in% c("scenario", "dataset_id", "is_null") || v_name %in% skip_vims) next
      val <- res[[v_name]]
      is_matrix <- is.matrix(val) && ncol(val) > 1 && nrow(val) == ncol(val)
      
      if (is_matrix) {
        # Mask only diagonal (self-pairings), mirroring legacy approach
        diag(val) <- NA
        vec <- as.vector(val[, 1])
      } else {
        vec <- normalize_1d(val, v_name)
      }
      
      if (is.null(vec) || length(vec) < 100) next
      
      if (is.null(vim_data[[v_name]])) {
        vim_data[[v_name]] <- list(corr = numeric(), uncorr = numeric())
      }
      
      vim_data[[v_name]]$corr <- c(vim_data[[v_name]]$corr, vec[1:n_corr])
      vim_data[[v_name]]$uncorr <- c(vim_data[[v_name]]$uncorr, vec[(n_corr+1):100])
    }
  }
  
  for (v_name in names(vim_data)) {
    c_vals <- vim_data[[v_name]]$corr
    u_vals <- vim_data[[v_name]]$uncorr
    c_vals <- c_vals[!is.na(c_vals)]
    u_vals <- u_vals[!is.na(u_vals)]
    
    if (length(c_vals) == 0 || length(u_vals) == 0) next
    
    # Type I error: proportion of correlated null values beyond the 95th
    # percentile of the uncorrelated null values. Minimal-depth VIMs (MD, SMD)
    # rank lower values as more important, so the lower (5th) tail is used.
    # VIMRF-CMD (FindIntMax) is an asymmetric pairwise matrix with no
    # per-variable direction, so its type I error is not defined (NA).
    is_reverse <- grepl("MinDepth|SMD", v_name)
    if (grepl("FindIntMax", v_name)) {
      type_1_err <- NA
    } else if (is_reverse) {
      threshold <- quantile(u_vals, 0.05, na.rm = TRUE)
      type_1_err <- mean(c_vals < threshold, na.rm = TRUE)
    } else {
      threshold <- quantile(u_vals, 0.95, na.rm = TRUE)
      type_1_err <- mean(c_vals > threshold, na.rm = TRUE)
    }
    
    # Wilcoxon rank sum test
    wt <- suppressWarnings(wilcox.test(c_vals, u_vals, alternative = "two.sided"))
    
    pub_name <- if (v_name %in% names(VIM_MAP)) VIM_MAP[[v_name]] else v_name
    
    all_results <- rbind(all_results, data.frame(
      Scenario = scenario,
      VIM = pub_name,
      Type1_Error = type_1_err,
      Wilcoxon_P = wt$p.value
    ))
  }
}

write.csv(all_results, "results/tables/null_tables.csv", row.names = FALSE)
