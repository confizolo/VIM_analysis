# --- utils/vim_map.R ---
# Single source of truth for the VIM naming convention.
# Source this file in any R script that needs to translate internal VIM names
# to their canonical publication labels.
#
# Usage:
#   source("utils/vim_map.R")
#   df$VIM <- dplyr::recode(df$VIM, !!!VIM_MAP)
#
# Maintained by: F. Conforto
# Built with the aid of Gemini CLI (v0.46.0)

VIM_MAP <- c(
  # --- randomForest ---
  "VIMRF_Gini"        = "VIMRF-Gini",
  "VIMRF_P"           = "VIMRF-P",
  "VIMRF_Pscaled"     = "VIMRF-PS",
  "VIMRF_Single"      = "VIMRF-Count",
  "VIMRF_IPM"         = "VIMRF-IPM",
  "VIMRF_iBranchBranch" = "VIMRF-iBranchB",
  "VIMRF_iBranchTree"   = "VIMRF-iBranchT",
  "VIM_RFlocalfdr"    = "VIMRF-localfdr",
  # NOTE: FIRM (VIM_FIRM) is computed inside the randomForest model-build step
  # and is therefore absent from standalone benchmark timing measurements.
  "VIM_FIRM"          = "FIRM",

  # --- ranger ---
  "VIMRanger_AIR"     = "VIMRF-AIR",

  # --- ranger-based (TreeSHAP, SobolMDA) ---
  "VIM_TreeSHAP"      = "TreeSHAP",
  "VIM_SobolMDA"      = "VIMRF-Sobol",

  # --- party (Conditional Inference Forest) ---
  # party::varimp(pre1.0_0 = TRUE) permutes the variable values (Breiman) -> VIMCIF-P;
  # the default (pre1.0_0 = FALSE) permutes child-node assignment (Hapfelmeier et al.) -> VIMCIF-PA
  "VIMParty_Ppre"     = "VIMCIF-P",
  "VIMParty_P"        = "VIMCIF-PA",
  "VIMParty_AUC"      = "VIMCIF-PAUC",
  "VIMParty_Count"    = "VIMCIF-Count",
  "VIMParty_IPM"      = "VIMCIF-IPM",
  "VIMParty_Conditional"   = "VIMCIF-Conditional",
  "VIMPermimp_Conditional" = "VIMCIF-FCPI",

  # --- randomForestSRC ---
  "VIMSRC_MinDepth"    = "VIMRF-MD",
  "VIMSRC_FindIntMax"  = "VIMRF-CMD",
  "VIMSRC_Anti"        = "VIMSRC-Anti",
  "VIMSRC_AntiJoint"   = "VIMSRC-AntiJoint",
  "VIMSRC_PermJoint"   = "VIMRF-JP",
  "VIMSRC_Random"      = "VIMSRC-Random",
  "VIMSRC_RanJoint"    = "VIMSRC-RanJoint",
  "VIMSRC_Permute"     = "VIMSRC-Permute",
  "VIMSRC_Holdout"     = "VIMRF-Holdout",
  "VIMSRC_FindIntVimp" = "VIMSRC-FindIntVimp",

  # --- RFSurrogates ---
  "VIM_MIR" = "VIMRF-MIR",
  "VIM_SMD" = "VIMRF-SMD",

  # --- H2O ---
  "VIMH2O"  = "VIMRF-SE"
)
