#!/usr/bin/env Rscript

source(file.path("scripts", "benchmark_config.R"))

raw_path <- file.path(BENCHMARK_TABLES, "Table_Benchmark_Runtime_Raw.csv")
if (!file.exists(raw_path)) stop("Run scripts/benchmark_run.R first.")
raw <- read.csv(raw_path, stringsAsFactors = FALSE)
if ("protocol_version" %in% names(raw)) stop("Legacy protocol_version schema is not supported.")
if (!nrow(raw) || any(!raw$equivalence_passed) || any(!is.finite(raw$elapsed_sec)) || any(raw$elapsed_sec <= 0))
  stop("Benchmark raw results are invalid or incomplete.")

family_map <- c(
  c_reference = "C reference",
  r_sequential = "R", r_psock = "R",
  cython_sequential = "Python/Cython", cython_openmp = "Python/Cython",
  cpp_sequential = "C++", cpp_openmp = "C++", cpp_cuda = "CUDA"
)
baseline_map <- c(R = "r_sequential", `Python/Cython` = "cython_sequential", `C++` = "cpp_sequential")
parallel_map <- c(R = "r_psock", `Python/Cython` = "cython_openmp", `C++` = "cpp_openmp")
raw$language_family <- unname(family_map[raw$implementation])
if (anyNA(raw$language_family)) stop("Unknown benchmark implementation in raw results.")

raw$is_timing_outlier <- FALSE
outlier_groups <- split(
  seq_len(nrow(raw)),
  interaction(raw$n_records, raw$implementation, raw$workers, raw$timing_region, drop = TRUE)
)
for (idx in outlier_groups) {
  values <- log(raw$elapsed_sec[idx])
  center <- stats::median(values)
  spread <- stats::mad(values, center = center, constant = 1.4826)
  if (is.finite(spread) && spread > 0)
    raw$is_timing_outlier[idx] <- abs(values - center) / spread > 3.5
}

outlier_diagnostics <- raw[, c(
  "language_family", "n_records", "repetition", "random_order", "implementation",
  "workers", "timing_region", "elapsed_sec", "measurement_block_sec", "is_timing_outlier"
)]
write.csv(outlier_diagnostics, file.path(BENCHMARK_TABLES, "Table_Benchmark_Outlier_Diagnostics.csv"), row.names = FALSE)

calibration_diagnostics <- raw[raw$timing_region == "compute", c(
  "language_family", "n_records", "repetition", "implementation", "workers",
  "inner_loops", "elapsed_sec", "measurement_block_sec", "minimum_block_sec",
  "calibration_floor_passed", "calibration_attempts"
)]
write.csv(calibration_diagnostics, file.path(BENCHMARK_TABLES, "Table_Benchmark_Calibration_Diagnostics.csv"), row.names = FALSE)

set.seed(BENCHMARK_ORDER_SEED + 1L)
geomean <- function(x) exp(mean(log(x)))
bootstrap_ci <- function(x, statistic, reps = BENCHMARK_BOOT_REPS) {
  x <- x[is.finite(x) & x > 0]
  if (length(x) == 1L) return(c(x, x))
  unname(stats::quantile(
    replicate(reps, statistic(sample(x, length(x), TRUE))),
    c(.025, .975), type = 8
  ))
}

summarize_runtime <- function(x) {
  ci <- bootstrap_ci(x$elapsed_sec, median)
  relative_ci <- (ci[2] - ci[1]) / (2 * median(x$elapsed_sec)) * 100
  cv <- stats::sd(x$elapsed_sec) / mean(x$elapsed_sec) * 100
  precision_passed <- relative_ci <= BENCHMARK_MAX_RELATIVE_CI_PERCENT
  smoke_variability_passed <- cv <= BENCHMARK_MAX_CV_PERCENT_SMOKE
  data.frame(
    language_family = x$language_family[1], n_records = x$n_records[1],
    implementation = x$implementation[1], workers = x$workers[1], timing_region = x$timing_region[1],
    repetitions = nrow(x), median_elapsed_sec = median(x$elapsed_sec),
    median_ci95_low_sec = ci[1], median_ci95_high_sec = ci[2],
    geometric_mean_elapsed_sec = geomean(x$elapsed_sec), mean_elapsed_sec = mean(x$elapsed_sec),
    sd_elapsed_sec = stats::sd(x$elapsed_sec), iqr_elapsed_sec = stats::IQR(x$elapsed_sec),
    cv_percent = cv, median_throughput_profiles_sec = median(x$throughput_profiles_sec),
    relative_ci_half_width_percent = relative_ci, timing_outlier_count = sum(x$is_timing_outlier),
    precision_passed = precision_passed, smoke_variability_passed = smoke_variability_passed,
    stability_passed = if (BENCHMARK_SMOKE) smoke_variability_passed else precision_passed
  )
}

