#!/usr/bin/env Rscript

# ==========================================================
# 10_parallel_runtime_benchmark.R
# Ribeiro Classification Score (RCS)
#
# Optional full-scale parallel benchmark using persistent workers.
#
# Purpose:
#   Evaluate whether profile-level batch parallelism preserves
#   deterministic equivalence with the sequential RCS scoring function,
#   using cohort sizes from 10,000 to 5,000,000 records.
#
# Outputs:
#   outputs/tables/Table_Parallel_Runtime_Benchmark_Raw.csv
#   outputs/tables/Table_Parallel_Runtime_Benchmark_Summary.csv
#   outputs/tables/Table_Parallel_Runtime_Equivalence_Check.csv
# ==========================================================

source(file.path("scripts", "02_model.R"))

log_message("Running full-scale persistent-cluster parallel runtime benchmark")

if (!requireNamespace("parallel", quietly = TRUE)) {
  stop("The 'parallel' package is required but not available.")
}

RUN_LARGE <- toupper(Sys.getenv("RUN_LARGE_BENCH", unset = "TRUE")) == "TRUE"
REPS <- as.integer(Sys.getenv("BENCH_REPS", unset = "5"))

# Full-scale benchmark requested for the manuscript:
# 10k, 50k, 100k, 500k, 1M, 2M, and 5M records.
sizes <- if (RUN_LARGE) {
  c(1e4, 5e4, 1e5, 5e5, 1e6, 2e6, 5e6)
} else {
  c(1e4, 5e4, 1e5)
}

requested_workers <- as.integer(Sys.getenv(
  "RCS_PARALLEL_WORKERS",
  unset = as.character(max(1, parallel::detectCores(logical = TRUE) - 1))
))

workers <- max(1, requested_workers)

message("Parallel workers requested: ", workers)
message("Benchmark repetitions: ", REPS)
message("Large benchmark mode: ", RUN_LARGE)
message("Benchmark sizes: ", paste(scales::comma(sizes), collapse = ", "))

make_bench_df <- function(n) {
  matrix <- rep(c("fluid", "solid"), length.out = n)
  df <- tibble::tibble(matrix = matrix)

  all_axes <- unique(unlist(lapply(axis_weights, names)))

  for (a in all_axes) {
    df[[paste0(a, "_severity")]] <- stats::runif(n, 0, 1)
  }

  df
}

split_indices <- function(n, workers) {
  workers <- max(1, min(workers, n))
  ids <- seq_len(n)
  split(ids, cut(ids, breaks = workers, labels = FALSE))
}

make_cluster_once <- function(workers) {
  cl <- parallel::makeCluster(workers)

  parallel::clusterEvalQ(cl, {
    suppressPackageStartupMessages({
      library(dplyr)
      library(tidyr)
      library(purrr)
      library(tibble)
      library(stringr)
      library(scales)
      library(forcats)
      library(broom)
    })
    NULL
  })

  parallel::clusterExport(
    cl,
    varlist = c(
      "axis_weights",
      "axis_names",
      "score_grade",
      "score_profiles",
      "rcs_cols"
    ),
    envir = .GlobalEnv
  )

  cl
}

score_profiles_parallel_persistent <- function(df, cl, workers) {
  workers <- max(1, min(workers, nrow(df)))

  if (workers == 1 || nrow(df) == 0) {
    return(score_profiles(df))
  }

  idx_list <- split_indices(nrow(df), workers)

  chunks <- lapply(idx_list, function(idx) {
    df[idx, , drop = FALSE]
  })

  out <- parallel::parLapply(
    cl,
    chunks,
    function(chunk) {
      score_profiles(chunk)
    }
  )

  dplyr::bind_rows(out)
}

compare_outputs <- function(seq_out, par_out) {
  tibble::tibble(
    same_n_rows = nrow(seq_out) == nrow(par_out),
    max_abs_pbio_diff = max(abs(seq_out$P_bio - par_out$P_bio), na.rm = TRUE),
    max_abs_rcs_diff = max(abs(seq_out$RCS - par_out$RCS), na.rm = TRUE),
    identical_final_grade = all(as.character(seq_out$final_grade) == as.character(par_out$final_grade)),
    identical_grade_route = all(as.character(seq_out$grade_route) == as.character(par_out$grade_route)),
    deterministic_equivalence_passed =
      nrow(seq_out) == nrow(par_out) &&
      max(abs(seq_out$P_bio - par_out$P_bio), na.rm = TRUE) < 1e-9 &&
      max(abs(seq_out$RCS - par_out$RCS), na.rm = TRUE) < 1e-9 &&
      all(as.character(seq_out$final_grade) == as.character(par_out$final_grade)) &&
      all(as.character(seq_out$grade_route) == as.character(par_out$grade_route))
  )
}

