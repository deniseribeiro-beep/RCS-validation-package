#!/usr/bin/env Rscript
source(file.path("benchmark_v2", "config.R"))
required <- c("ggplot2", "patchwork", "scales")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing R packages for V2 outputs: ", paste(missing, collapse = ", "))

raw_path <- file.path(V2_TABLES, "Table_V2_Runtime_Benchmark_Raw.csv")
if (!file.exists(raw_path)) stop("Run benchmark_v2/02_run_benchmark.R first.")
raw <- read.csv(raw_path, stringsAsFactors = FALSE)
if (!nrow(raw) || any(raw$protocol_version != V2_PROTOCOL_VERSION) || any(!raw$equivalence_passed) ||
    any(!is.finite(raw$elapsed_sec)) || any(raw$elapsed_sec <= 0)) stop("Raw V2 results are invalid or incomplete.")

family_map <- c(r_sequential="R", r_psock="R", cython_sequential="Python/Cython",
                cython_openmp="Python/Cython", cpp_sequential="C++", cpp_openmp="C++", cpp_cuda="CUDA")
baseline_map <- c(R="r_sequential", `Python/Cython`="cython_sequential", `C++`="cpp_sequential")
parallel_map <- c(R="r_psock", `Python/Cython`="cython_openmp", `C++`="cpp_openmp")
raw$language_family <- unname(family_map[raw$implementation])

# Gross timing outliers are flagged on the log scale with a robust MAD rule.
# They remain in every estimate and figure; this table is diagnostic and makes
# anomalous repetitions auditable instead of silently deleting them.
raw$is_timing_outlier <- FALSE
outlier_groups <- split(seq_len(nrow(raw)), interaction(raw$n_records, raw$implementation,
  raw$workers, raw$timing_region, drop=TRUE))
for (idx in outlier_groups) {
  values <- log(raw$elapsed_sec[idx])
  center <- stats::median(values)
  spread <- stats::mad(values, center=center, constant=1.4826)
  if (is.finite(spread) && spread > 0)
    raw$is_timing_outlier[idx] <- abs(values-center)/spread > 3.5
}
outlier_diagnostics <- raw[,c("protocol_version","language_family","n_records","repetition",
  "random_order","implementation","workers","timing_region","elapsed_sec",
  "measurement_block_sec","is_timing_outlier")]
write.csv(outlier_diagnostics, file.path(V2_TABLES, "Table_V2_Outlier_Diagnostics.csv"), row.names=FALSE)
calibration_diagnostics <- raw[raw$timing_region == "compute",
  c("protocol_version","language_family","n_records","repetition","implementation","workers",
    "inner_loops","elapsed_sec","measurement_block_sec","minimum_block_sec",
    "calibration_floor_passed","calibration_attempts")]
write.csv(calibration_diagnostics,
  file.path(V2_TABLES, "Table_V2_Calibration_Diagnostics.csv"), row.names=FALSE)

set.seed(V2_ORDER_SEED + 1L)
geomean <- function(x) exp(mean(log(x)))
bootstrap_ci <- function(x, statistic, reps=V2_BOOT_REPS) {
  x <- x[is.finite(x) & x > 0]
  if (length(x) == 1L) return(c(x, x))
  unname(stats::quantile(replicate(reps, statistic(sample(x, length(x), TRUE))), c(.025, .975), type=8))
}
summarize_runtime <- function(x) {
  ci <- bootstrap_ci(x$elapsed_sec, median)
  relative_ci <- (ci[2]-ci[1])/(2*median(x$elapsed_sec))*100
  cv <- stats::sd(x$elapsed_sec)/mean(x$elapsed_sec)*100
  precision_passed <- relative_ci <= V2_MAX_RELATIVE_CI_PERCENT
  smoke_variability_passed <- cv <= V2_MAX_CV_PERCENT_SMOKE
  data.frame(protocol_version=V2_PROTOCOL_VERSION, language_family=x$language_family[1], n_records=x$n_records[1],
    implementation=x$implementation[1], workers=x$workers[1], timing_region=x$timing_region[1], repetitions=nrow(x),
    median_elapsed_sec=median(x$elapsed_sec), median_ci95_low_sec=ci[1], median_ci95_high_sec=ci[2],
    geometric_mean_elapsed_sec=geomean(x$elapsed_sec), mean_elapsed_sec=mean(x$elapsed_sec),
    sd_elapsed_sec=stats::sd(x$elapsed_sec), iqr_elapsed_sec=stats::IQR(x$elapsed_sec),
    cv_percent=cv,
    median_throughput_profiles_sec=median(x$throughput_profiles_sec),
    relative_ci_half_width_percent=relative_ci,
    timing_outlier_count=sum(x$is_timing_outlier),
    precision_passed=precision_passed,
    smoke_variability_passed=smoke_variability_passed,
    stability_passed=if (V2_SMOKE) smoke_variability_passed else precision_passed)
}
groups <- split(raw, interaction(raw$n_records, raw$implementation, raw$workers, raw$timing_region, drop=TRUE))
summary_table <- do.call(rbind, lapply(groups, summarize_runtime)); rownames(summary_table) <- NULL
write.csv(summary_table, file.path(V2_TABLES, "Table_V2_Runtime_Benchmark_Summary.csv"), row.names=FALSE)

