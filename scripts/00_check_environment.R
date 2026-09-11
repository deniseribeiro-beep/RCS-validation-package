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

python_executable <- unname(Sys.which("python3"))
python_dependencies_preverified <-
  toupper(Sys.getenv("BENCHMARK_PYTHON_DEPS_VERIFIED", unset = "FALSE")) == "TRUE"

python_package_available <- function(package) {
  if (!nzchar(python_executable)) return(FALSE)
  if (python_dependencies_preverified) return(TRUE)

  # Outside CI, query the interpreter's own pip metadata. This avoids the
  # R -> Python import-probe behavior that produced false negatives on hosted
  # GitHub runners even when direct Python imports succeeded.
  status <- suppressWarnings(
    system2(
      python_executable,
      c("-m", "pip", "show", package),
      stdout = FALSE,
      stderr = FALSE
    )
  )
  isTRUE(as.integer(status) == 0L)
}

run_python <- toupper(Sys.getenv("BENCHMARK_RUN_PYTHON", unset = "TRUE")) == "TRUE"
run_cuda <- toupper(Sys.getenv("BENCHMARK_RUN_CUDA", unset = "FALSE")) == "TRUE"

benchmark_checks <- data.frame(
  component = c(
    "Rscript", "g++", "Python 3", "Python NumPy", "Python Cython",
    "Python setuptools", "nvcc", "NVIDIA GPU"
  ),
  available = c(
    command_available("Rscript"),
    command_available("g++"),
    command_available("python3"),
    python_package_available("numpy"),
    python_package_available("cython"),
    python_package_available("setuptools"),
    command_available("nvcc"),
    command_available("nvidia-smi") &&
      system2("nvidia-smi", "-L", stdout = FALSE, stderr = FALSE) == 0L
  ),
  required = c(
    TRUE, TRUE,
    run_python, run_python, run_python, run_python,
    run_cuda, run_cuda
  ),
  stringsAsFactors = FALSE
)

cat("\nPython executable:", if (nzchar(python_executable)) python_executable else "MISSING", "\n")
if (python_dependencies_preverified) {
  cat("Python dependencies: pre-verified by the calling environment.\n")
}
cat("\nBenchmark components:\n")
print(benchmark_checks, row.names = FALSE)

if (!run_cuda) {
  cat("\nCUDA checks are optional because BENCHMARK_RUN_CUDA=FALSE.\n")
}

if (!all(available_r)) {
  stop("Missing required R packages: ", paste(required_r[!available_r], collapse = ", "))
}
if (any(benchmark_checks$required & !benchmark_checks$available)) {
  stop(
    "Missing required benchmark components: ",
    paste(
      benchmark_checks$component[benchmark_checks$required & !benchmark_checks$available],
      collapse = ", "
    )
  )
}

cat("\nEnvironment check passed.\n")