groups <- split(raw, interaction(raw$n_records, raw$implementation, raw$workers, raw$timing_region, drop = TRUE))
summary_table <- do.call(rbind, lapply(groups, summarize_runtime))
rownames(summary_table) <- NULL
write.csv(summary_table, file.path(BENCHMARK_TABLES, "Table_Benchmark_Runtime_Summary.csv"), row.names = FALSE)

parallel_raw <- raw[
  raw$language_family %in% names(baseline_map) &
    raw$implementation == unname(parallel_map[raw$language_family]),
]
refs <- raw[
  raw$implementation == unname(baseline_map[raw$language_family]),
  c("language_family", "n_records", "repetition", "timing_region", "elapsed_sec")
]
names(refs)[5] <- "sequential_elapsed_sec"
speedup_raw <- merge(
  parallel_raw, refs,
  by = c("language_family", "n_records", "repetition", "timing_region"), all.x = TRUE
)
speedup_raw$within_language_speedup <- speedup_raw$sequential_elapsed_sec / speedup_raw$elapsed_sec
speedup_raw$parallel_efficiency <- speedup_raw$within_language_speedup / speedup_raw$workers

summarize_speedup <- function(x) {
  ci <- bootstrap_ci(x$within_language_speedup, geomean)
  data.frame(
    language_family = x$language_family[1], n_records = x$n_records[1], implementation = x$implementation[1],
    workers = x$workers[1], timing_region = x$timing_region[1], repetitions = nrow(x),
    geometric_mean_speedup = geomean(x$within_language_speedup),
    speedup_ci95_low = ci[1], speedup_ci95_high = ci[2],
    median_speedup = median(x$within_language_speedup),
    median_efficiency = median(x$parallel_efficiency)
  )
}
sg <- split(
  speedup_raw,
  interaction(speedup_raw$language_family, speedup_raw$n_records, speedup_raw$workers, speedup_raw$timing_region, drop = TRUE)
)
speedup_summary <- do.call(rbind, lapply(sg, summarize_speedup))
rownames(speedup_summary) <- NULL
write.csv(speedup_summary, file.path(BENCHMARK_TABLES, "Table_Benchmark_Within_Language_Speedup_Summary.csv"), row.names = FALSE)

cuda_raw <- raw[raw$implementation == "cpp_cuda", ]
if (nrow(cuda_raw)) {
  cpp_reference <- raw[raw$implementation == "cpp_sequential", c("n_records", "repetition", "timing_region", "elapsed_sec")]
  names(cpp_reference)[4] <- "cpp_sequential_elapsed_sec"
  cuda_speedup_raw <- merge(cuda_raw, cpp_reference, by = c("n_records", "repetition", "timing_region"), all.x = TRUE)
  cuda_speedup_raw$cuda_speedup_vs_cpp_sequential <- cuda_speedup_raw$cpp_sequential_elapsed_sec / cuda_speedup_raw$elapsed_sec
  cuda_groups <- split(cuda_speedup_raw, interaction(cuda_speedup_raw$n_records, cuda_speedup_raw$timing_region, drop = TRUE))
  cuda_summary <- do.call(rbind, lapply(cuda_groups, function(x) {
    ci <- bootstrap_ci(x$cuda_speedup_vs_cpp_sequential, geomean)
    data.frame(
      n_records = x$n_records[1], timing_region = x$timing_region[1], repetitions = nrow(x),
      geometric_mean_speedup = geomean(x$cuda_speedup_vs_cpp_sequential),
      speedup_ci95_low = ci[1], speedup_ci95_high = ci[2],
      median_speedup = median(x$cuda_speedup_vs_cpp_sequential),
      iqr_speedup = stats::IQR(x$cuda_speedup_vs_cpp_sequential)
    )
  }))
  rownames(cuda_summary) <- NULL
  write.csv(cuda_summary, file.path(BENCHMARK_TABLES, "Table_Benchmark_CUDA_Speedup_Summary.csv"), row.names = FALSE)
}