# Sequential-to-parallel speedups are paired only within the same language family.
parallel_raw <- raw[raw$language_family %in% names(baseline_map) &
                    raw$implementation == unname(parallel_map[raw$language_family]), ]
refs <- raw[raw$implementation == unname(baseline_map[raw$language_family]),
            c("language_family","n_records","repetition","timing_region","elapsed_sec")]
names(refs)[5] <- "sequential_elapsed_sec"
speedup_raw <- merge(parallel_raw, refs, by=c("language_family","n_records","repetition","timing_region"), all.x=TRUE)
speedup_raw$within_language_speedup <- speedup_raw$sequential_elapsed_sec / speedup_raw$elapsed_sec
speedup_raw$parallel_efficiency <- speedup_raw$within_language_speedup / speedup_raw$workers
write.csv(speedup_raw, file.path(V2_TABLES, "Table_V2_Within_Language_Speedup_Raw.csv"), row.names=FALSE)
summarize_speedup <- function(x) {
  ci <- bootstrap_ci(x$within_language_speedup, geomean)
  data.frame(language_family=x$language_family[1], n_records=x$n_records[1], implementation=x$implementation[1],
    workers=x$workers[1], timing_region=x$timing_region[1], repetitions=nrow(x),
    geometric_mean_speedup=geomean(x$within_language_speedup), speedup_ci95_low=ci[1], speedup_ci95_high=ci[2],
    median_speedup=median(x$within_language_speedup), median_efficiency=median(x$parallel_efficiency))
}
sg <- split(speedup_raw, interaction(speedup_raw$language_family, speedup_raw$n_records, speedup_raw$workers,
                                     speedup_raw$timing_region, drop=TRUE))
speedup_summary <- do.call(rbind, lapply(sg, summarize_speedup)); rownames(speedup_summary) <- NULL
write.csv(speedup_summary, file.path(V2_TABLES, "Table_V2_Within_Language_Speedup_Summary.csv"), row.names=FALSE)

# CUDA is an accelerator of the C++ kernel, so its only reference is C++ sequential.
cuda_raw <- raw[raw$implementation == "cpp_cuda", ]
if (nrow(cuda_raw)) {
  cpp_reference <- raw[raw$implementation == "cpp_sequential",
    c("n_records","repetition","timing_region","elapsed_sec")]
  names(cpp_reference)[4] <- "cpp_sequential_elapsed_sec"
  cuda_speedup_raw <- merge(cuda_raw, cpp_reference,
    by=c("n_records","repetition","timing_region"), all.x=TRUE)
  cuda_speedup_raw$cuda_speedup_vs_cpp_sequential <-
    cuda_speedup_raw$cpp_sequential_elapsed_sec / cuda_speedup_raw$elapsed_sec
  write.csv(cuda_speedup_raw, file.path(V2_TABLES, "Table_V2_CUDA_Speedup_Raw.csv"), row.names=FALSE)
  cuda_groups <- split(cuda_speedup_raw, interaction(cuda_speedup_raw$n_records,
    cuda_speedup_raw$timing_region, drop=TRUE))
  cuda_summary <- do.call(rbind, lapply(cuda_groups, function(x) {
    ci <- bootstrap_ci(x$cuda_speedup_vs_cpp_sequential, geomean)
    data.frame(n_records=x$n_records[1], timing_region=x$timing_region[1], repetitions=nrow(x),
      geometric_mean_speedup=geomean(x$cuda_speedup_vs_cpp_sequential),
      speedup_ci95_low=ci[1], speedup_ci95_high=ci[2],
      median_speedup=median(x$cuda_speedup_vs_cpp_sequential),
      iqr_speedup=stats::IQR(x$cuda_speedup_vs_cpp_sequential))
  }))
  rownames(cuda_summary) <- NULL
  write.csv(cuda_summary, file.path(V2_TABLES, "Table_V2_CUDA_Speedup_Summary.csv"), row.names=FALSE)
}

