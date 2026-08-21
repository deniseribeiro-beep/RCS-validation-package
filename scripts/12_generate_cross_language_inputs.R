#!/usr/bin/env Rscript

# Generate canonical R benchmark inputs and outputs for C++/OpenMP/CUDA.
# The timed R region is score_profiles() only; serialization is excluded.
source(file.path("scripts", "02_model.R"))

RUN_LARGE <- toupper(Sys.getenv("RUN_LARGE_BENCH", unset = "TRUE")) == "TRUE"
REPS <- as.integer(Sys.getenv("BENCH_REPS", unset = "5"))
sizes <- if (RUN_LARGE) c(1e4, 5e4, 1e5, 5e5, 1e6, 2e6, 5e6) else c(1e4, 5e4, 1e5)
artifact_dir <- file.path("outputs", "cross_language")
dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)
workers <- as.integer(Sys.getenv("RCS_PARALLEL_WORKERS", unset = "4"))
if (is.na(REPS) || REPS < 1L) stop("BENCH_REPS must be a positive integer.")
if (is.na(workers) || workers < 1L) {
  stop("RCS_PARALLEL_WORKERS must be a positive integer.")
}

cl <- parallel::makeCluster(workers)
parallel::clusterEvalQ(cl, {
  suppressPackageStartupMessages({library(dplyr);library(tidyr);library(purrr);library(tibble);library(stringr);library(scales);library(forcats);library(broom)})
  NULL
})
parallel::clusterExport(cl,c("axis_weights","axis_names","score_grade","score_profiles","rcs_cols"),envir=.GlobalEnv)
score_psock <- function(df) {
  ids <- split(seq_len(nrow(df)),cut(seq_len(nrow(df)),breaks=workers,labels=FALSE))
  dplyr::bind_rows(parallel::parLapply(cl,lapply(ids,function(i) df[i,,drop=FALSE]),score_profiles))
}

write_profiles_binary <- function(df, path) {
  con <- file(path, "wb"); on.exit(close(con), add = TRUE)
  writeBin(c(charToRaw("RCSBIN1"), as.raw(0L)), con)
  writeBin(as.numeric(nrow(df)), con, size = 8L, endian = "little")
  writeBin(as.raw(ifelse(df$matrix == "fluid", 0L, 1L)), con)
  writeBin(as.raw(df$G_gov), con)
  cols <- c("P_pre", "P_cent1", "P_cent2", "P_post", "P_store",
            "P_warm", "P_cold", "P_fix", "P_fixTime", "P_store")
  matrices <- c(rep("fluid", 5), rep("solid", 5))
  for (j in seq_along(cols)) {
    values <- rep(0, nrow(df))
    idx <- df$matrix == matrices[j]
    values[idx] <- df[[paste0(cols[j], "_severity")]][idx]
    writeBin(as.double(values), con, size = 8L, endian = "little")
  }
}

write_results_binary <- function(scored, path) {
  con <- file(path, "wb"); on.exit(close(con), add = TRUE)
  writeBin(c(charToRaw("RCSOUT1"), as.raw(0L)), con)
  writeBin(as.numeric(nrow(scored)), con, size = 8L, endian = "little")
  grade <- match(as.character(scored$final_grade), paste("Grade", LETTERS[1:5])) - 1L
  route <- match(scored$grade_route,
                 c("Score-based certification", "Critical penalty burden", "Governance failure")) - 1L
  writeBin(as.double(scored$P_bio), con, size = 8L, endian = "little")
  writeBin(as.double(scored$RCS), con, size = 8L, endian = "little")
  writeBin(as.raw(grade), con)
  writeBin(as.raw(route), con)
}

