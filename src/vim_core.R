# --- src/vim_core.R ---
# Centralised logic for VIM calculations.
# Each package has its own dedicated runner function for extreme modularity.

has_rfsrc  <- require(randomForestSRC, quietly = TRUE)
has_ipmrf  <- require(IPMRF,           quietly = TRUE)
has_ranger <- require(ranger,          quietly = TRUE)
has_party  <- require(party,           quietly = TRUE)
has_h2o    <- require(h2o,             quietly = TRUE)
has_permimp <- require(permimp, quietly = TRUE)
has_sobolmda <- requireNamespace("sobolMDA", quietly = TRUE)
has_vip <- require(vip, quietly = TRUE)
has_rfsurrogates <- require(RFSurrogates, quietly = TRUE)
has_treeshap <- require(treeshap, quietly = TRUE)
has_rflocalfdr <- require(RFlocalfdr, quietly = TRUE)

# --- Shared Helper Functions ---
if (has_party) {
  count_party <- function(forest, inames = NULL) {
    if (is.null(inames) && extends(class(forest), "RandomForest"))
      inames <- names(forest@data@get("input"))
    resultvec <- rep(0, length(inames))
    myfunc <- function(x, inames, resultvec) {
      names(x) <- c("nodeID", "weights", "criterion", "terminal",
                    "psplit", "ssplits", "prediction", "left", "right")
      if (!x$terminal) {
        resultvec[x$psplit[[1]]] <- resultvec[x$psplit[[1]]] + 1
        resultvec <- myfunc(x$left, inames = inames, resultvec = resultvec)
        resultvec <- myfunc(x$right, inames = inames, resultvec = resultvec)
      }
      return(resultvec)
    }
    for (k in 1:length(forest@ensemble)) {
      resultvec <- myfunc(forest@ensemble[[k]], inames, resultvec)
    }
    names(resultvec) <- inames
    return(resultvec)
  }
}

get_ibranch_branch <- function(rf, ntree, x_names) {
  n_vars <- length(x_names)
  ibranch <- matrix(0, nrow = n_vars, ncol = n_vars)
  rownames(ibranch) <- colnames(ibranch) <- x_names
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
  ibranch[lower.tri(ibranch)] = t(ibranch)[lower.tri(ibranch)]
  return(ibranch)
}

get_ibranch_tree <- function(rf, ntree, x_names) {
  n_vars <- length(x_names)
  v1 <- varUsed(rf, by.tree = TRUE, count = FALSE)
  countmat <- matrix(0, nrow = n_vars, ncol = n_vars)
  rownames(countmat) <- colnames(countmat) <- x_names
  for (i in 1:length(v1)) {
    used <- v1[[i]]
    if (length(used) < 2) next
    for (j in 1:(length(used)-1)) {
      for (k in (j+1):length(used)) {
        v1_idx <- used[j]; v2_idx <- used[k]
        countmat[v1_idx, v2_idx] <- countmat[v1_idx, v2_idx] + 1
        countmat[v2_idx, v1_idx] <- countmat[v2_idx, v1_idx] + 1
      }
    }
  }
  return(countmat)
}

# --- Package-Specific Modules ---

run_vims_randomForest <- function(x, y, x_names, config, res) {
  rf <- randomForest(x = x, y = y, ntree = config$ntree, mtry = config$mtry, replace = FALSE, importance = TRUE, keep.forest = TRUE, keep.inbag = TRUE)
  imp_rf <- randomForest::importance(rf)
  
  res$VIMRF_Gini    <- imp_rf[, "IncNodePurity"]
  res$VIMRF_P       <- randomForest::importance(rf, type = 1, scale = FALSE)
  res$VIMRF_Pscaled <- randomForest::importance(rf, type = 1, scale = TRUE)
  res$VIMRF_iBranchBranch <- get_ibranch_branch(rf, config$ntree, x_names)
  res$VIMRF_iBranchTree   <- get_ibranch_tree(rf, config$ntree, x_names)
  res$VIMRF_Single <- varUsed(rf, by.tree = FALSE)

  if (has_rflocalfdr) {
    try({
      imp_log <- log(imp_rf[, "IncNodePurity"] + 1e-5)
      pdf(NULL); qq <- plotQ(imp_log, debug.flag = 0); dev.off()
      res$VIM_RFlocalfdr <- run.it.importances(qq, imp_log, temp.dir = tempdir())
    }, silent = FALSE)
  }

  if (has_vip) {
    try({
      suppressWarnings(suppressPackageStartupMessages(require(pdp, quietly=TRUE)))
      res$VIM_FIRM <- vi_firm(rf, feature_names = x_names, train = cbind(y, x))
    }, silent = FALSE)
  }
  
  if (has_ipmrf) {
    try({ rfi <- ipmrf(rf, x, config$ntree); res$VIMRF_IPM <- apply(rfi, 2, mean) }, silent = FALSE)
  }
  return(res)
}

