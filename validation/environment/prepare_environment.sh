#!/usr/bin/env bash
set -euo pipefail

echo "Preparing RCS validation environment..."
mkdir -p outputs/tables outputs/figures outputs/logs outputs/supplementary_tables

Rscript -e 'pkgs <- c("dplyr","tidyr","purrr","ggplot2","readr","stringr","scales","tibble","forcats","broom","patchwork"); missing <- pkgs[!sapply(pkgs, requireNamespace, quietly=TRUE)]; if(length(missing)) install.packages(missing, repos="https://cloud.r-project.org"); print(sapply(pkgs, requireNamespace, quietly=TRUE))'

Rscript tests/00_check_environment.R

echo "Environment ready."