equivalence <- aggregate(cbind(max_abs_pbio_diff, max_abs_rcs_diff) ~ language_family + implementation + workers, raw, max)
equivalence$reference_implementation <- "C reference"
equivalence$all_equivalence_checks_passed <- TRUE
write.csv(equivalence, file.path(BENCHMARK_TABLES, "Table_Benchmark_Equivalence_Check.csv"), row.names = FALSE)

stability <- summary_table[, c(
  "language_family", "n_records", "implementation", "workers", "timing_region", "repetitions",
  "cv_percent", "relative_ci_half_width_percent", "timing_outlier_count",
  "precision_passed", "smoke_variability_passed", "stability_passed"
)]
write.csv(stability, file.path(BENCHMARK_TABLES, "Table_Benchmark_Measurement_Stability.csv"), row.names = FALSE)

compute_stability <- summary_table$timing_region == "compute"
e2e_stability <- summary_table$timing_region == "end_to_end"
compute_stability_rate <- mean(summary_table$stability_passed[compute_stability])
e2e_stability_rate <- mean(summary_table$stability_passed[e2e_stability])
compute_rows <- raw$timing_region == "compute"
calibration_gate_passed <- all(raw$calibration_floor_passed[compute_rows] %in% TRUE) &&
  all(raw$measurement_block_sec[compute_rows] >= raw$minimum_block_sec[compute_rows])
equivalence_gate_passed <- all(raw$equivalence_passed) &&
  all(raw$identical_final_grade) && all(raw$identical_grade_route) &&
  max(raw$max_abs_pbio_diff) <= 1e-9 && max(raw$max_abs_rcs_diff) <= 1e-9
compute_stability_gate_passed <- compute_stability_rate >= BENCHMARK_MIN_STABILITY_RATE
e2e_stability_gate_passed <- e2e_stability_rate >= BENCHMARK_MIN_STABILITY_RATE

quality_gates <- data.frame(
  run_mode = if (BENCHMARK_SMOKE) "smoke_diagnostic" else "publication",
  computational_reference = "C reference",
  quality_gates_enforced = BENCHMARK_ENFORCE_QUALITY_GATES,
  equivalence_gate_passed = equivalence_gate_passed,
  calibrated_compute_measurements = sum(compute_rows),
  calibrated_compute_measurements_passing = sum(raw$calibration_floor_passed[compute_rows] %in% TRUE),
  calibration_floor_gate_passed = calibration_gate_passed,
  compute_timing_conditions = sum(compute_stability),
  stable_compute_conditions = sum(summary_table$stability_passed[compute_stability]),
  compute_stability_rate = compute_stability_rate,
  compute_stability_gate_passed = compute_stability_gate_passed,
  end_to_end_timing_conditions = sum(e2e_stability),
  stable_end_to_end_conditions = sum(summary_table$stability_passed[e2e_stability]),
  end_to_end_stability_rate = e2e_stability_rate,
  end_to_end_stability_enforced = BENCHMARK_ENFORCE_E2E_STABILITY,
  end_to_end_stability_gate_passed = e2e_stability_gate_passed,
  required_stability_rate = BENCHMARK_MIN_STABILITY_RATE,
  stability_metric = if (BENCHMARK_SMOKE)
    paste0("CV <= ", BENCHMARK_MAX_CV_PERCENT_SMOKE, "% (diagnostic)")
  else paste0("bootstrap median CI relative half-width <= ", BENCHMARK_MAX_RELATIVE_CI_PERCENT, "%")
)
quality_gates$all_quality_gates_passed <- equivalence_gate_passed && calibration_gate_passed &&
  (!BENCHMARK_ENFORCE_QUALITY_GATES || (
    compute_stability_gate_passed && (!BENCHMARK_ENFORCE_E2E_STABILITY || e2e_stability_gate_passed)
  ))
