#!/usr/bin/env Rscript
# --- custom_benchmark.R ---
# Explicitly benchmarks EVERY SINGLE VIM individually (27+ VIMs).
# Runs on both 1 core and 16 cores.

r_libs <- Sys.getenv("R_LIBS_USER")
if (r_libs != "") .libPaths(c(strsplit(r_libs, ":")[[1]], .libPaths()))

suppressPackageStartupMessages({
  require(randomForest, quietly=TRUE)
  require(ranger, quietly=TRUE)
  require(party, quietly=TRUE)
  require(randomForestSRC, quietly=TRUE)
  require(h2o, quietly=TRUE)
  require(permimp, quietly=TRUE)
  require(RFSurrogates, quietly=TRUE)
  require(treeshap, quietly=TRUE)
  require(IPMRF, quietly=TRUE)
})

args <- commandArgs(trailingOnly = TRUE)
input_path <- if (length(args) > 0) args[1] else file.path(Sys.getenv("VIM_INPUT_BASE"), "strong0305", "strong0305.txt.1")
out_csv <- if (length(args) > 1) args[2] else "custom_benchmark_results.csv"

# Shared Helpers
get_ibranch_branch <- function(rf, ntree, x_names) {
  n_vars <- length(x_names)
  ibranch <- matrix(0, nrow = n_vars, ncol = n_vars)
  for (nt in 1:ntree) {
    branch <- getTree(rf, k = nt)
    branch1 <- branch[branch[,3] != 0,]
    if (nrow(branch1) == 0) next
    s1 <- branch1[,3]; p1 <- branch1[1,3]
    t1 <- table(s1)
    for (a in 1:length(t1)) {
      v_idx <- as.integer(names(t1)[a])
      ibranch[min(v_idx, p1), max(v_idx, p1)] <- ibranch[min(v_idx, p1), max(v_idx, p1)] + as.vector(t1[a])
    }
    ibranch[p1, p1] <- ibranch[p1, p1] - 1
  }
  return(ibranch)
}

get_ibranch_tree <- function(rf, ntree, x_names) {
  n_vars <- length(x_names)
  v1 <- varUsed(rf, by.tree = TRUE, count = FALSE)
  countmat <- matrix(0, nrow = n_vars, ncol = n_vars)
  for (i in 1:length(v1)) {
    used <- v1[[i]]
    if (length(used) < 2) next
    for (j in 1:(length(used)-1)) {
      for (k in (j+1):length(used)) {
        v1_idx <- used[j]; v2_idx <- used[k]
        countmat[v1_idx, v2_idx] <- countmat[v1_idx, v2_idx] + 1
      }
    }
  }
  return(countmat)
}

count_party <- function(forest, inames = NULL) {
  if (is.null(inames) && extends(class(forest), "RandomForest"))
    inames <- names(forest@data@get("input"))
  resultvec <- rep(0, length(inames))
  myfunc <- function(x, inames, resultvec) {
    names(x) <- c("nodeID", "weights", "criterion", "terminal", "psplit", "ssplits", "prediction", "left", "right")
    if (!x$terminal) {
      resultvec[x$psplit[[1]]] <- resultvec[x$psplit[[1]]] + 1
      resultvec <- myfunc(x$left, inames = inames, resultvec = resultvec)
      resultvec <- myfunc(x$right, inames = inames, resultvec = resultvec)
    }
    return(resultvec)
  }
  for (k in 1:length(forest@ensemble)) resultvec <- myfunc(forest@ensemble[[k]], inames, resultvec)
  return(resultvec)
}

data <- read.table(input_path, header = TRUE)
y <- data$y
x <- data[, -which(names(data) == "y")]
x_names <- colnames(x)
config <- list(ntree = 1000, mtry = 33)

results <- data.frame(VIM = character(), Cores = integer(), Time_Secs = numeric(), stringsAsFactors = FALSE)

log_time <- function(vim_name, cores, t_start) {
  elapsed <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
  cat(sprintf("[ %-25s ] %d Cores: %.2f seconds\n", vim_name, cores, elapsed))
  results <<- rbind(results, data.frame(VIM = vim_name, Cores = cores, Time_Secs = elapsed))
}

