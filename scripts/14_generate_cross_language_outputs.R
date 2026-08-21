#!/usr/bin/env Rscript

# Single publication figure for the complete computational comparison.
# Speedups are paired by workload and repetition. CUDA uses total device
# elapsed time; kernel-only time remains available in the benchmark tables.

source(file.path("scripts", "01_config_utils.R"))
suppressPackageStartupMessages(library(patchwork))

raw_path <- file.path(
  "outputs", "tables", "Table_Cross_Language_Runtime_Benchmark_Raw.csv"
)
if (!file.exists(raw_path)) {
  stop("Run scripts/13_run_cross_language_benchmark.R first.")
}

raw <- readr::read_csv(raw_path, show_col_types = FALSE, progress = FALSE)
required_columns <- c(
  "n_records", "rep", "implementation", "threads", "elapsed_sec"
)
missing_columns <- setdiff(required_columns, names(raw))
if (length(missing_columns)) {
  stop("Benchmark table is missing: ", paste(missing_columns, collapse = ", "))
}
raw <- raw |>
  dplyr::filter(is.finite(elapsed_sec), elapsed_sec > 0)
if (!nrow(raw)) stop("No positive finite runtime observations were found.")

first_threads <- function(id, fallback) {
  value <- raw |>
    dplyr::filter(implementation == id) |>
    dplyr::summarise(value = dplyr::first(threads)) |>
    dplyr::pull(value)
  if (!length(value) || is.na(value)) as.integer(fallback) else as.integer(value)
}
psock_workers <- first_threads(
  "r_psock", Sys.getenv("RCS_PARALLEL_WORKERS", "4")
)
openmp_threads <- first_threads(
  "cpp_openmp", Sys.getenv("RCS_OPENMP_THREADS", "4")
)

implementation_labels <- c(
  r_sequential = "R sequential",
  r_psock = sprintf("R/PSOCK (%d workers)", psock_workers),
  cpp_sequential = "C++ sequential",
  cpp_openmp = sprintf("C++/OpenMP (%d threads)", openmp_threads),
  cpp_cuda = "C++/CUDA (total)"
)
present_ids <- names(implementation_labels)[
  names(implementation_labels) %in% unique(raw$implementation)
]
implementation_levels <- unname(implementation_labels[present_ids])
raw <- raw |>
  dplyr::mutate(
    mode = factor(
      unname(implementation_labels[implementation]),
      levels = implementation_levels
    )
  ) |>
  dplyr::filter(!is.na(mode))

workloads <- sort(unique(raw$n_records))
format_workload <- function(x) {
  vapply(x, function(value) {
    if (value >= 1e6) {
      millions <- value / 1e6
      digits <- if (abs(millions - round(millions)) < 1e-10) 0 else 1
      return(paste0(
        format(round(millions, digits), nsmall = digits, trim = TRUE), "M"
      ))
    }
    scales::comma(value, accuracy = 1)
  }, character(1))
}
workload_labels <- stats::setNames(
  format_workload(workloads), as.character(workloads)
)
raw <- raw |>
  dplyr::mutate(
    workload = factor(
      as.character(n_records),
      levels = as.character(workloads),
      ordered = TRUE
    )
  )

summarise_ci95 <- function(data, value_column) {
  data |>
    dplyr::summarise(
      repetitions = dplyr::n(),
      mean = mean(.data[[value_column]], na.rm = TRUE),
      sd = if (dplyr::n() > 1L) {
        stats::sd(.data[[value_column]], na.rm = TRUE)
      } else {
        NA_real_
      },
      se = if (dplyr::n() > 1L) sd / sqrt(dplyr::n()) else NA_real_,
      ci95 = if (dplyr::n() > 1L) {
        stats::qt(0.975, df = dplyr::n() - 1L) * se
      } else {
        NA_real_
      },
      ymin = if (is.finite(ci95)) {
        pmax(.Machine$double.eps, mean - ci95)
      } else {
        NA_real_
      },
      ymax = if (is.finite(ci95)) mean + ci95 else NA_real_,
      .groups = "drop"
    )
}

