#!/usr/bin/env Rscript

# ==========================================================
# 11_generate_parallel_benchmark_outputs.R
# Ribeiro Classification Score (RCS)
#
# Purpose:
#   Generate a publication-ready Figure 6 and manuscript table
#   from the existing full-scale parallel runtime benchmark.
#
# Design choices for journal submission:
#   - No long explanatory text inside the figure.
#   - Error-bar meaning is encoded in legend labels.
#   - Clear axis-title spacing.
#   - Log10 x-axis to avoid label overlap.
#   - 95% confidence intervals shown as vertical error bars.
#   - Main interpretation remains in the manuscript caption/text.
#
# Inputs:
#   outputs/tables/Table_Parallel_Runtime_Benchmark_Raw.csv
#   outputs/tables/Table_Parallel_Runtime_Benchmark_Summary.csv
#   outputs/tables/Table_Parallel_Runtime_Equivalence_Check.csv
#
# Outputs:
#   outputs/figures/Figure_6_Parallel_Runtime_Benchmark.pdf/png
#   outputs/tables/Table_Parallel_Runtime_Benchmark_Manuscript.csv
#   outputs/tables/supplementary/Additional_File_S12_Parallel_Runtime_Benchmark.csv
#   outputs/tables/figure_source/Figure_6_Source_*.csv
# ==========================================================

options(warn = 1, scipen = 999)

required_packages <- c(
  "ggplot2",
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "scales",
  "patchwork"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Missing required packages: ",
    paste(missing_packages, collapse = ", "),
    "\nInstall them before running this script."
  )
}

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(scales)
  library(patchwork)
})

get_project_root <- function() {
  cwd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

  if (dir.exists(file.path(cwd, "outputs", "tables"))) {
    return(cwd)
  }

  if (dir.exists(file.path(cwd, "..", "outputs", "tables"))) {
    return(normalizePath(file.path(cwd, ".."), winslash = "/", mustWork = TRUE))
  }

  env_root <- Sys.getenv("RCS_PROJECT_ROOT")
  if (nzchar(env_root) && dir.exists(file.path(env_root, "outputs", "tables"))) {
    return(normalizePath(env_root, winslash = "/", mustWork = TRUE))
  }

  stop("Could not locate project root. Run from project root or set RCS_PROJECT_ROOT.")
}

project_root <- get_project_root()

table_dir <- file.path(project_root, "outputs", "tables")
figure_dir <- file.path(project_root, "outputs", "figures")
figure_source_dir <- file.path(table_dir, "figure_source")
supplementary_dir <- file.path(table_dir, "supplementary")

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_source_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(supplementary_dir, recursive = TRUE, showWarnings = FALSE)

message("Project root: ", project_root)
message("Table directory: ", table_dir)
message("Figure directory: ", figure_dir)

parse_num <- function(x) {
  if (is.numeric(x)) return(x)

  x_chr <- as.character(x)
  x_chr <- stringr::str_trim(x_chr)

  x_chr <- ifelse(
    stringr::str_detect(x_chr, ",") & !stringr::str_detect(x_chr, "\\."),
    stringr::str_replace_all(x_chr, ",", "."),
    x_chr
  )

  readr::parse_number(x_chr)
}

profile_label <- function(x) {
  dplyr::case_when(
    abs(x) >= 1e6 ~ paste0(format(round(x / 1e6, 1), nsmall = 1), "M"),
    TRUE ~ scales::comma(x)
  )
}