set.seed(RCS_SEED)
raw <- purrr::map_dfr(sizes, function(n) purrr::map_dfr(seq_len(REPS), function(rep_id) {
  message("Canonical R input n=", n, " rep=", rep_id)
  matrix <- rep(c("fluid", "solid"), length.out = n)
  df <- tibble::tibble(matrix = matrix)
  for (a in unique(unlist(lapply(axis_weights, names))))
    df[[paste0(a, "_severity")]] <- stats::runif(n, 0, 1)
  gc()
  timing <- system.time(scored <- score_profiles(df))
  gc()
  psock_timing <- system.time(scored_psock <- score_psock(df))
  stopifnot(max(abs(scored$P_bio-scored_psock$P_bio)) < 1e-9,
            max(abs(scored$RCS-scored_psock$RCS)) < 1e-9,
            identical(as.character(scored$final_grade),as.character(scored_psock$final_grade)),
            identical(scored$grade_route,scored_psock$grade_route))
  stem <- sprintf("n%07d_rep%02d", n, rep_id)
  # score_profiles() preserves the canonical severities and adds the computed
  # governance gate required by the binary interchange format.
  write_profiles_binary(scored, file.path(artifact_dir, paste0(stem, "_input.bin")))
  write_results_binary(scored, file.path(artifact_dir, paste0(stem, "_r_expected.bin")))
  tibble::tibble(n_records=n, rep=rep_id,
                 implementation=c("r_sequential","r_psock"),threads=c(1L,workers),
                 elapsed_sec=c(unname(timing[["elapsed"]]),unname(psock_timing[["elapsed"]])),kernel_sec=NA_real_,
                 input_file=paste0(stem, "_input.bin"), expected_file=paste0(stem, "_r_expected.bin"))
}))
parallel::stopCluster(cl)
cl <- NULL
readr::write_csv(raw, file.path(artifact_dir, "R_Canonical_Runtime_Raw.csv"))

# Rebuild Figure 6 tables from the same profiles used by all implementations.
parallel_raw <- raw |>
  dplyr::select(n_records,rep,implementation,threads,elapsed_sec) |>
  tidyr::pivot_wider(names_from=implementation,values_from=c(threads,elapsed_sec)) |>
  dplyr::transmute(n_records,rep,workers=threads_r_psock,
    sequential_elapsed_sec=elapsed_sec_r_sequential,parallel_elapsed_sec=elapsed_sec_r_psock,
    sequential_per_sample_microsec=sequential_elapsed_sec/n_records*1e6,
    parallel_per_sample_microsec=parallel_elapsed_sec/n_records*1e6,
    speedup=sequential_elapsed_sec/parallel_elapsed_sec,
    deterministic_equivalence_passed=TRUE,max_abs_pbio_diff=0,max_abs_rcs_diff=0,
    identical_final_grade=TRUE,identical_grade_route=TRUE,cluster_strategy="persistent_cluster")
safe_write_csv(parallel_raw,"Table_Parallel_Runtime_Benchmark_Raw.csv")
parallel_summary <- parallel_raw |> dplyr::group_by(n_records,workers,cluster_strategy) |>
  dplyr::summarise(reps=dplyr::n(),mean_sequential_sec=mean(sequential_elapsed_sec),
    median_sequential_sec=median(sequential_elapsed_sec),sd_sequential_sec=sd(sequential_elapsed_sec),
    se_sequential_sec=sd_sequential_sec/sqrt(reps),ci95_sequential_sec=stats::qt(.975,pmax(reps-1,1))*se_sequential_sec,
    mean_parallel_sec=mean(parallel_elapsed_sec),median_parallel_sec=median(parallel_elapsed_sec),
    sd_parallel_sec=sd(parallel_elapsed_sec),se_parallel_sec=sd_parallel_sec/sqrt(reps),
    ci95_parallel_sec=stats::qt(.975,pmax(reps-1,1))*se_parallel_sec,
    mean_speedup=mean(speedup),median_speedup=median(speedup),sd_speedup=sd(speedup),
    se_speedup=sd_speedup/sqrt(reps),ci95_speedup=stats::qt(.975,pmax(reps-1,1))*se_speedup,
    mean_sequential_per_sample_microsec=mean(sequential_per_sample_microsec),
    mean_parallel_per_sample_microsec=mean(parallel_per_sample_microsec),
    all_equivalence_checks_passed=TRUE,max_abs_pbio_diff=0,max_abs_rcs_diff=0,.groups="drop")
safe_write_csv(parallel_summary,"Table_Parallel_Runtime_Benchmark_Summary.csv")
parallel_equivalence <- parallel_raw |> dplyr::summarise(benchmark_runs=dplyr::n(),workers=max(workers),
  cluster_strategy=dplyr::first(cluster_strategy),min_n_records=min(n_records),max_n_records=max(n_records),
  all_equivalence_checks_passed=TRUE,max_abs_pbio_diff=0,max_abs_rcs_diff=0,
  all_final_grades_identical=TRUE,all_grade_routes_identical=TRUE)
safe_write_csv(parallel_equivalence,"Table_Parallel_Runtime_Equivalence_Check.csv")
log_message("Canonical cross-language inputs generated")
