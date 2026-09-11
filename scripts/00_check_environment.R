#!/usr/bin/env Rscript

required_r <- c(
  "dplyr", "tidyr", "purrr", "ggplot2", "readr", "stringr",
  "scales", "tibble", "forcats", "broom", "patchwork"
)
available_r <- vapply(required_r, requireNamespace, logical(1), quietly = TRUE)

cat("R version:", R.version.string, "\n")
cat("Platform:", R.version$platform, "\n")
cat("OS:", Sys.info()[["sysname"]], Sys.info()[["release"]], "\n")
cat("Logical cores:", parallel::detectCores(logical = TRUE), "\n")
cat("Physical cores:", parallel::detectCores(logical = FALSE), "\n")
cat("Cairo PDF available:", capabilities("cairo"), "\n")
cat("\nRequired R packages:\n")
for (i in seq_along(required_r)) {
  version <- if (available_r[[i]]) as.character(utils::packageVersion(required_r[[i]])) else "MISSING"
  cat(sprintf("  %-12s %s\n", required_r[[i]], version))
}

command_available <- function(command) nzchar(Sys.which(command))
python_module_available <- function(module) {
  if (!command_available("python3")) return(FALSE)
  probe <- paste0(
    "import importlib.util, sys; ",
    "sys.exit(0 if importlib.util.find_spec('", module, "') is not None else 1)"
  )
  identical(system2("python3", c("-c", probe), stdout = FALSE, stderr = FALSE), 0L)
}

run_cuda <- toupper(Sys.getenv("BENCHMARK_RUN_CUDA", unset = "FALSE")) == "TRUE"
benchmark_checks <- data.frame(
  component = c("Rscript", "g++", "Python 3", "Python NumPy", "Python Cython", "Python setuptools", "nvcc", "NVIDIA GPU"),
  available = c(
    command_available("Rscript"),
    command_available("g++"),
    command_available("python3"),
    python_module_available("numpy"),
    python_module_available("Cython"),
    python_module_available("setuptools"),
    command_available("nvcc"),
    command_available("nvidia-smi") && system2("nvidia-smi", "-L", stdout = FALSE, stderr = FALSE) == 0L
  ),
  required = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, run_cuda, run_cuda),
  stringsAsFactors = FALSE
)

cat("\nBenchmark components:\n")
print(benchmark_checks, row.names = FALSE)

if (!all(available_r)) {
  stop("Missing required R packages: ", paste(required_r[!available_r], collapse = ", "))
}
if (any(benchmark_checks$required & !benchmark_checks$available)) {
  stop(
    "Missing required benchmark components: ",
    paste(benchmark_checks$component[benchmark_checks$required & !benchmark_checks$available], collapse = ", ")
  )
}

cat("\nEnvironment check passed.\n")
