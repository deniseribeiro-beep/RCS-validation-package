#!/usr/bin/env Rscript

source(file.path("benchmark_v2", "config.R"))
checks <- data.frame(
  component = c("Rscript", "g++", "Python 3", "Python NumPy", "Python Cython", "Python setuptools", "nvcc", "NVIDIA GPU"),
  available = c(
    nzchar(Sys.which("Rscript")), nzchar(Sys.which("g++")), nzchar(Sys.which("python3")),
    if (nzchar(Sys.which("python3"))) system2("python3", c("-c", shQuote("import numpy")), stdout = FALSE, stderr = FALSE) == 0L else FALSE,
    if (nzchar(Sys.which("python3"))) system2("python3", c("-c", shQuote("import Cython")), stdout = FALSE, stderr = FALSE) == 0L else FALSE,
    if (nzchar(Sys.which("python3"))) system2("python3", c("-c", shQuote("import setuptools")), stdout = FALSE, stderr = FALSE) == 0L else FALSE,
    nzchar(Sys.which("nvcc")), nzchar(Sys.which("nvidia-smi")) && system2("nvidia-smi", "-L", stdout = FALSE, stderr = FALSE) == 0L
  ), stringsAsFactors = FALSE)
print(checks, row.names = FALSE)
required_r <- c("ggplot2", "patchwork", "scales")
missing_r <- required_r[!vapply(required_r, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_r)) cat("Missing R packages:", paste(missing_r, collapse = ", "), "\n")
mandatory <- checks$available[!checks$component %in% c("nvcc", "NVIDIA GPU") | V2_RUN_CUDA]
if (!all(mandatory) || length(missing_r)) quit(status = 1L)
cat("Benchmark V2 environment check passed.\n")