run_benchmark <- function(n_cores) {
  cat(sprintf("\n============================================\n   STARTING BENCHMARK WITH %d CORES\n============================================\n\n", n_cores))
  
  # --- randomForest Suite ---
  t0 <- Sys.time()
  rf <- randomForest(x = x, y = y, ntree = config$ntree, mtry = config$mtry, replace = FALSE, importance = TRUE, keep.forest = TRUE, keep.inbag = TRUE)
  log_time("Model-Build-randomForest", n_cores, t0)
  
  t0 <- Sys.time(); imp_rf <- randomForest::importance(rf); log_time("VIMRF-Gini", n_cores, t0)
  t0 <- Sys.time(); p_unscaled <- randomForest::importance(rf, type = 1, scale = FALSE); log_time("VIMRF-P", n_cores, t0)
  t0 <- Sys.time(); p_scaled <- randomForest::importance(rf, type = 1, scale = TRUE); log_time("VIMRF-PS", n_cores, t0)
  t0 <- Sys.time(); single <- varUsed(rf, by.tree = FALSE); log_time("VIMRF-Count", n_cores, t0)
  t0 <- Sys.time(); ib_branch <- get_ibranch_branch(rf, config$ntree, x_names); log_time("VIMRF-iBranchB", n_cores, t0)
  t0 <- Sys.time(); ib_tree <- get_ibranch_tree(rf, config$ntree, x_names); log_time("VIMRF-iBranchT", n_cores, t0)
  
  if (require(RFlocalfdr, quietly = TRUE)) {
    t0 <- Sys.time()
    try({
      imp_log <- log(imp_rf[, "IncNodePurity"] + 1e-5)
      pdf(NULL); qq <- plotQ(imp_log, debug.flag = 0); dev.off()
      locfdr <- run.it.importances(qq, imp_log, temp.dir = tempdir())
      log_time("VIMRF-localfdr", n_cores, t0)
    }, silent = TRUE)
  }
  
  if (require(vip, quietly = TRUE) && require(pdp, quietly = TRUE)) {
    t0 <- Sys.time(); firm <- vi_firm(rf, feature_names = x_names, train = cbind(y, x)); log_time("FIRM", n_cores, t0)
  }
  
  t0 <- Sys.time(); rfi <- ipmrf(rf, x, config$ntree); ipm_res <- apply(rfi, 2, mean); log_time("VIMRF-IPM", n_cores, t0)
  
  # --- Ranger Suite ---
  t0 <- Sys.time()
  ra <- ranger(y ~ ., data = cbind(y, x), num.trees = config$ntree, importance = "impurity_corrected", mtry = config$mtry, num.threads = n_cores)
  log_time("VIMRF-AIR", n_cores, t0)
  
  if (require(treeshap, quietly = TRUE)) {
    t0 <- Sys.time(); unify_ra <- ranger.unify(ra, cbind(y, x)); treeshap_res <- treeshap(unify_ra, x); log_time("TreeSHAP", n_cores, t0)
  }
  
  if (requireNamespace("sobolMDA", quietly = TRUE)) {
    t0 <- Sys.time(); fit_sobol <- sobolMDA::ranger(y ~ ., data = cbind(y, x), importance = "sobolMDA", num.trees = config$ntree); log_time("VIMRF-Sobol", n_cores, t0)
  }
  
  # --- Party Suite ---
  t0 <- Sys.time()
  cf_std <- cforest(y ~ ., data = cbind(y, x), controls = cforest_control(mtry = config$mtry, ntree = config$ntree))
  log_time("Model-Build-cforest", n_cores, t0)
  
  t0 <- Sys.time(); ppre <- varimp(cf_std, pre1.0_0 = TRUE); log_time("VIMCIF-P", n_cores, t0)
  t0 <- Sys.time(); p <- varimp(cf_std, pre1.0_0 = FALSE); log_time("VIMCIF-PA", n_cores, t0)
  t0 <- Sys.time(); try({ auc <- varimpAUC(cf_std); log_time("VIMCIF-PAUC", n_cores, t0) }, silent = TRUE)
  t0 <- Sys.time(); count_res <- count_party(cf_std); log_time("VIMCIF-Count", n_cores, t0)
  t0 <- Sys.time(); cfi <- ipmparty(cf_std, x, config$ntree); party_ipm <- apply(cfi, 2, mean); log_time("VIMCIF-IPM", n_cores, t0)
  
  t0 <- Sys.time(); pcond <- permimp(cf_std, conditional = TRUE, threshold = 0.8, asParty = TRUE); log_time("VIMCIF-Conditional", n_cores, t0)
  
  # --- RFSRC Suite ---
  t0 <- Sys.time()
  src <- rfsrc(y ~ ., data = cbind(y, x), ntree = config$ntree, mtry = config$mtry, nthread = n_cores, importance = TRUE)
  log_time("Model-Build-and-VIMSRC-Permute", n_cores, t0)
  
  t0 <- Sys.time(); ms <- max.subtree(src, nthread = n_cores); log_time("VIMRF-MD", n_cores, t0)
  t0 <- Sys.time(); ms_int <- max.subtree(src, sub.order = TRUE, nthread = n_cores); log_time("VIMRF-CMD", n_cores, t0)
  t0 <- Sys.time(); anti <- vimp(src, importance = "anti", nthread = n_cores); log_time("VIMSRC-Anti", n_cores, t0)
  t0 <- Sys.time(); anti_j <- vimp(src, importance = "anti.joint", nthread = n_cores); log_time("VIMSRC-AntiJoint", n_cores, t0)
  t0 <- Sys.time(); perm_j <- vimp(src, importance = "permute.joint", nthread = n_cores); log_time("VIMRF-JP", n_cores, t0)
  t0 <- Sys.time(); rand <- vimp(src, importance = "random", nthread = n_cores); log_time("VIMSRC-Random", n_cores, t0)
  t0 <- Sys.time(); rand_j <- vimp(src, importance = "random.joint", nthread = n_cores); log_time("VIMSRC-RanJoint", n_cores, t0)
  t0 <- Sys.time(); hold <- holdout.vimp(y ~ ., data = data, ntree = config$ntree, mtry = config$mtry, nthread = n_cores); log_time("VIMRF-Holdout", n_cores, t0)
  t0 <- Sys.time(); int_index <- find.interaction(src, method = "vimp", nthread = n_cores, verbose = FALSE); log_time("VIMSRC-FindIntVimp", n_cores, t0)
  
  # --- RFSurrogates ---
  t0 <- Sys.time()
  RFS <- RandomForestSurrogates(x = x, y = y, num.trees = config$ntree/2, mtry = config$mtry, num.threads = n_cores, importance = "impurity_corrected")
  log_time("Model-Build-RFSurrogates", n_cores, t0)
  
  t0 <- Sys.time(); rel_maa <- MeanAdjustedAgreement(RFS, num.threads = n_cores); log_time("VIMRF-MIR", n_cores, t0)
  t0 <- Sys.time(); smd <- SurrogateMinimalDepth(RFS); log_time("VIMRF-SMD", n_cores, t0)
  
  # --- H2O ---
  if (require(h2o, quietly = TRUE)) {
    h2o_port <- sample(50000:60000, 1)
    try({ h2o.init(nthreads = n_cores, max_mem_size = "6G", port = h2o_port) }, silent = FALSE)
    t0 <- Sys.time()
    h2odata <- as.h2o(cbind(y = y, x))
    h2orf <- h2o.randomForest(training_frame = h2odata, x = 2:ncol(h2odata), y = 1, ntrees = config$ntree, mtries = config$mtry)
    h2o_full <- as.data.frame(h2o.varimp(h2orf))
    log_time("VIMRF-SE", n_cores, t0)
    try({ h2o.shutdown(prompt = FALSE) }, silent = FALSE)
  }
}

# run_benchmark(1)
run_benchmark(8)
write.csv(results, out_csv, row.names = FALSE)
cat("\nResults completely saved to", out_csv, "\n")
