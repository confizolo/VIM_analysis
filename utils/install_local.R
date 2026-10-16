options(repos = c(CRAN = 'https://cran.r-project.org'))

# 1. Standard CRAN Packages
cran_pkgs <- c('randomForest', 'ranger', 'party', 'h2o', 'dplyr', 'purrr', 'ggplot2', 'permimp', 'vip', 'pdp', 'treeshap', 'RFlocalfdr', 'remotes', 'IPMRF')

for (p in cran_pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) {
    install.packages(p, dependencies = TRUE)
  }
}

# 2. Remote Packages (GitHub / GitLab)
if (require('remotes', character.only = TRUE, quietly = TRUE)) {
  cat('\nInstalling Remote Packages...\n')
  
  if (!requireNamespace('linkcomm', quietly = TRUE)) {
    remotes::install_github('alextkalinka/linkcomm', upgrade = 'never')
  }
  if (!requireNamespace('SurrogateMinimalDepth', quietly = TRUE)) {
    remotes::install_github('StephanSeifert/SurrogateMinimalDepth', upgrade = 'never')
  }
  if (!requireNamespace('RFSurrogates', quietly = TRUE)) {
    remotes::install_github('AGSeifert/RFSurrogates', upgrade = 'never')
  }
  if (!requireNamespace('sobolMDA', quietly = TRUE)) {
    remotes::install_gitlab('drti/sobolmda@sobolMDA', upgrade = 'never')
  }
}

# 3. Install legacy randomForestSRC (v3.2.0) into $LIB_DIR 
cat("Installing dependencies (data.tree, DiagrammeR)...\n")
options(repos = c(CRAN = "https://cran.r-project.org"))
install.packages(c("data.tree", "DiagrammeR"))

cat("Downloading randomForestSRC 3.2.0 source...\n")
download.file("https://cran.r-project.org/src/contrib/Archive/randomForestSRC/randomForestSRC_3.2.0.tar.gz", "randomForestSRC_3.2.0.tar.gz", quiet = TRUE)

cat("Compiling and installing randomForestSRC 3.2.0...\n")
install.packages("randomForestSRC_3.2.0.tar.gz", repos = NULL, type = "source")

file.remove("randomForestSRC_3.2.0.tar.gz")
cat("Legacy installation complete!\n")