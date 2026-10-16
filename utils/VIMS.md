# Comprehensive Ranked List of Variable Importance Measures (VIMs)

This document provides a technical and mathematical breakdown of the Variable Importance Measures (VIMs) implemented or evaluated in this project, tracking their origin from the "Original 17" suite versus "New Additions".

---

## 1. VIMRF-Gini (Mean Decrease Impurity) — [Original 17]
*   **Reference:** Breiman, L. (2001). Random Forests. *Machine Learning*, 45(1), 5-32.
*   **Mathematical Formula:**
    $$MDI(X_j) = \frac{1}{K} \sum_{k=1}^K \sum_{t \in T_k: v(s_t) = X_j} p(t) \Delta I(s_t, t)$$
    Where $K$ is the number of trees, $p(t)$ is the proportion of samples reaching node $t$, and $\Delta I(s_t, t)$ is the impurity reduction (Gini impurity for classification, Variance for regression).
*   **Status:** Implemented (as `VIMRF-Gini`)

## 2. VIMRF-P (Standard Permutation) — [Original 17]
*   **Reference:** Breiman, L. (2001). Random Forests. *Machine Learning*, 45(1), 5-32.
*   **Mathematical Formula:**
    $$VI_{perm}(X_j) = \frac{1}{K} \sum_{k=1}^K \left( \text{ErrOOB}_{k,j}^* - \text{ErrOOB}_k \right)$$
    Where $\text{ErrOOB}_{k,j}^*$ is the error of tree $k$ after permuting variable $X_j$.
*   **Status:** Implemented (as `VIMRF-P` and `VIMSRC-Permute`)

## 3. VIMRF-PS (Scaled Permutation) — [Original 17]
*   **Reference:** Breiman, L. (2001). Random Forests. *Machine Learning*, 45(1), 5-32.
*   **Mathematical Formula:**
    $$z_j = \frac{VI_{perm}(X_j)}{\sigma_j / \sqrt{K}}$$
    Where $\sigma_j$ is the standard deviation of the importance scores across the $K$ trees.
*   **Status:** Implemented (as `VIMRF-PS`)

## 4. VIMCIF-P (Conditional Inference Permutation) — [Original 17]
*   **Reference:** Hothorn, T., Hornik, K., & Zeileis, A. (2006). Unbiased Recursive Partitioning: A Conditional Inference Framework. *Journal of Computational and Graphical Statistics*, 15(3), 651-674.
*   **Mathematical Formula:** Uses standard permutation on Conditional Inference Trees (CIT), where splits are based on the $p$-value of a global test of independence:
    $$T_j = n \cdot \text{corr}(X_j, Y)^2$$
*   **Status:** Implemented (as `VIMCIF-P`)

## 5. VIMRF-MD (Minimal Depth) — [Original 17]
*   **Reference:** Ishwaran, H., Kogalur, U. B., Gorodeski, E. Z., Minn, A. J., & Lauer, M. S. (2010). High-dimensional variable selection for survival data. *Journal of the American Statistical Association*, 105(489), 205-217.
*   **Mathematical Formula:**
    $$MD(X_j) = \frac{1}{K} \sum_{k=1}^K d_k(X_j)$$
    Where $d_k(X_j)$ is the depth of the first node in tree $k$ that splits on $X_j$ (root = 0).
*   **Status:** Implemented (as `VIMRF-MD`)

## 6. VIMRF-SE (Squared Error Loss) — [Original 17]
*   **Reference:** H2O.ai (2020). *H2O: Scalable Machine Learning*.
*   **Mathematical Formula:**
    $$VIM_{MSE}(X_j) = \text{MSE}(\text{permuted } X_j) - \text{MSE}(\text{original})$$
*   **Status:** Implemented (as `VIMRF-SE`)

## 7. VIMCIF-Conditional (Conditional Permutation) — [Original 17]
*   **Reference:** Strobl, C., Boulesteix, A. L., Kneib, T., Augustin, T., & Zeileis, A. (2008). Conditional variable importance for random forests. *BMC Bioinformatics*, 9(1), 307.
*   **Mathematical Formula:**
    $$VIM_{cond}(X_j) = \frac{1}{K} \sum_{k=1}^K \left( \text{Perf}(OOB_k) - \text{Perf}(OOB_k, \pi_j(X_j | Z)) \right)$$
    Where $\pi_j(X_j | Z)$ denotes permutation of $X_j$ within strata of correlated variables $Z$.