equivalence <- aggregate(cbind(max_abs_pbio_diff,max_abs_rcs_diff) ~ language_family+implementation+workers, raw, max)
equivalence$all_equivalence_checks_passed <- TRUE
write.csv(equivalence, file.path(V2_TABLES, "Table_V2_Equivalence_Check.csv"), row.names=FALSE)
write.csv(summary_table[,c("language_family","n_records","implementation","workers","timing_region","repetitions",
                           "cv_percent","relative_ci_half_width_percent","timing_outlier_count",
                           "precision_passed","smoke_variability_passed","stability_passed")],
          file.path(V2_TABLES, "Table_V2_Measurement_Stability.csv"), row.names=FALSE)
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
compute_stability_gate_passed <- compute_stability_rate >= V2_MIN_STABILITY_RATE
e2e_stability_gate_passed <- e2e_stability_rate >= V2_MIN_STABILITY_RATE
quality_gates <- data.frame(
  protocol_version=V2_PROTOCOL_VERSION,
  run_mode=if (V2_SMOKE) "smoke_diagnostic" else "publication",
  quality_gates_enforced=V2_ENFORCE_QUALITY_GATES,
  equivalence_gate_passed=equivalence_gate_passed,
  calibrated_compute_measurements=sum(compute_rows),
  calibrated_compute_measurements_passing=sum(raw$calibration_floor_passed[compute_rows] %in% TRUE),
  calibration_floor_gate_passed=calibration_gate_passed,
  compute_timing_conditions=sum(compute_stability),
  stable_compute_conditions=sum(summary_table$stability_passed[compute_stability]),
  compute_stability_rate=compute_stability_rate,
  compute_stability_gate_passed=compute_stability_gate_passed,
  end_to_end_timing_conditions=sum(e2e_stability),
  stable_end_to_end_conditions=sum(summary_table$stability_passed[e2e_stability]),
  end_to_end_stability_rate=e2e_stability_rate,
  end_to_end_stability_enforced=V2_ENFORCE_E2E_STABILITY,
  end_to_end_stability_gate_passed=e2e_stability_gate_passed,
  required_stability_rate=V2_MIN_STABILITY_RATE,
  stability_metric=if (V2_SMOKE) paste0("CV <= ",V2_MAX_CV_PERCENT_SMOKE,"% (diagnostic)")
    else paste0("bootstrap median CI relative half-width <= ",V2_MAX_RELATIVE_CI_PERCENT,"%")
)
quality_gates$all_quality_gates_passed <- equivalence_gate_passed && calibration_gate_passed &&
  (!V2_ENFORCE_QUALITY_GATES || (compute_stability_gate_passed &&
    (!V2_ENFORCE_E2E_STABILITY || e2e_stability_gate_passed)))
write.csv(quality_gates, file.path(V2_TABLES, "Table_V2_Quality_Gates.csv"), row.names=FALSE)

publication_theme <- function() {
  ggplot2::theme_minimal(base_size=11) +
    ggplot2::theme(
      panel.grid.minor=ggplot2::element_blank(),
      panel.grid.major=ggplot2::element_line(color="#E2E2E2", linewidth=.35),
      axis.title=ggplot2::element_text(face="bold"),
      plot.title=ggplot2::element_text(face="bold", size=12, margin=ggplot2::margin(b=10)),
      plot.subtitle=ggplot2::element_text(color="#444444", size=9.5),
      legend.position="bottom",
      legend.box="vertical",
      legend.box.just="left",
      legend.title=ggplot2::element_text(face="bold"),
      plot.margin=ggplot2::margin(10,22,10,28)
    )
}

# Remove superseded mixed-language figures so a rerun cannot leave ambiguous
# artifacts beside the language-specific V2 outputs.
obsolete_figure_stems <- c(
  "Figure_6_V2_Sequential_Parallel_Runtime",
  "Figure_S15_V2_Within_Language_Scaling",
  "Figure_S16_V2_CUDA_Acceleration"
)
unlink(unlist(lapply(obsolete_figure_stems, function(x)
  file.path(V2_FIGURES, paste0(x, c(".pdf", ".png"))))), force=TRUE)