elapsed <- raw |>
  dplyr::group_by(n_records, workload, mode) |>
  summarise_ci95("elapsed_sec")
elapsed_ci <- elapsed |>
  dplyr::filter(is.finite(ymin), is.finite(ymax), ymin > 0, ymax > 0)

wide <- raw |>
  dplyr::select(n_records, workload, rep, implementation, elapsed_sec) |>
  tidyr::pivot_wider(
    names_from = implementation,
    values_from = elapsed_sec,
    values_fn = mean
  )
expected <- c(
  "r_sequential", "r_psock", "cpp_sequential", "cpp_openmp", "cpp_cuda"
)
for (id in expected) {
  if (!id %in% names(wide)) wide[[id]] <- NA_real_
}
if (all(is.na(wide$r_sequential))) {
  stop("R sequential is required as the canonical performance baseline.")
}

# Panel B: total benefit relative to the same R sequential observation.
overall_labels <- c(
  r_psock = "R/PSOCK vs R sequential",
  cpp_sequential = "C++ sequential vs R sequential",
  cpp_openmp = "C++/OpenMP vs R sequential",
  cpp_cuda = "C++/CUDA vs R sequential"
)
overall_raw <- wide |>
  dplyr::transmute(
    n_records, workload, rep,
    r_psock = r_sequential / r_psock,
    cpp_sequential = r_sequential / cpp_sequential,
    cpp_openmp = r_sequential / cpp_openmp,
    cpp_cuda = r_sequential / cpp_cuda
  ) |>
  tidyr::pivot_longer(
    -c(n_records, workload, rep),
    names_to = "comparison_id",
    values_to = "speedup"
  ) |>
  dplyr::filter(is.finite(speedup), speedup > 0) |>
  dplyr::mutate(
    comparison = factor(
      unname(overall_labels[comparison_id]),
      levels = unname(overall_labels)
    )
  )
overall <- overall_raw |>
  dplyr::group_by(n_records, workload, comparison) |>
  summarise_ci95("speedup")
overall_ci <- overall |>
  dplyr::filter(is.finite(ymin), is.finite(ymax), ymin > 0, ymax > 0)

# Panel C: separate parallelization effects from the language effect.
component_labels <- c(
  psock_gain = "PSOCK: R sequential / R PSOCK",
  language_gain = "Language: R sequential / C++ sequential",
  openmp_gain = "OpenMP: C++ sequential / C++ OpenMP",
  cuda_gain = "CUDA: C++ sequential / C++ CUDA"
)
component_raw <- wide |>
  dplyr::transmute(
    n_records, workload, rep,
    psock_gain = r_sequential / r_psock,
    language_gain = r_sequential / cpp_sequential,
    openmp_gain = cpp_sequential / cpp_openmp,
    cuda_gain = cpp_sequential / cpp_cuda
  ) |>
  tidyr::pivot_longer(
    -c(n_records, workload, rep),
    names_to = "component_id",
    values_to = "speedup"
  ) |>
  dplyr::filter(is.finite(speedup), speedup > 0) |>
  dplyr::mutate(
    component = factor(
      unname(component_labels[component_id]),
      levels = unname(component_labels)
    )
  )
components <- component_raw |>
  dplyr::group_by(n_records, workload, component) |>
  summarise_ci95("speedup")
component_ci <- components |>
  dplyr::filter(is.finite(ymin), is.finite(ymax), ymin > 0, ymax > 0)