*   **Status:** Implemented (Optimised via 500-tree Split Forest strategy and threshold = 0.8).

## 8. VIMCIF-PAUC (AUC-based Permutation) — [Original 17]
*   **Reference:** Janitza, S., Strobl, C., & Boulesteix, A. L. (2013). An AUC-based permutation variable importance measure for random forests. *BMC Bioinformatics*, 14(1), 119.
*   **Mathematical Formula:**
    $$VIM_{AUC}(X_j) = \frac{1}{K} \sum_{k=1}^K \left( AUC(OOB_k) - AUC(OOB_k, \pi_j(X_j)) \right)$$
*   **Status:** Computed (`party::varimpAUC`) but not reported: AUC-based importance is not defined for regression outcomes.

## 9. TreeSHAP (Global SHAP Importance) — [New Addition]
*   **Reference:** Lundberg, S. M., Erion, G., Chen, H., DeGrave, A., Prutkin, J. M., Nair, B., Katz, R., Himmelfarb, J., Bansal, N., & Lee, S. I. (2020). From local explanations to global understanding with explainable AI for trees. *Nature Machine Intelligence*, 2(1), 56-67.
*   **Mathematical Formula:**
    $$\phi_i = \sum_{S \subseteq N \setminus \{i\}} \frac{|S|!(|N|-|S|-1)!}{|N|!} [f(S \cup \{i\}) - f(S)]$$
    Global importance is calculated as the mean absolute SHAP value: $I_j = \frac{1}{n} \sum_{i=1}^n |\phi_i^{(j)}|$.
*   **Status:** Implemented (via `treeshap` on the `ranger` forest; global importance = mean |SHAP|).

## 10. CV-Permutation VIM & PIMP — [New Addition]
*   **Reference:** Altmann, A., Toloşi, L., Sander, O., & Lengauer, T. (2010). Permutation importance: a corrected feature importance measure. *Bioinformatics*, 26(10), 1340-1347.
*   **Mathematical Formula:** Compares the observed $VI_j$ to a null distribution $VI_j^{(1)}, \dots, VI_j^{(S)}$ generated by permuting the response $Y$.
    $$p_j = \frac{1}{S} \sum_{s=1}^S I(VI_j^{(s)} \geq VI_j)$$
*   **Status:** Not implemented.

## 11. Conditional Minimal Depth (CMD) — [New Addition]
*   **Reference:** Ishwaran, H., Kogalur, U. B., Chen, X., & Minn, A. J. (2011). Random survival forests for high-dimensional data. *Statistical Analysis and Data Mining*, 4(1), 115-132.
*   **Mathematical Formula:**
    $$CMD(X_j | X_i) = \frac{1}{K} \sum_{k=1}^K [d_k(X_j) - d_k(X_i)] \cdot I(d_k(X_i) < d_k(X_j))$$
*   **Status:** Implemented (via `VIMRF-CMD`)

## 12. Actual Impurity Reduction (VIMRF-AIR) — [Original 17]
*   **Reference:** Nembrini, S., König, I. R., & Wright, M. N. (2018). The revival of the Gini importance? *Bioinformatics*, 34(21), 3711-3718.
*   **Mathematical Formula:**
    $$AIR(X_j) = MDI(X_j) - MDI(\text{Shadow } X_j)$$
    Where "Shadow $X_j$" is a permuted copy of $X_j$ that captures the cardinality-based bias.
*   **Status:** Implemented (via `ranger` package as `VIMRF-AIR`)

## 13. Empirical Bayes Gini VIM (Local FDR) — [New Addition]
*   **Reference:** `RFlocalfdr` R package (Dunne et al.) — full reference to be added.
*   **Mathematical Formula:** Fits a mixture model $f(z) = \pi_0 f_0(z) + (1-\pi_0) f_1(z)$ to the importance scores, and calculates:
    $$fdr(z) = P(\text{Noise} | Z=z) = \frac{\pi_0 f_0(z)}{f(z)}$$
