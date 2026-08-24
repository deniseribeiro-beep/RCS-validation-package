#!/usr/bin/env Rscript

source(file.path("benchmark_v2", "config.R"))
required <- c("ggplot2", "patchwork", "scales")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing R packages for V2 outputs: ", paste(missing, collapse = ", "))

raw_path <- file.path(V2_TABLES, "Table_V2_Runtime_Benchmark_Raw.csv")
if (!file.exists(raw_path)) stop("Run benchmark_v2/02_run_benchmark.R first.")
raw <- read.csv(raw_path, stringsAsFactors = FALSE)
if (!nrow(raw) || any(!raw$equivalence_passed) || any(!is.finite(raw$elapsed_sec)) || any(raw$elapsed_sec <= 0))
  stop("Raw V2 results are incomplete, invalid, or failed equivalence.")

set.seed(V2_ORDER_SEED + 1L)
bootstrap_ci <- function(x, statistic, reps = V2_BOOT_REPS) {
  x <- x[is.finite(x) & x > 0]
  if (length(x) == 1L) return(c(x, x))
  values <- replicate(reps, statistic(sample(x, length(x), replace = TRUE)))
  unname(stats::quantile(values, c(0.025, 0.975), na.rm = TRUE, type = 8))
}
geomean <- function(x) exp(mean(log(x)))

summarize_group <- function(x) {
  median_ci <- bootstrap_ci(x$elapsed_sec, median)
  geom_ci <- bootstrap_ci(x$elapsed_sec, geomean)
  data.frame(protocol_version = V2_PROTOCOL_VERSION, n_records = x$n_records[1],
    implementation = x$implementation[1], workers = x$workers[1], timing_region = x$timing_region[1],
    repetitions = nrow(x), median_elapsed_sec = median(x$elapsed_sec),
    median_ci95_low_sec = median_ci[1], median_ci95_high_sec = median_ci[2],
    geometric_mean_elapsed_sec = geomean(x$elapsed_sec),
    geometric_ci95_low_sec = geom_ci[1], geometric_ci95_high_sec = geom_ci[2],
    mean_elapsed_sec = mean(x$elapsed_sec), sd_elapsed_sec = stats::sd(x$elapsed_sec),
    iqr_elapsed_sec = stats::IQR(x$elapsed_sec), cv_percent = stats::sd(x$elapsed_sec) / mean(x$elapsed_sec) * 100,
    median_throughput_profiles_sec = median(x$throughput_profiles_sec),
    relative_ci_half_width_percent = (median_ci[2] - median_ci[1]) / (2 * median(x$elapsed_sec)) * 100,
    stability_passed = (median_ci[2] - median_ci[1]) / (2 * median(x$elapsed_sec)) <= 0.10,
    stringsAsFactors = FALSE)
}
groups <- split(raw, interaction(raw$n_records, raw$implementation, raw$workers, raw$timing_region, drop = TRUE))
summary_table <- do.call(rbind, lapply(groups, summarize_group)); rownames(summary_table) <- NULL
write.csv(summary_table, file.path(V2_TABLES, "Table_V2_Runtime_Benchmark_Summary.csv"), row.names = FALSE)

reference <- raw[raw$implementation == "r_sequential", c("n_records", "repetition", "timing_region", "elapsed_sec")]
names(reference)[4] <- "reference_elapsed_sec"
speedup_raw <- merge(raw[raw$implementation != "r_sequential", ], reference,
                     by = c("n_records", "repetition", "timing_region"), all.x = TRUE)
speedup_raw$speedup_vs_r_sequential <- speedup_raw$reference_elapsed_sec / speedup_raw$elapsed_sec
write.csv(speedup_raw, file.path(V2_TABLES, "Table_V2_Speedup_Raw.csv"), row.names = FALSE)

summarize_speedup <- function(x) {
  ci <- bootstrap_ci(x$speedup_vs_r_sequential, geomean)
  data.frame(n_records = x$n_records[1], implementation = x$implementation[1], workers = x$workers[1],
    timing_region = x$timing_region[1], repetitions = nrow(x),
    geometric_mean_speedup = geomean(x$speedup_vs_r_sequential),
    speedup_ci95_low = ci[1], speedup_ci95_high = ci[2],
    median_speedup = median(x$speedup_vs_r_sequential), iqr_speedup = stats::IQR(x$speedup_vs_r_sequential),
    stringsAsFactors = FALSE)
}
speed_groups <- split(speedup_raw, interaction(speedup_raw$n_records, speedup_raw$implementation,
                                               speedup_raw$workers, speedup_raw$timing_region, drop = TRUE))