run_vims_ranger <- function(x, y, config, res) {
  if (!has_ranger) return(res)
  
  try({
    ra <- ranger(y ~ ., data = cbind(y, x), num.trees = config$ntree, importance = "impurity_corrected", mtry = config$mtry, replace = FALSE)
    res$VIMRanger_AIR <- ra$variable.importance
    
    if (has_treeshap) {
      unify_ra <- ranger.unify(ra, cbind(y, x))
      treeshap_res <- treeshap(unify_ra, x)
      # Compact TreeSHAP to a global measure and strip hidden model environment
      compact_shap <- as.numeric(colMeans(abs(treeshap_res$shaps)))
      names(compact_shap) <- colnames(treeshap_res$shaps)
      res$VIM_TreeSHAP <- compact_shap
    }
    
    if (has_sobolmda) {
      fit_sobol <- sobolMDA::ranger(y ~ ., data = cbind(y, x), importance = "sobolMDA", num.trees = config$ntree)
      res$VIM_SobolMDA <- fit_sobol$variable.importance
    }
  }, silent = FALSE)
  return(res)
}

run_vims_party_std <- function(x, y, config, res) {
  if (!has_party) return(res)
  try({ 
    control_std <- cforest_control(mtry = config$mtry, ntree = config$ntree, replace = FALSE, fraction = 0.632)
    cf_std <- cforest(y ~ ., data = cbind(y, x), controls = control_std)
    
    res$VIMParty_Ppre <- varimp(cf_std, pre1.0_0 = TRUE)
    res$VIMParty_P <- varimp(cf_std, pre1.0_0 = FALSE)
    
    try({ res$VIMParty_AUC <- varimpAUC(cf_std) }, silent = FALSE)
    
    res$VIMParty_Count <- count_party(cf_std)
    cfi <- ipmparty(cf_std, x, config$ntree)
    res$VIMParty_IPM <- apply(cfi, 2, mean)
  }, silent = FALSE)
  return(res)
}

run_vims_rfsrc <- function(x, y, x_names, data, config, res, n_threads) {
  if (!has_rfsrc) return(res)
  try({ 
    src <- rfsrc(y ~ ., data = cbind(y, x), ntree = config$ntree, mtry = config$mtry, 
                 samptype = "swor", split.depth = "all.trees", forest = TRUE, nthread = n_threads, importance = TRUE)
    
    ms <- max.subtree(src, nthread = n_threads)
    res$VIMSRC_MinDepth <- ms$order[, 1]
    ms_int <- max.subtree(src, sub.order = TRUE, nthread = n_threads)
    res$VIMSRC_FindIntMax <- ms_int$sub.order
    
    res$VIMSRC_Anti <- vimp(src, importance = "anti", nthread = n_threads)$importance
    res$VIMSRC_AntiJoint <- vimp(src, importance = "anti.joint", nthread = n_threads)$importance
    res$VIMSRC_PermJoint <- vimp(src, importance = "permute.joint", nthread = n_threads)$importance
    res$VIMSRC_Random <- vimp(src, importance = "random", nthread = n_threads)$importance
    res$VIMSRC_RanJoint <- vimp(src, importance = "random.joint", nthread = n_threads)$importance
    
    try({ res$VIMSRC_Permute <- vimp(src, importance = "permute", nthread = n_threads)$importance }, silent=FALSE)

    int_index <- find.interaction(src, method = "vimp", nthread = n_threads, verbose = FALSE)
    v_individual <- src$importance
    n_vars <- length(x_names)
    joint_vimp <- matrix(0, nrow = n_vars, ncol = n_vars)
    rownames(joint_vimp) <- colnames(joint_vimp) <- x_names
    for (i in 1:(n_vars - 1)) {
      for (j in (i + 1):n_vars) {
        p1 <- paste(x_names[i], x_names[j], sep = ":")
        p2 <- paste(x_names[j], x_names[i], sep = ":")
        paired_val <- 0
        if (p1 %in% rownames(int_index)) paired_val <- int_index[p1, "Paired"]
        else if (p2 %in% rownames(int_index)) paired_val <- int_index[p2, "Paired"]
        joint_vimp[i, j] <- paired_val + v_individual[x_names[i]] + v_individual[x_names[j]]
      }
    }
    joint_vimp[lower.tri(joint_vimp)] <- t(joint_vimp)[lower.tri(joint_vimp)]
    res$VIMSRC_FindIntVimp <- joint_vimp

    try({ res$VIMSRC_Holdout <- holdout.vimp(y ~ ., data = data, ntree = config$ntree, mtry = config$mtry, nthread = n_threads)$importance }, silent=FALSE)
  }, silent = FALSE)
  return(res)
}