theme_rcs_publication <- function(base_size = 14) {
  ggplot2::theme_minimal(base_size = base_size, base_family = "sans") +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.grid.major = ggplot2::element_line(colour = "#E0E0E0", linewidth = 0.35),
      panel.grid.minor = ggplot2::element_blank(),

      plot.title = ggplot2::element_text(
        colour = "#222222",
        face = "bold",
        size = base_size + 1,
        margin = ggplot2::margin(b = 14)
      ),

      axis.title.x = ggplot2::element_text(
        colour = "#222222",
        size = base_size + 1,
        margin = ggplot2::margin(t = 18)
      ),
      axis.title.y = ggplot2::element_text(
        colour = "#222222",
        size = base_size + 1,
        margin = ggplot2::margin(r = 18)
      ),
      axis.text.x = ggplot2::element_text(
        colour = "#444444",
        size = base_size - 1,
        margin = ggplot2::margin(t = 8)
      ),
      axis.text.y = ggplot2::element_text(
        colour = "#444444",
        size = base_size - 1,
        margin = ggplot2::margin(r = 6)
      ),

      legend.position = "bottom",
      legend.title = ggplot2::element_blank(),
      legend.text = ggplot2::element_text(size = base_size - 1),
      legend.key.width = grid::unit(1.15, "cm"),
      legend.key.height = grid::unit(0.50, "cm"),
      legend.spacing.x = grid::unit(0.35, "cm"),
      legend.margin = ggplot2::margin(t = 10, b = 10),
      legend.box.margin = ggplot2::margin(t = 4, b = 8),

      plot.margin = ggplot2::margin(t = 20, r = 34, b = 24, l = 34)
    )
}