speedup_summary <- do.call(rbind, lapply(speed_groups, summarize_speedup)); rownames(speedup_summary) <- NULL
write.csv(speedup_summary, file.path(V2_TABLES, "Table_V2_Speedup_Summary.csv"), row.names = FALSE)

equivalence <- aggregate(cbind(max_abs_pbio_diff, max_abs_rcs_diff) ~ implementation + workers,
                         raw, max)
equivalence_counts <- aggregate(repetition ~ implementation + workers, raw, length)
names(equivalence_counts)[3] <- "benchmark_rows"
equivalence <- merge(equivalence, equivalence_counts, by = c("implementation", "workers"), all.x = TRUE)
equivalence$all_equivalence_checks_passed <- TRUE
equivalence$all_final_grades_identical <- TRUE
equivalence$all_grade_routes_identical <- TRUE
write.csv(equivalence, file.path(V2_TABLES, "Table_V2_Equivalence_Check.csv"), row.names = FALSE)

stability <- summary_table[, c("n_records", "implementation", "workers", "timing_region", "repetitions",
                               "cv_percent", "relative_ci_half_width_percent", "stability_passed")]
write.csv(stability, file.path(V2_TABLES, "Table_V2_Measurement_Stability.csv"), row.names = FALSE)

labels <- c(r_sequential = "R sequential", r_psock = "R/PSOCK", python_numpy = "Python/NumPy",
            python_process = "Python/process pool", cpp_sequential = "C++ sequential",
            cpp_openmp = "C++/OpenMP", cpp_cuda = "C++/CUDA")
palette <- c(r_sequential = "#000000", r_psock = "#CC79A7", python_numpy = "#E69F00",
             python_process = "#F0E442", cpp_sequential = "#009E73", cpp_openmp = "#0072B2", cpp_cuda = "#D55E00")
shapes <- c(r_sequential = 16, r_psock = 17, python_numpy = 15, python_process = 18,
            cpp_sequential = 3, cpp_openmp = 8, cpp_cuda = 7)
primary <- function(df) df[(df$implementation %in% c("r_sequential", "python_numpy", "cpp_sequential", "cpp_cuda")) |
                            (df$implementation %in% c("r_psock", "python_process", "cpp_openmp") & df$workers == V2_PRIMARY_WORKERS), ]
plot_time <- function(region, title, y_title) {
  data <- primary(summary_table[summary_table$timing_region == region, ])
  data$label <- unname(labels[data$implementation])
  ggplot2::ggplot(data, ggplot2::aes(n_records, median_elapsed_sec, color = implementation,
                                     shape = implementation, group = implementation)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = median_ci95_low_sec, ymax = median_ci95_high_sec,
                                     fill = implementation), alpha = 0.10, color = NA, show.legend = FALSE) +
    ggplot2::geom_line(linewidth = 0.75) + ggplot2::geom_point(size = 2.4) +
    ggplot2::scale_x_log10(breaks = sort(unique(data$n_records)), labels = scales::label_comma()) +
    ggplot2::scale_y_log10(labels = scales::label_number()) +
    ggplot2::scale_color_manual(values = palette, labels = labels) +
    ggplot2::scale_fill_manual(values = palette) + ggplot2::scale_shape_manual(values = shapes, labels = labels) +
    ggplot2::labs(title = title, x = NULL, y = y_title, color = NULL, shape = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom", legend.box = "vertical", panel.grid.minor = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = "bold"), plot.margin = ggplot2::margin(8, 12, 8, 12)) +
    ggplot2::guides(color = ggplot2::guide_legend(nrow = 2, byrow = TRUE),
                    shape = ggplot2::guide_legend(nrow = 2, byrow = TRUE))
}
p_a <- plot_time("compute", "A. Steady-state compute time", "Median compute time (s; log scale)")
p_b <- plot_time("end_to_end", "B. Cold end-to-end time", "Median end-to-end time (s; log scale)")