run_vims_party_conditional <- function(x, y, config, res, n_threads) {
  if (!has_party || !has_permimp) return(res)
  try({
    cl <- NULL
    if (n_threads > 1) {
      cl <- NULL
      
    }
    control_std <- cforest_control(mtry = config$mtry, ntree = config$ntree/2, replace = FALSE, fraction = 0.632)
    cf_std <- cforest(y ~ ., data = cbind(y, x), controls = control_std)

    try({ res$VIMParty_Conditional <- permimp(cf_std, conditional = TRUE, threshold = 0.8, progressBar = TRUE, cl = cl, asParty = TRUE)$values }, silent=FALSE)
    try({ res$VIMPermimp_Conditional <- permimp(cf_std, conditional = TRUE, threshold = 0.8, progressBar = TRUE, cl = cl)$values }, silent=FALSE)

    
  }, silent = FALSE)
  return(res)
}

run_vims_rfsurrogates <- function(x, y, config, res, n_threads, seed) {
  if (!has_rfsurrogates) return(res)
  try({
    RFS <- RandomForestSurrogates(x = x, y = y, num.trees = config$ntree/2, mtry = config$mtry, num.threads = n_threads, importance = "impurity_corrected", seed = seed)
    rel_maa <- MeanAdjustedAgreement(RFS, num.threads = n_threads)
    mir_res <- MutualImpurityReduction(rel_maa)
    res$VIM_MIR <- mir_res$MIR
    # Compact SurrogateMinimalDepth to prevent saving a 2GB model environment
    smd_full <- SurrogateMinimalDepth(RFS)
    res$VIM_SMD <- smd_full$depth
  }, silent = FALSE)
  return(res)
}

run_vims_h2o <- function(x, y, config, res, n_cores) {
  if (!has_h2o) return(res)
  h2o_port <- sample(50000:60000, 1)
  try({ h2o.init(nthreads = n_cores, max_mem_size = "6G", port = h2o_port) }, silent = FALSE) 
  
  try({ 
    h2odata <- as.h2o(cbind(y = y, x))
    h2orf <- h2o.randomForest(training_frame = h2odata, x = 2:ncol(h2odata), y = 1, ntrees = config$ntree, mtries = config$mtry)
    # Compact H2O variable importance to prevent attaching Java environments
    h2o_full <- as.data.frame(h2o.varimp(h2orf))
    h2o_vec <- h2o_full$relative_importance
    names(h2o_vec) <- h2o_full$variable
    # Sort so v1, v2, ... are in order
    var_nums <- as.integer(gsub("\\D", "", names(h2o_vec)))
    h2o_vec <- h2o_vec[order(var_nums)]
    res$VIMH2O <- h2o_vec
  }, silent = FALSE)

  try({ h2o.shutdown(prompt = FALSE) }, silent = FALSE)
  return(res)
}