# Direct optimized-path comparisons remain auditable without overcrowding
# the figure or mixing total and component effects.
direct_labels <- c(
  psock_openmp = "R/PSOCK / C++ OpenMP",
  psock_cuda = "R/PSOCK / C++ CUDA"
)
direct_raw <- wide |>
  dplyr::transmute(
    n_records, workload, rep,
    psock_openmp = r_psock / cpp_openmp,
    psock_cuda = r_psock / cpp_cuda
  ) |>
  tidyr::pivot_longer(
    -c(n_records, workload, rep),
    names_to = "comparison_id",
    values_to = "speedup"
  ) |>
  dplyr::filter(is.finite(speedup), speedup > 0) |>
  dplyr::mutate(comparison = unname(direct_labels[comparison_id]))
direct <- direct_raw |>
  dplyr::group_by(n_records, workload, comparison) |>
  summarise_ci95("speedup")

figure_source_dir <- file.path("outputs", "tables", "figure_source")
supplementary_dir <- file.path("outputs", "tables", "supplementary")
figure_dir <- file.path("outputs", "figures")
dir.create(figure_source_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(supplementary_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

readr::write_csv(
  elapsed,
  file.path(figure_source_dir, "Figure_6_Source_Implementation_Runtime_CI95.csv")
)
readr::write_csv(
  overall_raw,
  file.path(figure_source_dir, "Figure_6_Source_Overall_Speedup_Raw.csv")
)
readr::write_csv(
  overall,
  file.path(figure_source_dir, "Figure_6_Source_Overall_Speedup_CI95.csv")
)
readr::write_csv(
  component_raw,
  file.path(figure_source_dir, "Figure_6_Source_Component_Speedup_Raw.csv")
)
readr::write_csv(
  components,
  file.path(figure_source_dir, "Figure_6_Source_Component_Speedup_CI95.csv")
)
readr::write_csv(
  direct_raw,
  file.path(
    supplementary_dir,
    "Additional_File_S13_Direct_Optimized_Path_Speedups_Raw.csv"
  )
)
readr::write_csv(
  direct,
  file.path(
    supplementary_dir,
    "Additional_File_S14_Direct_Optimized_Path_Speedups_CI95.csv"
  )
)

index_path <- file.path(
  "outputs", "tables", "Figure_And_Supplementary_Output_Index.csv"
)
index_rows <- tibble::tribble(
  ~item, ~file_base, ~type, ~description,
  "Figure 6",
  "Figure_6_Implementation_Performance_Benchmark",
  "main figure",
  "Runtime, overall R-baseline speedup, and decomposed language/parallelization effects.",
  "Additional File S12",
  "Additional_File_S12_R_PSOCK_Runtime_Benchmark.csv",
  "supplementary table",
  "R sequential and persistent PSOCK runtime benchmark.",
  "Additional File S13",
  "Additional_File_S13_Direct_Optimized_Path_Speedups_Raw.csv",
  "supplementary table",
  "Paired raw R/PSOCK-to-OpenMP and R/PSOCK-to-CUDA speedups.",
  "Additional File S14",
  "Additional_File_S14_Direct_Optimized_Path_Speedups_CI95.csv",
  "supplementary table",
  "Summary and 95% confidence intervals for direct optimized-path speedups."
)
if (file.exists(index_path)) {
  output_index <- readr::read_csv(
    index_path, show_col_types = FALSE, progress = FALSE
  ) |>
    dplyr::filter(!item %in% index_rows$item) |>
    dplyr::bind_rows(index_rows)
} else {
  output_index <- index_rows
}
readr::write_csv(output_index, index_path)

implementation_colours <- c(
  "R sequential" = "#595959",
  "R/PSOCK" = "#CC79A7",
  "C++ sequential" = "#009E73",
  "C++/OpenMP" = "#0072B2",
  "C++/CUDA (total)" = "#D55E00"
)
names(implementation_colours)[2] <- sprintf(
  "R/PSOCK (%d workers)", psock_workers
)
names(implementation_colours)[4] <- sprintf(
  "C++/OpenMP (%d threads)", openmp_threads
)
implementation_shapes <- stats::setNames(
  c(16, 17, 15, 3, 18), names(implementation_colours)
)
overall_colours <- c(
  "R/PSOCK vs R sequential" = "#CC79A7",
  "C++ sequential vs R sequential" = "#009E73",
  "C++/OpenMP vs R sequential" = "#0072B2",
  "C++/CUDA vs R sequential" = "#D55E00"
)
overall_shapes <- stats::setNames(c(17, 15, 3, 18), names(overall_colours))
component_colours <- c(
  "PSOCK: R sequential / R PSOCK" = "#CC79A7",
  "Language: R sequential / C++ sequential" = "#009E73",
  "OpenMP: C++ sequential / C++ OpenMP" = "#0072B2",
  "CUDA: C++ sequential / C++ CUDA" = "#D55E00"
)
component_shapes <- stats::setNames(
  c(17, 15, 3, 18), names(component_colours)
)

base_theme <- ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(
      face = "bold", size = 13.5, margin = ggplot2::margin(b = 8)
    ),
    axis.title = ggplot2::element_text(size = 12.5),
    axis.text = ggplot2::element_text(size = 10),
    legend.position = "bottom",
    legend.box = "vertical",
    legend.text = ggplot2::element_text(size = 8.8),
    legend.key.width = grid::unit(1.1, "lines"),
    legend.spacing.x = grid::unit(0.18, "cm"),
    plot.margin = ggplot2::margin(12, 22, 14, 22)
  )

workload_scale <- function() {
  ggplot2::scale_x_discrete(
    labels = workload_labels,
    drop = FALSE,
    expand = ggplot2::expansion(mult = c(0.04, 0.04))
  )
}
speedup_scale <- function() {
  ggplot2::scale_y_log10(
    breaks = scales::breaks_log(n = 6),
    labels = scales::label_number(
      accuracy = 0.1, big.mark = ",", suffix = "\u00d7", trim = TRUE
    )
  )
}

p1 <- ggplot2::ggplot(
  elapsed,
  ggplot2::aes(workload, mean, colour = mode, shape = mode, group = mode)
) +
  ggplot2::geom_point(
    data = raw,
    ggplot2::aes(workload, elapsed_sec, colour = mode, shape = mode),
    inherit.aes = FALSE,
    alpha = 0.22,
    size = 1.7,
    position = ggplot2::position_jitter(width = 0.055, height = 0),
    show.legend = FALSE
  ) +
  ggplot2::geom_errorbar(
    data = elapsed_ci,
    ggplot2::aes(ymin = ymin, ymax = ymax),
    width = 0.12,
    linewidth = 0.55,
    show.legend = FALSE
  ) +
  ggplot2::geom_line(linewidth = 0.9) +
  ggplot2::geom_point(size = 2.8) +
  workload_scale() +
  ggplot2::scale_y_log10(
    breaks = scales::breaks_log(n = 6),
    labels = scales::label_number(accuracy = 0.0001, trim = TRUE)
  ) +
  ggplot2::scale_colour_manual(
    values = implementation_colours, drop = TRUE, name = NULL
  ) +
  ggplot2::scale_shape_manual(
    values = implementation_shapes, drop = TRUE, name = NULL
  ) +
  ggplot2::guides(
    colour = ggplot2::guide_legend(nrow = 2, byrow = TRUE),
    shape = "none"
  ) +
  ggplot2::labs(
    title = "A. Runtime by implementation",
    x = NULL,
    y = "Elapsed time (s; log scale)"
  ) +
  base_theme

p2 <- ggplot2::ggplot(
  overall,
  ggplot2::aes(
    workload, mean, colour = comparison, shape = comparison, group = comparison
  )
) +
  ggplot2::geom_hline(
    yintercept = 1,
    linetype = "dashed",
    colour = "#6F6F6F",
    linewidth = 0.55
  ) +
  ggplot2::geom_point(
    data = overall_raw,
    ggplot2::aes(workload, speedup, colour = comparison, shape = comparison),
    inherit.aes = FALSE,
    alpha = 0.22,
    size = 1.7,
    position = ggplot2::position_jitter(width = 0.055, height = 0),
    show.legend = FALSE
  ) +
  ggplot2::geom_errorbar(
    data = overall_ci,
    ggplot2::aes(ymin = ymin, ymax = ymax),
    width = 0.12,
    linewidth = 0.55,
    show.legend = FALSE
  ) +
  ggplot2::geom_line(linewidth = 0.9) +
  ggplot2::geom_point(size = 2.8) +
  workload_scale() +
  speedup_scale() +
  ggplot2::scale_colour_manual(
    values = overall_colours, drop = TRUE, name = NULL
  ) +
  ggplot2::scale_shape_manual(
    values = overall_shapes, drop = TRUE, name = NULL
  ) +
  ggplot2::guides(
    colour = ggplot2::guide_legend(nrow = 2, byrow = TRUE),
    shape = "none"
  ) +
  ggplot2::labs(
    title = "B. Overall speedup relative to R sequential",
    x = NULL,
    y = "Paired speedup (log scale)"
  ) +
  base_theme

p3 <- ggplot2::ggplot(
  components,
  ggplot2::aes(
    workload, mean, colour = component, shape = component, group = component
  )
) +
  ggplot2::geom_hline(
    yintercept = 1,
    linetype = "dashed",
    colour = "#6F6F6F",
    linewidth = 0.55
  ) +
  ggplot2::geom_point(
    data = component_raw,
    ggplot2::aes(workload, speedup, colour = component, shape = component),
    inherit.aes = FALSE,
    alpha = 0.22,
    size = 1.7,
    position = ggplot2::position_jitter(width = 0.055, height = 0),
    show.legend = FALSE
  ) +
  ggplot2::geom_errorbar(
    data = component_ci,
    ggplot2::aes(ymin = ymin, ymax = ymax),
    width = 0.12,
    linewidth = 0.55,
    show.legend = FALSE
  ) +
  ggplot2::geom_line(linewidth = 0.9) +
  ggplot2::geom_point(size = 2.8) +
  workload_scale() +
  speedup_scale() +
  ggplot2::scale_colour_manual(
    values = component_colours, drop = TRUE, name = NULL
  ) +
  ggplot2::scale_shape_manual(
    values = component_shapes, drop = TRUE, name = NULL
  ) +
  ggplot2::guides(
    colour = ggplot2::guide_legend(nrow = 2, byrow = TRUE),
    shape = "none"
  ) +
  ggplot2::labs(
    title = "C. Decomposition of language and parallelization effects",
    x = "Number of biospecimen profiles",
    y = "Paired speedup (log scale)"
  ) +
  base_theme +
  ggplot2::theme(
    axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = 8))
  )

figure <- p1 / p2 / p3 +
  patchwork::plot_layout(heights = c(1, 1, 1), guides = "keep")
pdf_device <- if (capabilities("cairo")) {
  grDevices::cairo_pdf
} else {
  grDevices::pdf
}
pdf_path <- file.path(
  figure_dir, "Figure_6_Implementation_Performance_Benchmark.pdf"
)
png_path <- file.path(
  figure_dir, "Figure_6_Implementation_Performance_Benchmark.png"
)
ggplot2::ggsave(
  pdf_path,
  figure,
  width = 11.5,
  height = 12,
  units = "in",
  device = pdf_device,
  bg = "white",
  limitsize = FALSE
)
ggplot2::ggsave(
  png_path,
  figure,
  width = 11.5,
  height = 12,
  units = "in",
  dpi = 600,
  bg = "white",
  limitsize = FALSE
)

log_message("Unified implementation-performance Figure 6 generated")
message("Generated: ", pdf_path)
message("Generated: ", png_path)
message(if ("cpp_cuda" %in% unique(raw$implementation)) {
  "CUDA observations detected and included."
} else {
  "CUDA observations not detected; CUDA series were omitted."
})
