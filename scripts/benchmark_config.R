#!/usr/bin/env Rscript

source(file.path("scripts", "output_config.R"))

benchmark_bool <- function(name, default = FALSE) {
  value <- toupper(Sys.getenv(name, unset = if (default) "TRUE" else "FALSE"))
  if (!value %in% c("TRUE", "FALSE")) stop(name, " must be TRUE or FALSE.")
  value == "TRUE"
}

benchmark_int <- function(name, default, minimum = 1L) {
  value <- suppressWarnings(as.integer(Sys.getenv(name, unset = as.character(default))))
  if (is.na(value) || value < minimum) stop(name, " must be an integer >= ", minimum, ".")
  value
}

benchmark_num <- function(name, default, minimum = 0) {
  value <- suppressWarnings(as.numeric(Sys.getenv(name, unset = as.character(default))))
  if (is.na(value) || value <= minimum) stop(name, " must be greater than ", minimum, ".")
  value
}

benchmark_fraction <- function(name, default) {
  value <- suppressWarnings(as.numeric(Sys.getenv(name, unset = as.character(default))))
  if (is.na(value) || value <= 0 || value > 1)
    stop(name, " must be a number in the interval (0, 1].")
  value
}

benchmark_int_list <- function(name, default) {
  text <- Sys.getenv(name, unset = paste(default, collapse = ","))
  values <- suppressWarnings(as.integer(strsplit(text, ",", fixed = TRUE)[[1]]))
  if (!length(values) || anyNA(values) || any(values < 1L))
    stop(name, " must be a comma-separated list of positive integers.")
  unique(values)
}

BENCHMARK_SMOKE <- benchmark_bool("BENCHMARK_SMOKE", RCS_RUN_SCOPE != "publication")
if (RCS_RUN_SCOPE == "publication" && BENCHMARK_SMOKE)
  stop("Publication scope cannot run BENCHMARK_SMOKE=TRUE.")

BENCHMARK_DATA_SEED <- benchmark_int("BENCHMARK_DATA_SEED", 20260504L, 0L)
BENCHMARK_ORDER_SEED <- benchmark_int("BENCHMARK_ORDER_SEED", 20260824L, 0L)
BENCHMARK_REPS <- benchmark_int("BENCHMARK_REPS", if (BENCHMARK_SMOKE) 5L else 30L)
BENCHMARK_BOOT_REPS <- benchmark_int("BENCHMARK_BOOT_REPS", if (BENCHMARK_SMOKE) 1000L else 5000L)
BENCHMARK_MIN_SAMPLE_SEC <- benchmark_num("BENCHMARK_MIN_SAMPLE_SEC", 0.50)
BENCHMARK_MAX_INNER_LOOPS <- benchmark_int("BENCHMARK_MAX_INNER_LOOPS", 1000000L)
BENCHMARK_WARMUP_CPU <- benchmark_int("BENCHMARK_WARMUP_CPU", if (BENCHMARK_SMOKE) 1L else 3L, 0L)
BENCHMARK_WARMUP_PARALLEL <- benchmark_int("BENCHMARK_WARMUP_PARALLEL", if (BENCHMARK_SMOKE) 1L else 2L, 0L)
BENCHMARK_WARMUP_CUDA <- benchmark_int("BENCHMARK_WARMUP_CUDA", if (BENCHMARK_SMOKE) 1L else 5L, 0L)
BENCHMARK_WORKLOADS <- benchmark_int_list(
  "BENCHMARK_WORKLOADS",
  if (BENCHMARK_SMOKE) c(10000L, 50000L, 100000L)
  else c(10000L, 50000L, 100000L, 500000L, 1000000L, 2000000L, 5000000L)
)
BENCHMARK_PROCESS_WORKERS <- benchmark_int_list(
  "BENCHMARK_PROCESS_WORKERS",
  if (BENCHMARK_SMOKE) c(1L, 2L) else c(1L, 2L, 4L, 8L, 16L)
)
BENCHMARK_OPENMP_THREADS <- benchmark_int_list(
  "BENCHMARK_OPENMP_THREADS",
  if (BENCHMARK_SMOKE) c(1L, 2L) else c(1L, 2L, 4L, 8L, 16L)
)
BENCHMARK_PRIMARY_WORKERS <- benchmark_int("BENCHMARK_PRIMARY_WORKERS", if (BENCHMARK_SMOKE) 2L else 8L)
BENCHMARK_RUN_CUDA <- benchmark_bool("BENCHMARK_RUN_CUDA", FALSE)
BENCHMARK_RUN_PYTHON <- benchmark_bool("BENCHMARK_RUN_PYTHON", TRUE)
BENCHMARK_RESUME <- benchmark_bool("BENCHMARK_RESUME", FALSE)
BENCHMARK_MIN_STABILITY_RATE <- benchmark_fraction("BENCHMARK_MIN_STABILITY_RATE", if (BENCHMARK_SMOKE) 0.80 else 0.90)
BENCHMARK_MAX_CV_PERCENT_SMOKE <- benchmark_num("BENCHMARK_MAX_CV_PERCENT_SMOKE", 30)
BENCHMARK_MAX_RELATIVE_CI_PERCENT <- benchmark_num("BENCHMARK_MAX_RELATIVE_CI_PERCENT", 10)
BENCHMARK_ENFORCE_QUALITY_GATES <- benchmark_bool("BENCHMARK_ENFORCE_QUALITY_GATES", !BENCHMARK_SMOKE)
BENCHMARK_ENFORCE_E2E_STABILITY <- benchmark_bool("BENCHMARK_ENFORCE_E2E_STABILITY", FALSE)

if (!1L %in% BENCHMARK_PROCESS_WORKERS) stop("BENCHMARK_PROCESS_WORKERS must include 1.")
if (!1L %in% BENCHMARK_OPENMP_THREADS) stop("BENCHMARK_OPENMP_THREADS must include 1.")

BENCHMARK_WORK_ROOT <- file.path(RCS_OUTPUT_ROOT, ".benchmark_work")
BENCHMARK_INPUTS <- file.path(BENCHMARK_WORK_ROOT, "inputs")
BENCHMARK_EXPECTED <- file.path(BENCHMARK_WORK_ROOT, "expected")
BENCHMARK_RESULTS <- file.path(BENCHMARK_WORK_ROOT, "results")
BENCHMARK_BIN <- file.path(BENCHMARK_WORK_ROOT, "bin")
BENCHMARK_TABLES <- RCS_TABLES_DIR
BENCHMARK_LOGS <- RCS_ENVIRONMENT_DIR

invisible(lapply(
  c(BENCHMARK_WORK_ROOT, BENCHMARK_INPUTS, BENCHMARK_EXPECTED, BENCHMARK_RESULTS,
    BENCHMARK_BIN, BENCHMARK_TABLES, BENCHMARK_LOGS),
  dir.create, recursive = TRUE, showWarnings = FALSE
))