unlink(file.path(V2_TABLES, c(
  "Figure_6_V2_Source_Runtime.csv",
  "Figure_S15_V2_Source_Scaling.csv"
)), force=TRUE)

save_language_figure <- function(language_family, sequential_impl, parallel_impl,
                                 sequential_label, parallel_label, worker_noun,
                                 figure_number, figure_stem, figure_title) {
  selected_workers <- sort(unique(c(1L, V2_PRIMARY_WORKERS)))
  runtime <- summary_table[
    summary_table$language_family == language_family &
      (summary_table$implementation == sequential_impl |
       (summary_table$implementation == parallel_impl & summary_table$workers %in% selected_workers)), ]
  runtime$configuration <- ifelse(
    runtime$implementation == sequential_impl,
    sequential_label,
    paste0(parallel_label, " (", runtime$workers, " ",
           ifelse(runtime$workers == 1L, sub("s$", "", worker_noun), worker_noun), ")")
  )
  runtime$configuration <- factor(runtime$configuration, levels=unique(c(
    sequential_label,
    paste0(parallel_label, " (", selected_workers, " ",
           ifelse(selected_workers == 1L, sub("s$", "", worker_noun), worker_noun), ")")
  )))
  runtime_colors <- setNames(c("#333333", "#56B4E9", "#0072B2")[seq_along(levels(runtime$configuration))],
                             levels(runtime$configuration))
  runtime_shapes <- setNames(c(16, 15, 17)[seq_along(levels(runtime$configuration))],
                             levels(runtime$configuration))

  plot_runtime_panel <- function(region, panel_title, show_legend=TRUE) {
    d <- runtime[runtime$timing_region == region, ]
    ggplot2::ggplot(d, ggplot2::aes(n_records, median_elapsed_sec,
      color=configuration, fill=configuration, shape=configuration, group=configuration)) +
      ggplot2::geom_ribbon(ggplot2::aes(ymin=median_ci95_low_sec, ymax=median_ci95_high_sec),
                           alpha=.10, color=NA, show.legend=FALSE) +
      ggplot2::geom_line(linewidth=.85) +
      ggplot2::geom_point(size=2.4, stroke=.3) +
      ggplot2::scale_x_log10(breaks=sort(unique(d$n_records)), labels=scales::label_comma()) +
      ggplot2::scale_y_log10(labels=scales::label_number()) +
      ggplot2::scale_color_manual(values=runtime_colors, drop=FALSE) +
      ggplot2::scale_fill_manual(values=runtime_colors, drop=FALSE) +
      ggplot2::scale_shape_manual(values=runtime_shapes, drop=FALSE) +
      ggplot2::labs(title=panel_title, x="Number of biospecimen profiles",
        y="Median elapsed time (seconds; log scale)",
        color="Execution configuration", fill="Execution configuration",
        shape="Execution configuration") +
      ggplot2::guides(
        color=ggplot2::guide_legend(nrow=2, byrow=TRUE),
        fill=ggplot2::guide_legend(nrow=2, byrow=TRUE),
        shape=ggplot2::guide_legend(nrow=2, byrow=TRUE)
      ) +
      publication_theme() +
      ggplot2::theme(legend.position=if (show_legend) "bottom" else "none")
  }

  speed <- speedup_summary[
    speedup_summary$language_family == language_family &
      speedup_summary$implementation == parallel_impl &
      speedup_summary$timing_region == "compute", ]
  speed$worker_label <- factor(
    paste0(speed$workers, " ", ifelse(speed$workers == 1L, sub("s$", "", worker_noun), worker_noun)),
    levels=paste0(sort(unique(speed$workers)), " ",
      ifelse(sort(unique(speed$workers)) == 1L, sub("s$", "", worker_noun), worker_noun))
  )
  speed_colors <- setNames(grDevices::hcl.colors(length(levels(speed$worker_label)), "Dark 3"),
                           levels(speed$worker_label))
  p_speed <- ggplot2::ggplot(speed, ggplot2::aes(n_records, geometric_mean_speedup,
      color=worker_label, fill=worker_label, group=worker_label)) +
    ggplot2::geom_hline(yintercept=1, linetype=2, color="#666666", linewidth=.55) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin=speedup_ci95_low, ymax=speedup_ci95_high),
                         alpha=.10, color=NA, show.legend=FALSE) +
    ggplot2::geom_line(linewidth=.85) +
    ggplot2::geom_point(size=2.4) +
    ggplot2::scale_x_log10(breaks=sort(unique(speed$n_records)), labels=scales::label_comma()) +
    ggplot2::scale_y_log10(labels=function(x) paste0(scales::label_number()(x), "×")) +
    ggplot2::scale_color_manual(values=speed_colors, drop=FALSE) +
    ggplot2::scale_fill_manual(values=speed_colors, drop=FALSE) +
    ggplot2::labs(
      title="C. Parallel speedup within the same language",
      subtitle=paste0("Paired ratio: ", sequential_label, " time / ", parallel_label,
                      " time. The dashed 1× line denotes no acceleration."),
      x="Number of biospecimen profiles",
      y="Geometric-mean speedup (log scale)",
      color=paste0("Number of ", worker_noun), fill=paste0("Number of ", worker_noun)
    ) + publication_theme()

  combined <- patchwork::plot_spacer() /
    plot_runtime_panel("compute", "A. Steady-state classification", TRUE) /
    plot_runtime_panel("end_to_end", "B. End-to-end execution", FALSE) /
    p_speed +
    patchwork::plot_layout(heights=c(.10, 1, 1, 1.15)) +
    patchwork::plot_annotation(
      title=paste0(figure_number, ". ", figure_title),
      theme=ggplot2::theme(
        plot.title=ggplot2::element_text(face="bold", size=14, margin=ggplot2::margin(b=20)),
        plot.margin=ggplot2::margin(t=16, r=16, b=10, l=16)
      )
    )
  pdf_device <- if (capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf
  ggplot2::ggsave(file.path(V2_FIGURES, paste0(figure_stem, ".pdf")), combined,
    width=10.5, height=12.8, device=pdf_device, bg="white")
  ggplot2::ggsave(file.path(V2_FIGURES, paste0(figure_stem, ".png")), combined,
    width=10.5, height=12.8, dpi=600, bg="white")
  write.csv(runtime, file.path(V2_TABLES, paste0(figure_stem, "_Source_Runtime.csv")), row.names=FALSE)
  write.csv(speed, file.path(V2_TABLES, paste0(figure_stem, "_Source_Speedup.csv")), row.names=FALSE)
}