save_figure <- function(plot, filename, width, height) {
  pdf_file <- file.path(figure_dir, paste0(filename, ".pdf"))
  png_file <- file.path(figure_dir, paste0(filename, ".png"))

  pdf_device <- if (capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf

  ggplot2::ggsave(
    filename = pdf_file,
    plot = plot,
    width = width,
    height = height,
    units = "in",
    device = pdf_device,
    bg = "white",
    limitsize = FALSE
  )

  ggplot2::ggsave(
    filename = png_file,
    plot = plot,
    width = width,
    height = height,
    units = "in",
    dpi = 600,
    bg = "white",
    limitsize = FALSE
  )

  message("Saved: ", pdf_file)
  message("Saved: ", png_file)
}

raw_path <- file.path(table_dir, "Table_Parallel_Runtime_Benchmark_Raw.csv")
summary_path <- file.path(table_dir, "Table_Parallel_Runtime_Benchmark_Summary.csv")
equivalence_path <- file.path(table_dir, "Table_Parallel_Runtime_Equivalence_Check.csv")

if (!file.exists(raw_path)) {
  stop("Missing file: ", raw_path, "\nRun scripts/10_parallel_runtime_benchmark.R first.")
}

if (!file.exists(summary_path)) {
  stop("Missing file: ", summary_path, "\nRun scripts/10_parallel_runtime_benchmark.R first.")
}

if (!file.exists(equivalence_path)) {
  stop("Missing file: ", equivalence_path, "\nRun scripts/10_parallel_runtime_benchmark.R first.")
}

raw <- readr::read_csv(raw_path, show_col_types = FALSE, progress = FALSE) |>
  dplyr::mutate(
    n_records = parse_num(n_records),
    rep = parse_num(rep),
    workers = parse_num(workers),
    sequential_elapsed_sec = parse_num(sequential_elapsed_sec),
    parallel_elapsed_sec = parse_num(parallel_elapsed_sec),
    sequential_per_sample_microsec = parse_num(sequential_per_sample_microsec),
    parallel_per_sample_microsec = parse_num(parallel_per_sample_microsec),
    speedup = parse_num(speedup)
  )

summary <- readr::read_csv(summary_path, show_col_types = FALSE, progress = FALSE) |>
  dplyr::mutate(
    n_records = parse_num(n_records),
    workers = parse_num(workers),
    reps = parse_num(reps),
    mean_sequential_sec = parse_num(mean_sequential_sec),
    median_sequential_sec = parse_num(median_sequential_sec),
    mean_parallel_sec = parse_num(mean_parallel_sec),
    median_parallel_sec = parse_num(median_parallel_sec),
    mean_speedup = parse_num(mean_speedup),
    median_speedup = parse_num(median_speedup),
    mean_sequential_per_sample_microsec = parse_num(mean_sequential_per_sample_microsec),
    mean_parallel_per_sample_microsec = parse_num(mean_parallel_per_sample_microsec)
  )

equivalence <- readr::read_csv(equivalence_path, show_col_types = FALSE, progress = FALSE)

# Save source tables for reproducibility.
readr::write_csv(
  raw,
  file.path(figure_source_dir, "Figure_6_Source_Parallel_Runtime_Raw.csv")
)

readr::write_csv(
  summary,
  file.path(figure_source_dir, "Figure_6_Source_Parallel_Runtime_Summary.csv")
)

# Compute mean and 95% confidence intervals from raw repetitions.
elapsed_summary <- raw |>
  dplyr::select(
    n_records,
    rep,
    workers,
    sequential_elapsed_sec,
    parallel_elapsed_sec
  ) |>
  tidyr::pivot_longer(
    cols = c(sequential_elapsed_sec, parallel_elapsed_sec),
    names_to = "execution_mode",
    values_to = "elapsed_seconds"
  ) |>
  dplyr::mutate(
    execution_mode = dplyr::recode(
      execution_mode,
      sequential_elapsed_sec = "Sequential",
      parallel_elapsed_sec = "Parallel"
    ),
    execution_mode = factor(execution_mode, levels = c("Sequential", "Parallel"))
  ) |>
  dplyr::group_by(n_records, execution_mode) |>
  dplyr::summarise(
    mean_elapsed_seconds = mean(elapsed_seconds, na.rm = TRUE),
    sd_elapsed_seconds = stats::sd(elapsed_seconds, na.rm = TRUE),
    n_reps = dplyr::n(),
    se_elapsed_seconds = sd_elapsed_seconds / sqrt(n_reps),
    ci95_elapsed_seconds = stats::qt(0.975, df = pmax(n_reps - 1, 1)) * se_elapsed_seconds,
    ymin = pmax(0, mean_elapsed_seconds - ci95_elapsed_seconds),
    ymax = mean_elapsed_seconds + ci95_elapsed_seconds,
    .groups = "drop"
  ) |>
  dplyr::mutate(
    legend_label = paste0(as.character(execution_mode), " mean ± 95% CI"),
    legend_label = factor(
      legend_label,
      levels = c("Sequential mean ± 95% CI", "Parallel mean ± 95% CI")
    )
  )

speed_summary <- raw |>
  dplyr::group_by(n_records) |>
  dplyr::summarise(
    mean_speedup = mean(speedup, na.rm = TRUE),
    sd_speedup = stats::sd(speedup, na.rm = TRUE),
    n_reps = dplyr::n(),
    se_speedup = sd_speedup / sqrt(n_reps),
    ci95_speedup = stats::qt(0.975, df = pmax(n_reps - 1, 1)) * se_speedup,
    ymin = pmax(0, mean_speedup - ci95_speedup),
    ymax = mean_speedup + ci95_speedup,
    .groups = "drop"
  )

readr::write_csv(
  elapsed_summary,
  file.path(figure_source_dir, "Figure_6_Source_Parallel_Runtime_Elapsed_CI95.csv")
)

readr::write_csv(
  speed_summary,
  file.path(figure_source_dir, "Figure_6_Source_Parallel_Runtime_Speedup_CI95.csv")
)

# Manuscript-ready compact table.
manuscript_table <- summary |>
  dplyr::transmute(
    profiles = n_records,
    workers = workers,
    repetitions = reps,
    mean_sequential_seconds = round(mean_sequential_sec, 4),
    mean_parallel_seconds = round(mean_parallel_sec, 4),
    mean_parallel_speedup = round(mean_speedup, 3),
    mean_parallel_cost_us_per_profile = round(mean_parallel_per_sample_microsec, 4),
    deterministic_equivalence = ifelse(
      all_equivalence_checks_passed,
      "Passed",
      "Failed"
    )
  )

readr::write_csv(
  manuscript_table,
  file.path(table_dir, "Table_Parallel_Runtime_Benchmark_Manuscript.csv")
)

readr::write_csv(
  manuscript_table,
  file.path(supplementary_dir, "Additional_File_S12_Parallel_Runtime_Benchmark.csv")
)

x_breaks <- sort(unique(raw$n_records))

mode_cols <- c(
  "Sequential mean ± 95% CI" = "#595959",
  "Parallel mean ± 95% CI" = "#3B82F6"
)

mode_shapes <- c(
  "Sequential mean ± 95% CI" = 16,
  "Parallel mean ± 95% CI" = 17
)

# Position dodge is intentionally disabled for line plots on a log axis.
# Separate colours/shapes identify execution mode; error bars encode 95% CI.

p6a <- ggplot2::ggplot(
  elapsed_summary,
  ggplot2::aes(
    x = n_records,
    y = mean_elapsed_seconds,
    colour = legend_label,
    shape = legend_label,
    group = legend_label
  )
) +
  ggplot2::geom_errorbar(
    ggplot2::aes(ymin = ymin, ymax = ymax),
    width = 0.035,
    linewidth = 0.80,
    alpha = 0.95
  ) +
  ggplot2::geom_line(
    linewidth = 1.15,
    alpha = 0.95
  ) +
  ggplot2::geom_point(
    size = 3.2,
    alpha = 0.98
  ) +
  ggplot2::scale_x_log10(
    breaks = x_breaks,
    labels = profile_label,
    expand = ggplot2::expansion(mult = c(0.04, 0.08))
  ) +
  ggplot2::scale_y_log10(
    breaks = c(0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50),
    labels = scales::label_number(accuracy = 0.1),
    expand = ggplot2::expansion(mult = c(0.05, 0.10))
  ) +
  ggplot2::scale_colour_manual(
    values = mode_cols,
    breaks = names(mode_cols),
    name = NULL
  ) +
  ggplot2::scale_shape_manual(
    values = mode_shapes,
    breaks = names(mode_shapes),
    name = NULL
  ) +
  ggplot2::labs(
    title = "A. Sequential and parallel elapsed time",
    x = NULL,
    y = "Mean elapsed time (s; log scale)"
  ) +
  theme_rcs_publication(base_size = 14) +
  ggplot2::theme(
    legend.position = "bottom",
    axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 20)),
    axis.text.x = ggplot2::element_text(margin = ggplot2::margin(t = 10)),
    plot.margin = ggplot2::margin(t = 20, r = 34, b = 12, l = 34)
  )

