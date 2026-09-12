#!/usr/bin/env Rscript

bool_env <- function(name, default = FALSE) {
  value <- toupper(Sys.getenv(name, unset = if (default) "TRUE" else "FALSE"))
  if (!value %in% c("TRUE", "FALSE")) stop(name, " must be TRUE or FALSE.")
  value == "TRUE"
}

command_available <- function(command) nzchar(Sys.which(command))
status_ok <- function(x) is.null(attr(x, "status")) || identical(attr(x, "status"), 0L)

run_python <- bool_env("BENCHMARK_RUN_PYTHON", TRUE)
run_cuda <- bool_env("BENCHMARK_RUN_CUDA", FALSE)
python_dependencies_preverified <- bool_env("BENCHMARK_PYTHON_DEPS_VERIFIED", FALSE)

python_executable <- unname(Sys.which("python3"))
python_package_available <- function(package) {
  if (!nzchar(python_executable)) return(FALSE)
  if (python_dependencies_preverified) return(TRUE)
  status <- suppressWarnings(system2(
    python_executable,
    c("-m", "pip", "show", package),
    stdout = FALSE,
    stderr = FALSE
  ))
  isTRUE(as.integer(status) == 0L)
}

openmp_available <- function() {
  if (!command_available("g++")) return(FALSE)
  src <- tempfile("rcs-openmp-check-", fileext = ".cpp")
  bin <- tempfile("rcs-openmp-check-")
  on.exit(unlink(c(src, bin), force = TRUE), add = TRUE)
  writeLines(c(
    "#include <omp.h>",
    "int main(void) { return omp_get_max_threads() < 1 ? 1 : 0; }"
  ), src)
  status <- suppressWarnings(system2(
    "g++",
    c("-std=c++17", "-fopenmp", src, "-o", bin),
    stdout = FALSE,
    stderr = FALSE
  ))
  isTRUE(as.integer(status) == 0L)
}

nvidia_gpu_available <- function() {
  if (!command_available("nvidia-smi")) return(FALSE)
  status <- suppressWarnings(system2("nvidia-smi", "-L", stdout = FALSE, stderr = FALSE))
  isTRUE(as.integer(status) == 0L)
}

checks <- data.frame(
  component = c(
    "Rscript", "C compiler (cc)", "C++ compiler (g++)", "OpenMP via g++",
    "Python 3", "Python NumPy", "Python Cython", "Python setuptools",
    "nvcc", "NVIDIA GPU"
  ),
  available = c(
    command_available("Rscript"),
    command_available("cc"),
    command_available("g++"),
    openmp_available(),
    command_available("python3"),
    python_package_available("numpy"),
    python_package_available("Cython"),
    python_package_available("setuptools"),
    command_available("nvcc"),
    nvidia_gpu_available()
  ),
  required = c(
    TRUE, TRUE, TRUE, TRUE,
    run_python, run_python, run_python, run_python,
    run_cuda, run_cuda
  ),
  stringsAsFactors = FALSE
)

cat("Benchmark requirements\n")
cat("BENCHMARK_RUN_PYTHON:", run_python, "\n")
cat("BENCHMARK_RUN_CUDA:", run_cuda, "\n")
if (python_dependencies_preverified) cat("Python dependencies: pre-verified by caller.\n")
print(checks, row.names = FALSE)

missing <- checks$component[checks$required & !checks$available]
if (length(missing)) {
  stop("Missing benchmark requirements: ", paste(missing, collapse = ", "))
}

cat("Benchmark requirements passed.\n")