# Each figure is intentionally restricted to one language family. No cross-language
# runtime or speedup panel is produced by the V2 analysis.
save_language_figure("R", "r_sequential", "r_psock",
  "R sequential (single process)", "R/PSOCK", "workers",
  "Figure 6", "Figure_6_V2_R_Sequential_Parallel_Performance",
  "R classification performance: sequential and PSOCK execution")
if (any(summary_table$language_family == "Python/Cython")) {
  save_language_figure("Python/Cython", "cython_sequential", "cython_openmp",
    "Cython sequential (1 thread)", "Cython/OpenMP", "threads",
    "Figure S15", "Figure_S15_V2_Cython_Sequential_Parallel_Performance",
    "Cython classification performance: sequential and OpenMP execution")
} else {
  warning("Python/Cython rows are absent; Figure S15 was not generated. Run with V2_RUN_PYTHON=TRUE.")
}
save_language_figure("C++", "cpp_sequential", "cpp_openmp",
  "C++ sequential (1 thread)", "C++/OpenMP", "threads",
  "Figure S16", "Figure_S16_V2_CPP_OpenMP_Performance",
  "C++ classification performance: sequential and OpenMP execution")

if (exists("cuda_summary")) {
  cuda_summary$region_label <- factor(cuda_summary$timing_region,
    levels=c("compute","end_to_end"), labels=c("Kernel only","End to end"))
  p_cuda <- ggplot2::ggplot(cuda_summary, ggplot2::aes(n_records, geometric_mean_speedup,
      color=region_label, fill=region_label, group=region_label)) +
    ggplot2::geom_hline(yintercept=1, linetype=2, color="#666666") +
    ggplot2::geom_ribbon(ggplot2::aes(ymin=speedup_ci95_low,ymax=speedup_ci95_high),
                         alpha=.12,color=NA) +
    ggplot2::geom_line(linewidth=.85) + ggplot2::geom_point(size=2.4) +
    ggplot2::scale_x_log10(breaks=sort(unique(cuda_summary$n_records)), labels=scales::label_comma()) +
    ggplot2::scale_y_log10(labels=function(x) paste0(scales::label_number()(x),"×")) +
    ggplot2::scale_color_manual(values=c("Kernel only"="#D55E00","End to end"="#0072B2")) +
    ggplot2::scale_fill_manual(values=c("Kernel only"="#D55E00","End to end"="#0072B2")) +
    ggplot2::labs(title="Figure S17. CUDA acceleration relative to C++ sequential",
      subtitle="CUDA is treated as an accelerator of the C++ kernel; no R or Cython denominator is used.",
      x="Number of biospecimen profiles", y="Paired geometric-mean speedup (log scale)",
      color="Timing region",fill="Timing region") + publication_theme()
  ggplot2::ggsave(file.path(V2_FIGURES,"Figure_S17_V2_CUDA_Acceleration.pdf"),p_cuda,
    width=9,height=5.8,device=if(capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf,bg="white")
  ggplot2::ggsave(file.path(V2_FIGURES,"Figure_S17_V2_CUDA_Acceleration.png"),p_cuda,
    width=9,height=5.8,dpi=600,bg="white")
  write.csv(cuda_summary,file.path(V2_TABLES,"Figure_S17_V2_Source_CUDA.csv"),row.names=FALSE)
}

phase_cols <- c("read_sec","initialization_sec","classification_sec","write_sec","process_overhead_sec")
phase_raw <- raw[raw$timing_region=="end_to_end",c("language_family","n_records","repetition","implementation","workers",phase_cols)]
phase_long <- reshape(phase_raw,varying=phase_cols,v.names="elapsed_sec",timevar="phase",times=phase_cols,direction="long")
phase_summary <- aggregate(elapsed_sec ~ language_family+n_records+implementation+workers+phase,phase_long,median)
phase_summary$share_percent <- ave(phase_summary$elapsed_sec,interaction(phase_summary$language_family,phase_summary$n_records,
  phase_summary$implementation,phase_summary$workers),FUN=function(x) 100*x/sum(x))
write.csv(phase_summary,file.path(V2_TABLES,"Table_V2_End_to_End_Phase_Decomposition.csv"),row.names=FALSE)

cuda_phase_cols <- c("cuda_host_prepare_sec","cuda_device_setup_sec","cuda_h2d_sec","cuda_kernel_sec",
                     "cuda_d2h_sec","cuda_device_teardown_sec","cuda_host_finalize_sec","cuda_disk_write_sec")
cuda_phases <- raw[raw$implementation=="cpp_cuda" & raw$timing_region=="end_to_end",
                   c("n_records","repetition",cuda_phase_cols)]
if (nrow(cuda_phases)) {
  cuda_phase_long <- reshape(cuda_phases,varying=cuda_phase_cols,v.names="elapsed_sec",
    timevar="phase",times=cuda_phase_cols,direction="long")
  cuda_phase_summary <- aggregate(elapsed_sec ~ n_records+phase,cuda_phase_long,median)
  cuda_phase_summary$share_percent <- ave(cuda_phase_summary$elapsed_sec,cuda_phase_summary$n_records,
    FUN=function(x) 100*x/sum(x))
  write.csv(cuda_phase_summary,file.path(V2_TABLES,"Table_V2_CUDA_Phase_Decomposition.csv"),row.names=FALSE)
}

cat("Benchmark V2 tables and figures generated without cross-language speedup comparisons; CUDA uses C++ sequential only.\n")
cat(sprintf("Calibration floor gate: %d/%d compute measurements passed.\n",
  sum(raw$calibration_floor_passed[compute_rows] %in% TRUE), sum(compute_rows)))
cat(sprintf("Compute stability: %d/%d conditions (%.1f%%; target %.1f%%).\n",
  sum(summary_table$stability_passed[compute_stability]), sum(compute_stability),
  100 * compute_stability_rate, 100 * V2_MIN_STABILITY_RATE))
cat(sprintf("End-to-end stability: %d/%d conditions (%.1f%%; %s).\n",
  sum(summary_table$stability_passed[e2e_stability]), sum(e2e_stability),
  100 * e2e_stability_rate,
  if (V2_ENFORCE_E2E_STABILITY) "enforced" else "diagnostic only"))
if (V2_SMOKE && !compute_stability_gate_passed) {
  warning("Smoke-test variability exceeded the diagnostic target. Outputs are valid for pipeline validation only, not inference.")
}
if (V2_ENFORCE_QUALITY_GATES && !quality_gates$all_quality_gates_passed) {
  stop("Benchmark V2 publication quality gate failed. Inspect calibration, stability, outlier, and quality-gate tables before reporting results.")
}
if (!V2_ENFORCE_QUALITY_GATES && !quality_gates$all_quality_gates_passed) {
  stop("Benchmark V2 mandatory equivalence or calibration floor gate failed.")
}