cl <- NULL

if (workers > 1) {
  cl <- make_cluster_once(workers)

  on.exit({
    try(parallel::stopCluster(cl), silent = TRUE)
  }, add = TRUE)
}

raw <- purrr::map_dfr(sizes, function(n) {
  purrr::map_dfr(seq_len(REPS), function(rep_id) {
    message("Benchmark n=", scales::comma(n), " rep=", rep_id, " workers=", workers)

    df <- make_bench_df(n)

    gc()
    t_seq <- system.time({
      scored_seq <- score_profiles(df)
    })

    gc()
    t_par <- system.time({
      scored_par <- if (workers > 1) {
        score_profiles_parallel_persistent(df, cl = cl, workers = workers)
      } else {
        score_profiles(df)
      }
    })

    eq <- compare_outputs(scored_seq, scored_par)

    tibble::tibble(
      n_records = n,
      rep = rep_id,
      workers = workers,
      sequential_elapsed_sec = unname(t_seq[["elapsed"]]),
      parallel_elapsed_sec = unname(t_par[["elapsed"]]),
      sequential_per_sample_microsec = sequential_elapsed_sec / n * 1e6,
      parallel_per_sample_microsec = parallel_elapsed_sec / n * 1e6,
      speedup = sequential_elapsed_sec / parallel_elapsed_sec,
      deterministic_equivalence_passed = eq$deterministic_equivalence_passed,
      max_abs_pbio_diff = eq$max_abs_pbio_diff,
      max_abs_rcs_diff = eq$max_abs_rcs_diff,
      identical_final_grade = eq$identical_final_grade,
      identical_grade_route = eq$identical_grade_route,
      cluster_strategy = ifelse(workers > 1, "persistent_cluster", "sequential_fallback")
    )
  })
})

safe_write_csv(raw, "Table_Parallel_Runtime_Benchmark_Raw.csv")

summary <- raw |>
  dplyr::group_by(n_records, workers, cluster_strategy) |>
  dplyr::summarise(
    reps = dplyr::n(),
    mean_sequential_sec = mean(sequential_elapsed_sec),
    median_sequential_sec = median(sequential_elapsed_sec),
    sd_sequential_sec = stats::sd(sequential_elapsed_sec),
    se_sequential_sec = sd_sequential_sec / sqrt(reps),
    ci95_sequential_sec = stats::qt(0.975, df = pmax(reps - 1, 1)) * se_sequential_sec,

    mean_parallel_sec = mean(parallel_elapsed_sec),
    median_parallel_sec = median(parallel_elapsed_sec),
    sd_parallel_sec = stats::sd(parallel_elapsed_sec),
    se_parallel_sec = sd_parallel_sec / sqrt(reps),
    ci95_parallel_sec = stats::qt(0.975, df = pmax(reps - 1, 1)) * se_parallel_sec,

    mean_speedup = mean(speedup),
    median_speedup = median(speedup),
    sd_speedup = stats::sd(speedup),
    se_speedup = sd_speedup / sqrt(reps),
    ci95_speedup = stats::qt(0.975, df = pmax(reps - 1, 1)) * se_speedup,

    mean_sequential_per_sample_microsec = mean(sequential_per_sample_microsec),
    mean_parallel_per_sample_microsec = mean(parallel_per_sample_microsec),

    all_equivalence_checks_passed = all(deterministic_equivalence_passed),
    max_abs_pbio_diff = max(max_abs_pbio_diff),
    max_abs_rcs_diff = max(max_abs_rcs_diff),
    .groups = "drop"
  )

safe_write_csv(summary, "Table_Parallel_Runtime_Benchmark_Summary.csv")

equivalence <- raw |>
  dplyr::summarise(
    benchmark_runs = dplyr::n(),
    workers = max(workers),
    cluster_strategy = dplyr::first(cluster_strategy),
    min_n_records = min(n_records),
    max_n_records = max(n_records),
    all_equivalence_checks_passed = all(deterministic_equivalence_passed),
    max_abs_pbio_diff = max(max_abs_pbio_diff),
    max_abs_rcs_diff = max(max_abs_rcs_diff),
    all_final_grades_identical = all(identical_final_grade),
    all_grade_routes_identical = all(identical_grade_route)
  )

safe_write_csv(equivalence, "Table_Parallel_Runtime_Equivalence_Check.csv")

if (!all(raw$deterministic_equivalence_passed)) {
  stop("Parallel benchmark failed deterministic equivalence checks.")
}

log_message("Full-scale persistent-cluster parallel runtime benchmark completed")
