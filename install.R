list.of.packages <- c(
    "tidyverse",
    "arrow",
    "reticulate",
    "skimr",
    "caret",
    "openxlsx",
    "extrafont",
    "kableExtra",
    "RPresto",
    "ckanr",
    "pryr",
    "digest",
    "Rcpp",
    "cli",
    "rJava",
    "plotly",
    "sf",
    "terra",
    "targets",
    "tarchetypes")
 
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]

# use posit binary linux packages
options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))
options(repos="https://packagemanager.rstudio.com/all/__linux__/focal/latest", Ncpus=3)
source("https://docs.posit.co/rspm/admin/check-user-agent.R")
Sys.setenv("NOT_CRAN" = TRUE)

# Install packages
if(length(new.packages)) install.packages(new.packages)

# Custom packages
remotes::install_github('ropensci/targets', dependencies = TRUE)
remotes::install_github('riazarbi/diffdfs', dependencies = TRUE)
remotes::install_github('cityofcapetown/aws.s3.patch', dependencies = TRUE)
