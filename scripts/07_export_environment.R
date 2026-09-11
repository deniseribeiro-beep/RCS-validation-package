#!/usr/bin/env Rscript

source(file.path("scripts", "01_config_utils.R"))
source(file.path("scripts", "benchmark_config.R"))
log_message("Exporting computational environment")

capture_command <- function(command, args = character()) {
  if (!nzchar(Sys.which(command))) return(paste(command, "not found"))
  paste(system2(command, args, stdout = TRUE, stderr = TRUE), collapse = " | ")
}

sink(file.path(DIR_LOGS, "SessionInfo_RCS.txt"))
print(sessionInfo())
sink()

env_lines <- c(
  paste("Date:", Sys.time()),
  paste("Git commit:", capture_command("git", c("rev-parse", "HEAD"))),
  paste("R:", R.version.string),
  paste("Python:", capture_command("python3", "--version")),
  paste("NumPy:", capture_command("python3", c("-c", shQuote("import numpy; print(numpy.__version__)")))),
  paste("Cython:", capture_command("python3", c("-c", shQuote("import Cython; print(Cython.__version__)")))),
  paste("C++:", capture_command("g++", "--version")),
  paste("CUDA:", capture_command("nvcc", "--version")),
  paste("GPU:", capture_command("nvidia-smi", c("--query-gpu=name,driver_version,memory.total", "--format=csv,noheader"))),
  paste("OS:", paste(Sys.info(), collapse = " ")),
  paste("RCS seed:", RCS_SEED),
  paste("Benchmark data seed:", BENCHMARK_DATA_SEED),
  paste("Benchmark order seed:", BENCHMARK_ORDER_SEED),
  paste("Benchmark repetitions:", BENCHMARK_REPS),
  paste("Bootstrap repetitions:", BENCHMARK_BOOT_REPS),
  paste("Minimum calibrated sample seconds:", BENCHMARK_MIN_SAMPLE_SEC),
  paste("Maximum inner loops:", BENCHMARK_MAX_INNER_LOOPS),
  "Calibration method: iterative observed-duration gate with 10% safety factor",
  paste("Minimum accepted stability rate:", BENCHMARK_MIN_STABILITY_RATE),
  paste("Maximum smoke-test CV percent:", BENCHMARK_MAX_CV_PERCENT_SMOKE),
  paste("Maximum publication relative CI half-width percent:", BENCHMARK_MAX_RELATIVE_CI_PERCENT),
  paste("Quality gates enforced:", BENCHMARK_ENFORCE_QUALITY_GATES),
  paste("End-to-end stability enforced:", BENCHMARK_ENFORCE_E2E_STABILITY),
  paste("R PSOCK workers:", paste(BENCHMARK_PROCESS_WORKERS, collapse = ",")),
  paste("OpenMP threads:", paste(BENCHMARK_OPENMP_THREADS, collapse = ",")),
  "C++ flags: -std=c++17 -O3 -DNDEBUG -march=native",
  "OpenMP flags: -std=c++17 -O3 -DNDEBUG -march=native -fopenmp",
  "CUDA flags: -std=c++17 -O3 -Xcompiler -march=native",
  paste("OMP_PROC_BIND:", Sys.getenv("OMP_PROC_BIND", unset = "not set")),
  paste("OMP_PLACES:", Sys.getenv("OMP_PLACES", unset = "not set")),
  paste("OPENBLAS_NUM_THREADS:", Sys.getenv("OPENBLAS_NUM_THREADS", unset = "not set"))
)
write_log_text(env_lines, "Computational_Environment.txt")
log_message("Computational environment exported")