write.csv(quality_gates, file.path(BENCHMARK_TABLES, "Table_Benchmark_Quality_Gates.csv"), row.names = FALSE)

phase_cols <- c("read_sec", "initialization_sec", "classification_sec", "write_sec", "process_overhead_sec")
phase_raw <- raw[raw$timing_region == "end_to_end", c(
  "language_family", "n_records", "repetition", "implementation", "workers", phase_cols
)]
phase_long <- reshape(phase_raw, varying = phase_cols, v.names = "elapsed_sec", timevar = "phase", times = phase_cols, direction = "long")
phase_summary <- aggregate(elapsed_sec ~ language_family + n_records + implementation + workers + phase, phase_long, median)
phase_summary$share_percent <- ave(
  phase_summary$elapsed_sec,
  interaction(phase_summary$language_family, phase_summary$n_records, phase_summary$implementation, phase_summary$workers),
  FUN = function(x) 100 * x / sum(x)
)
write.csv(phase_summary, file.path(BENCHMARK_TABLES, "Table_Benchmark_End_to_End_Phase_Decomposition.csv"), row.names = FALSE)

cuda_phase_cols <- c(
  "cuda_host_prepare_sec", "cuda_device_setup_sec", "cuda_h2d_sec", "cuda_kernel_sec",
  "cuda_d2h_sec", "cuda_device_teardown_sec", "cuda_host_finalize_sec", "cuda_disk_write_sec"
)
cuda_phases <- raw[
  raw$implementation == "cpp_cuda" & raw$timing_region == "end_to_end",
  c("n_records", "repetition", cuda_phase_cols)
]
if (nrow(cuda_phases)) {
  cuda_phase_long <- reshape(
    cuda_phases, varying = cuda_phase_cols, v.names = "elapsed_sec",
    timevar = "phase", times = cuda_phase_cols, direction = "long"
  )
  cuda_phase_summary <- aggregate(elapsed_sec ~ n_records + phase, cuda_phase_long, median)
  cuda_phase_summary$share_percent <- ave(cuda_phase_summary$elapsed_sec, cuda_phase_summary$n_records, FUN = function(x) 100 * x / sum(x))
  write.csv(cuda_phase_summary, file.path(BENCHMARK_TABLES, "Table_Benchmark_CUDA_Phase_Decomposition.csv"), row.names = FALSE)
}

cat("Benchmark tables generated with C-reference equivalence; no cross-language speedup comparisons were computed.\n")
cat(sprintf("Calibration floor gate: %d/%d compute measurements passed.\n",
            sum(raw$calibration_floor_passed[compute_rows] %in% TRUE), sum(compute_rows)))
cat(sprintf("Compute stability: %d/%d conditions (%.1f%%; target %.1f%%).\n",
            sum(summary_table$stability_passed[compute_stability]), sum(compute_stability),
            100 * compute_stability_rate, 100 * BENCHMARK_MIN_STABILITY_RATE))
cat(sprintf("End-to-end stability: %d/%d conditions (%.1f%%; %s).\n",
            sum(summary_table$stability_passed[e2e_stability]), sum(e2e_stability),
            100 * e2e_stability_rate,
            if (BENCHMARK_ENFORCE_E2E_STABILITY) "enforced" else "diagnostic only"))

if (BENCHMARK_SMOKE && !compute_stability_gate_passed)
  warning("Smoke-test variability exceeded the diagnostic target. Outputs are for pipeline validation only.")
if (BENCHMARK_ENFORCE_QUALITY_GATES && !quality_gates$all_quality_gates_passed)
  stop("Benchmark publication quality gate failed. Inspect calibration, stability, outlier, and quality-gate tables.")
if (!BENCHMARK_ENFORCE_QUALITY_GATES && !quality_gates$all_quality_gates_passed)
  stop("Benchmark mandatory C-reference equivalence or calibration floor gate failed.")