# Panel B uses a single series; the y-axis and legend label describe CI.
p6b <- ggplot2::ggplot(
  speed_summary,
  ggplot2::aes(
    x = n_records,
    y = mean_speedup
  )
) +
  ggplot2::geom_hline(
    yintercept = 1,
    linewidth = 0.75,
    linetype = "dashed",
    colour = "#6F6F6F"
  ) +
  ggplot2::geom_errorbar(
    ggplot2::aes(ymin = ymin, ymax = ymax),
    width = 0.035,
    linewidth = 0.85,
    alpha = 0.95,
    colour = "#3B82F6"
  ) +
  ggplot2::geom_line(
    colour = "#3B82F6",
    linewidth = 1.15,
    alpha = 0.95
  ) +
  ggplot2::geom_point(
    colour = "#3B82F6",
    size = 3.2,
    alpha = 0.98
  ) +
  ggplot2::scale_x_log10(
    breaks = x_breaks,
    labels = profile_label,
    expand = ggplot2::expansion(mult = c(0.04, 0.08))
  ) +
  ggplot2::scale_y_continuous(
    breaks = scales::breaks_pretty(n = 5),
    expand = ggplot2::expansion(mult = c(0.05, 0.10))
  ) +
  ggplot2::labs(
    title = "B. Parallel speedup relative to sequential execution",
    x = "Number of biospecimen profiles",
    y = "Mean paired speedup ± 95% CI"
  ) +
  theme_rcs_publication(base_size = 14) +
  ggplot2::theme(
    legend.position = "none",
    axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = 22)),
    axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 20)),
    axis.text.x = ggplot2::element_text(margin = ggplot2::margin(t = 10)),
    plot.margin = ggplot2::margin(t = 20, r = 34, b = 26, l = 34)
  )

p6 <- p6a / p6b +
  patchwork::plot_layout(heights = c(1.03, 1.00), guides = "collect") &
  ggplot2::theme(
    legend.position = "bottom"
  )

save_figure(
  p6,
  "Figure_6_Parallel_Runtime_Benchmark",
  width = 9.8,
  height = 7.4
)

message("Parallel benchmark outputs completed.")
message("Figure: ", file.path(figure_dir, "Figure_6_Parallel_Runtime_Benchmark.pdf"))
message("Table: ", file.path(table_dir, "Table_Parallel_Runtime_Benchmark_Manuscript.csv"))