*   **Status:** Computed (via `RFlocalfdr`) but not used in the paper (an FDR-based test, not a per-variable importance score).

## 14. VIMCIF-PA (Daughter Node Permutation) — [Original 17]
*   **Reference:** Hapfelmeier, A., Hothorn, T., Ulm, K., & Strobl, C. (2014). A new variable importance measure for random forests with missing data. *Statistics and Computing*, 24(1), 21-34.
*   **Mathematical Formula:** Stochastic assignment at node $t$ where $v(t) = X_j$:
    $$P(\text{Left}) = W_{t,L} / (W_{t,L} + W_{t,R})$$
*   **Status:** Implemented (as `VIMCIF-PA` via `party::varimp(pre1.0_0 = FALSE)`, the default). `pre1.0_0 = TRUE` permutes the variable values (Breiman) and is reported as `VIMCIF-P`.

## 15. Raw Counts (VIMRF-Count & VIMCIF-Count) — [Original 17]
*   **Reference:** Breiman, L. (2001). Random Forests. *Machine Learning*, 45(1), 5-32.
*   **Mathematical Formula:**
    $$Count(X_j) = \sum_{k=1}^K \sum_{t \in T_k} I(v(s_t) = X_j)$$
*   **Status:** Implemented (as `VIMRF-Count` and `VIMCIF-Count`)

## 16. Intervention in Prediction (IPM) — [Original 17]
*   **Reference:** Nicodemus, K. K., Malley, J. D., Strobl, C., & Ziegler, A. (2010). The behaviour of random forest permutation-based variable importance measures under predictor correlation. *BMC Bioinformatics*, 11(1), 110.
*   **Mathematical Formula:**
    $$IPM(X_j) = \frac{1}{K} \sum_{k=1}^K \frac{1}{|OOB_k|} \sum_{i \in OOB_k} c_{i,j,k}$$
    Where $c_{i,j,k} = 1$ if variable $X_j$ is used in the decision path for observation $i$ in tree $k$.
*   **Status:** Implemented (as `VIMRF-IPM` and `VIMCIF-IPM`)

## 17. Interaction Branching (iBranch) — [Original 17]
*   **Reference:** this paper (Conforto, Generation Scotland, Nicodemus).
*   **Mathematical Formula:** for tree $t$ with root split variable $r_t$, non-root split nodes $S_t$ and split variable $v(s)$:
    $$iBranchB(X_j, X_k) = \sum_t \sum_{s \in S_t} I(\{v(s), r_t\} = \{j, k\})$$
    $$iBranchT(X_j, X_k) = \sum_t I(X_j \in V_t \land X_k \in V_t)$$
    where $V_t$ is the set of variables used in tree $t$ (root-anchored iBranchB, as used in the paper).
*   **Status:** Implemented (as `VIMRF-iBranchT`, `VIMRF-iBranchB`)

## 18. Joint Permutation (VIMRF-JP) — [Original 17]
*   **Reference:** Bureau, A., Dupuis, J., Falls, K., Lunetta, K. L., Hayward, B., Kempf, T. P., & Van Eerdewegh, P. (2005). Identifying SNPs predictive of phenotype using random forests. *Genetic Epidemiology*, 28(2), 171-182.
*   **Mathematical Formula:**
    $$VI(X_j, X_k) = \frac{1}{K} \sum_{k=1}^K (errOOB_k^{j,k} - errOOB_k)$$
    Where $errOOB_k^{j,k}$ is the error after permuting both $X_j$ and $X_k$ independently.
*   **Status:** `randomForestSRC::vimp(importance = "permute.joint")` returns a single forest-level value, so it is not reported per variable. The pairwise joint-permutation VIM is VIMSRC-FindIntVimp (`find.interaction(method = "vimp")`).

