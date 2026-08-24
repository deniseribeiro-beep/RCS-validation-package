#!/usr/bin/env Rscript

v2_bool <- function(name, default = FALSE) {
  value <- toupper(Sys.getenv(name, unset = if (default) "TRUE" else "FALSE"))
  if (!value %in% c("TRUE", "FALSE")) stop(name, " must be TRUE or FALSE.")
  value == "TRUE"
}

v2_int <- function(name, default, minimum = 1L) {
  value <- suppressWarnings(as.integer(Sys.getenv(name, unset = as.character(default))))
  if (is.na(value) || value < minimum) stop(name, " must be an integer >= ", minimum, ".")
  value
}

v2_num <- function(name, default, minimum = 0) {
  value <- suppressWarnings(as.numeric(Sys.getenv(name, unset = as.character(default))))
  if (is.na(value) || value <= minimum) stop(name, " must be greater than ", minimum, ".")
  value
}

v2_int_list <- function(name, default) {
  text <- Sys.getenv(name, unset = paste(default, collapse = ","))
  values <- suppressWarnings(as.integer(strsplit(text, ",", fixed = TRUE)[[1]]))
  if (!length(values) || anyNA(values) || any(values < 1L))
    stop(name, " must be a comma-separated list of positive integers.")
  unique(values)
}

V2_SMOKE <- v2_bool("V2_SMOKE", TRUE)
V2_PROTOCOL_VERSION <- "2.0.0"
V2_DATA_SEED <- v2_int("V2_DATA_SEED", 20260504L, 0L)
V2_ORDER_SEED <- v2_int("V2_ORDER_SEED", 20260824L, 0L)
V2_REPS <- v2_int("V2_REPS", if (V2_SMOKE) 2L else 20L)
V2_BOOT_REPS <- v2_int("V2_BOOT_REPS", if (V2_SMOKE) 200L else 2000L)
V2_MIN_SAMPLE_SEC <- v2_num("V2_MIN_SAMPLE_SEC", if (V2_SMOKE) 0.05 else 0.25)
V2_MAX_INNER_LOOPS <- v2_int("V2_MAX_INNER_LOOPS", if (V2_SMOKE) 1000L else 1000000L)
V2_WARMUP_CPU <- v2_int("V2_WARMUP_CPU", if (V2_SMOKE) 1L else 3L, 0L)
V2_WARMUP_PARALLEL <- v2_int("V2_WARMUP_PARALLEL", if (V2_SMOKE) 1L else 2L, 0L)
V2_WARMUP_CUDA <- v2_int("V2_WARMUP_CUDA", if (V2_SMOKE) 1L else 5L, 0L)
V2_WORKLOADS <- v2_int_list("V2_WORKLOADS", if (V2_SMOKE) c(10000L, 50000L) else c(10000L, 50000L, 100000L, 500000L, 1000000L, 2000000L, 5000000L))
V2_PROCESS_WORKERS <- v2_int_list("V2_PROCESS_WORKERS", if (V2_SMOKE) c(1L, 2L) else c(1L, 2L, 4L, 8L))
V2_OPENMP_THREADS <- v2_int_list("V2_OPENMP_THREADS", if (V2_SMOKE) c(1L, 2L) else c(1L, 2L, 4L, 8L, 16L))
V2_PRIMARY_WORKERS <- v2_int("V2_PRIMARY_WORKERS", if (V2_SMOKE) 2L else 8L)
V2_RUN_CUDA <- v2_bool("V2_RUN_CUDA", FALSE)
V2_RUN_PYTHON <- v2_bool("V2_RUN_PYTHON", TRUE)
V2_RESUME <- v2_bool("V2_RESUME", FALSE)

V2_ROOT <- file.path("outputs", "benchmark_v2")
V2_INPUTS <- file.path(V2_ROOT, "inputs")
V2_EXPECTED <- file.path(V2_ROOT, "expected")
V2_RESULTS <- file.path(V2_ROOT, "results")
V2_BIN <- file.path(V2_ROOT, "bin")
V2_TABLES <- file.path(V2_ROOT, "tables")
V2_FIGURES <- file.path(V2_ROOT, "figures")
V2_LOGS <- file.path(V2_ROOT, "environment")
invisible(lapply(c(V2_ROOT, V2_INPUTS, V2_EXPECTED, V2_RESULTS, V2_BIN, V2_TABLES, V2_FIGURES, V2_LOGS), dir.create, recursive = TRUE, showWarnings = FALSE))