speed_data <- primary(speedup_summary[speedup_summary$timing_region == "end_to_end", ])
speed_data <- speed_data[speed_data$implementation != "r_sequential", ]
p_c <- ggplot2::ggplot(speed_data, ggplot2::aes(n_records, geometric_mean_speedup, color = implementation,
                                                shape = implementation, group = implementation)) +
  ggplot2::geom_hline(yintercept = 1, linetype = 2, color = "#666666") +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = speedup_ci95_low, ymax = speedup_ci95_high, fill = implementation),
                       alpha = 0.10, color = NA, show.legend = FALSE) +
  ggplot2::geom_line(linewidth = 0.75) + ggplot2::geom_point(size = 2.4) +
  ggplot2::scale_x_log10(breaks = sort(unique(speed_data$n_records)), labels = scales::label_comma()) +
  ggplot2::scale_y_log10(labels = function(x) paste0(scales::label_number()(x), "×")) +
  ggplot2::scale_color_manual(values = palette, labels = labels) + ggplot2::scale_fill_manual(values = palette) +
  ggplot2::scale_shape_manual(values = shapes, labels = labels) +
  ggplot2::labs(title = "C. Cold end-to-end speedup relative to R sequential", x = "Number of biospecimen profiles",
                y = "Paired geometric-mean speedup (log scale)", color = NULL, shape = NULL) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(legend.position = "bottom", panel.grid.minor = ggplot2::element_blank(),
                 plot.title = ggplot2::element_text(face = "bold"), plot.margin = ggplot2::margin(8, 12, 8, 12)) +
  ggplot2::guides(color = ggplot2::guide_legend(nrow = 2, byrow = TRUE),
                  shape = ggplot2::guide_legend(nrow = 2, byrow = TRUE))

figure <- p_a / p_b / p_c + patchwork::plot_layout(guides = "collect", heights = c(1, 1, 1.08)) &
  ggplot2::theme(legend.position = "bottom")
ggplot2::ggsave(file.path(V2_FIGURES, "Figure_6_V2_Implementation_Performance_Benchmark.pdf"), figure,
                width = 10.5, height = 12.5, device = if (capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf, bg = "white")
ggplot2::ggsave(file.path(V2_FIGURES, "Figure_6_V2_Implementation_Performance_Benchmark.png"), figure,
                width = 10.5, height = 12.5, dpi = 600, bg = "white")
write.csv(primary(summary_table), file.path(V2_TABLES, "Figure_6_V2_Source_Runtime.csv"), row.names = FALSE)
write.csv(speed_data, file.path(V2_TABLES, "Figure_6_V2_Source_Speedup.csv"), row.names = FALSE)

parallel_raw <- raw[raw$timing_region == "compute" & raw$implementation %in% c("r_psock", "python_process", "cpp_openmp"), ]
base_parallel <- parallel_raw[parallel_raw$workers == 1L, c("n_records", "repetition", "implementation", "elapsed_sec")]
names(base_parallel)[4] <- "one_worker_sec"
parallel_raw <- merge(parallel_raw, base_parallel, by = c("n_records", "repetition", "implementation"), all.x = TRUE)
parallel_raw$strong_scaling_speedup <- parallel_raw$one_worker_sec / parallel_raw$elapsed_sec
parallel_raw$parallel_efficiency <- parallel_raw$strong_scaling_speedup / parallel_raw$workers
scale_groups <- split(parallel_raw, interaction(parallel_raw$n_records, parallel_raw$implementation, parallel_raw$workers, drop = TRUE))
scaling <- do.call(rbind, lapply(scale_groups, function(x) data.frame(n_records = x$n_records[1], implementation = x$implementation[1],
  workers = x$workers[1], median_speedup = median(x$strong_scaling_speedup),
  median_efficiency = median(x$parallel_efficiency))))
write.csv(scaling, file.path(V2_TABLES, "Table_V2_Parallel_Scaling.csv"), row.names = FALSE)

scaling$workload <- paste0(scales::label_comma()(scaling$n_records), " profiles")
p_scaling <- ggplot2::ggplot(scaling, ggplot2::aes(workers, median_speedup, color = implementation,
                                                  shape = implementation, group = interaction(implementation, workload))) +
  ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2, color = "#777777") +
  ggplot2::geom_line() + ggplot2::geom_point(size = 2.2) + ggplot2::facet_wrap(~workload) +
  ggplot2::scale_color_manual(values = palette, labels = labels) + ggplot2::scale_shape_manual(values = shapes, labels = labels) +
  ggplot2::scale_x_continuous(breaks = sort(unique(scaling$workers))) +
  ggplot2::labs(title = "Strong scaling within each parallel implementation", x = "Workers or OpenMP threads",
                y = "Speedup relative to one worker/thread", color = NULL, shape = NULL) +
  ggplot2::theme_minimal(base_size = 11) + ggplot2::theme(legend.position = "bottom", panel.grid.minor = ggplot2::element_blank(),
                                                         plot.title = ggplot2::element_text(face = "bold"))
ggplot2::ggsave(file.path(V2_FIGURES, "Figure_S15_V2_Parallel_Strong_Scaling.pdf"), p_scaling,
                width = 10.5, height = 6.8, device = if (capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf, bg = "white")
ggplot2::ggsave(file.path(V2_FIGURES, "Figure_S15_V2_Parallel_Strong_Scaling.png"), p_scaling,
                width = 10.5, height = 6.8, dpi = 600, bg = "white")

cat("Benchmark V2 tables and figures generated successfully.\n")