## 19. RFSRC Joint Variants — [New Addition]
*   **Reference:** Ishwaran, H. et al. (2020). *randomForestSRC: Fast Unified Random Forests for Survival, Regression, and Classification (RF-SRC)*.
*   **Variants**: 
    - `anti.joint`: Permutes within non-OOB.
    - `random.joint`: Shuffles from the empirical distribution.
    - `permute.joint`: Averaged error increase over bootstrap ensembles.
*   **Status**: ✅ Fully Implemented.

## 20. Sobol-MDA — [New Addition]
*   **Reference:** Bénard, C., Da Veiga, S., & Scornet, E. (2022). Mean decrease accuracy for random forests: inconsistency, and a practical solution via the Sobol-MDA. *Biometrika*, 109(4), 881-900.
*   **Mathematical Formula:** Estimates the Total Sobol Index $S_{T_j}$ using a projected predictor approach:
    $$S_{T_j} = \frac{E[Var(Y|X_{-j})]}{Var(Y)}$$
*   **Status**: Implemented (via `sobolMDA`).

## 21. Fast Conditional Permutation Importance — [New Addition]
*   **Reference:** Debeer, D., & Strobl, C. (2020). Conditional permutation importance revisited. *BMC Bioinformatics*, 21(1), 307.
*   **Mathematical Formula:** Mathematically equivalent to VIM #7 but uses a more efficient implementation of the conditional permutation scheme.
*   **Status**: Implemented (via `permimp`).

## 22. Feature Importance Ranking Measure (FIRM) — [New Addition]
*   **Reference:** Greenwell, B. M., & Boehmke, B. C. (2020). Variable Importance Plots—An Introduction to the vip Package. *The R Journal*, 12(1), 343-366.
*   **Mathematical Formula:** Standard deviation of the Partial Dependence function $\hat{f}_j(x_j)$ across its range:
    $$FIRM(X_j) = \sqrt{\frac{1}{m-1} \sum_{k=1}^m (\hat{f}_j(x_{j,k}) - \bar{f}_j)^2}$$
*   **Status**: Implemented (via `vip`).

## 23. Mutual Forest Impact (MFI) & Mutual Impurity Reduction (MIR) — [New Addition]
*   **Reference:** Voges, L. F., Jarren, L. C., & Seifert, S. (2023). Exploitation of surrogate variables in random forests for unbiased analysis of mutual impact and importance of features. *Bioinformatics*, 39(8), btad471.
*   **Mathematical Formula:** Based on the impurity reduction $\Delta I$ provided by surrogate splits $s_j^*$ that mimic primary splits $s_i$:
    $$MIR(X_i, X_j) = \sum_{t} \Delta I(s_i, t) \cdot \text{corr}(s_i, s_j^*)$$
*   **Status**: Implemented (via `RFSurrogates`).

## 24. Surrogate Minimal Depth (SMD) — [New Addition]
*   **Reference:** Seifert, S., et al. (2019). Surrogate Minimal Depth as an Importance Measure for Variables in Random Forests. *Bioinformatics*, 35(21).
*   **Mathematical Formula:** Modifies the depth $d_k(X_j)$ by allowing surrogates to "stand in" for primary variables:
    $$d_k^{surr}(X_j) = \min(d_k(X_j), \min_{i} d_k(X_i) + \delta_{ij})$$
    Where $\delta_{ij}$ is the penalty based on surrogate quality.
*   **Status**: Implemented (via `RFSurrogates`).

## 25. Holdout VIMP — [New Addition]
*   **Reference:** Ishwaran, H. et al. (2020). *randomForestSRC: Fast Unified Random Forests for Survival, Regression, and Classification*.
*   **Mathematical Formula:**
    $$Holdout(X_j) = \text{MSE}(\text{Forest built without } X_j) - \text{MSE}(\text{Original Forest})$$
*   **Status:** Implemented (via `randomForestSRC::holdout.vimp`).

## 26. RFSRC Standard Permute — [New Addition]
*   **Reference:** Ishwaran, H. et al. (2020). Modern C-level implementation of permutation importance with OpenMP support.
*   **Status:** Implemented (via `randomForestSRC::vimp(importance="permute")`).

---
*Developed with Gemini CLI (v0.46.0). Designed and adapted from legacy code by the author.*
