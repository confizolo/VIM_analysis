#!/usr/bin/env Rscript
# --- analyse_bias_coverage.R ---
# Evaluates bias and coverage for regression models (Linear or Logistic).
# Adapted from legacy orci.R to process standard dataset files dynamically.

r_libs <- Sys.getenv("R_LIBS_USER")
if (r_libs != "") .libPaths(c(strsplit(r_libs, ":")[[1]], .libPaths()))
library(dplyr)

args <- commandArgs(trailingOnly = TRUE)
data_dir <- if(length(args) > 0) args[1] else Sys.getenv("VIM_INPUT_BASE")
scenario <- if(length(args) > 1) args[2] else "strong0305"
n_datasets <- if(length(args) > 2) as.integer(args[3]) else 500

# Specify true parameters dynamically based on scenario
if (grepl("null", scenario)) {
  true_beta_1 <- 0
  true_beta_2 <- 0
  true_beta_int <- 0
} else if (grepl("weakint", scenario)) {
  true_beta_1 <- 0.06
  true_beta_2 <- 0.06
  true_beta_int <- 0.095
} else if (grepl("strongint", scenario)) {
  true_beta_1 <- 0.06
  true_beta_2 <- 0.06
  true_beta_int <- 0.14
} else if (grepl("weak", scenario)) {
  # Main effect only
  true_beta_1 <- 0.09
  true_beta_2 <- 0
  true_beta_int <- 0
} else if (grepl("strong", scenario)) {
  # Main effect only
  true_beta_1 <- 0.12   # matches the data generator (sim*strong.R: b1 = 0.12)
  true_beta_2 <- 0
  true_beta_int <- 0
} else {
  # Fallback
  true_beta_1 <- 0
  true_beta_2 <- 0
  true_beta_int <- 0
} 

cat(sprintf("Running Bias & Coverage Analysis on %s (%d datasets)...\n", scenario, n_datasets))

results <- data.frame()

for (i in 1:n_datasets) {
  # Support common file naming patterns on Eddie
  file_path <- file.path(data_dir, scenario, paste0(scenario, ".txt.", i))
  if (!file.exists(file_path)) {
    file_path <- file.path(data_dir, paste0(scenario, ".txt.", i))
    if (!file.exists(file_path)) next
  }
  
  # Most modern datasets here have headers, but if they don't, we need to handle it.
  # The worker scripts assume header=TRUE and v1, v2 etc. are assigned automatically 
  # if missing, or present in the file.
  tryCatch({
    data <- read.table(file_path, header = TRUE)
    
    # If the file had no header but read.table consumed the first row, we'll
    # assume the standard structure: y, v1, v2, ...
    if(ncol(data) > 0 && !("y" %in% names(data))) {
       data <- read.table(file_path, header = FALSE)
       names(data) <- c("y", paste0("v", 1:(ncol(data)-1)))
    }

    # Check if binary or continuous outcome
    is_binary <- length(unique(data$y)) == 2
    
    # Fit the appropriate model
    if (is_binary) {
      model <- glm(y ~ v1 + v100 + v1:v100, data = data, family = binomial(link = "logit"))
    } else {
      model <- lm(y ~ v1 + v100 + v1:v100, data = data)
    }
    
    sm <- summary(model)
    coefs <- sm$coefficients
    
    # Helper to extract bias, coverage, and p-value
    get_bc <- function(term, true_val) {
      if (term %in% rownames(coefs)) {
        est <- coefs[term, 1]
        se <- coefs[term, 2]
        pval <- coefs[term, 4]
        bias <- est - true_val
        lb <- est - (1.96 * se)
        ub <- est + (1.96 * se)
        cover <- as.integer(true_val >= lb && true_val <= ub)
        return(c(bias, cover, pval))
      }
      return(c(NA, NA, NA))
    }
    
    v1_res <- get_bc("v1", true_beta_1)
    v2_res <- get_bc("v100", true_beta_2)
    int_res <- get_bc("v1:v100", true_beta_int)
    
    results <- bind_rows(results, data.frame(
      Dataset = i,
      Bias_v1 = v1_res[1], Cover_v1 = v1_res[2], P_v1 = v1_res[3],
      Bias_v100 = v2_res[1], Cover_v100 = v2_res[2], P_v100 = v2_res[3],
      Bias_Int = int_res[1], Cover_Int = int_res[2], P_Int = int_res[3]
    ))
  }, error = function(e) {
    cat(sprintf("Error processing dataset %d: %s\n", i, e$message))
  })
}

if (nrow(results) > 0) {
  summary_stats <- data.frame(
    Scenario = scenario,
    Mean_Bias_v1 = mean(results$Bias_v1, na.rm = TRUE),
    Coverage_v1 = mean(results$Cover_v1, na.rm = TRUE),
    Median_P_v1 = median(results$P_v1, na.rm = TRUE),
    Sig_P_v1 = mean(results$P_v1 < 0.05, na.rm = TRUE),
    Mean_Bias_v100 = mean(results$Bias_v100, na.rm = TRUE),
    Coverage_v100 = mean(results$Cover_v100, na.rm = TRUE),
    Median_P_v100 = median(results$P_v100, na.rm = TRUE),
    Sig_P_v100 = mean(results$P_v100 < 0.05, na.rm = TRUE),
    Mean_Bias_Int = mean(results$Bias_Int, na.rm = TRUE),
    Coverage_Int = mean(results$Cover_Int, na.rm = TRUE),
    Median_P_Int = median(results$P_Int, na.rm = TRUE),
    Sig_P_Int = mean(results$P_Int < 0.05, na.rm = TRUE)
  )
  
  print(summary_stats)
  
  out_dir_bc <- "results/tables/bias_coverage"
  dir.create(out_dir_bc, showWarnings = FALSE, recursive = TRUE)
  write.csv(results, file.path(out_dir_bc, paste0("results_", scenario, ".csv")), row.names = FALSE)
  write.csv(summary_stats, file.path(out_dir_bc, paste0("summary_", scenario, ".csv")), row.names = FALSE)
  cat("\nResults saved to", out_dir_bc, "directory.\n")
} else {
  cat("No data processed. Check file paths and dataset structure.\n")
}
