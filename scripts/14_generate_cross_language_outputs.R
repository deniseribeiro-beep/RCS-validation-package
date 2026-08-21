#!/usr/bin/env Rscript

# ==============================================================================
# Figure 7 — Cross-language and heterogeneous-computing runtime benchmark
#
# Panel A:
#   End-to-end elapsed time for:
#     - R sequential
#     - R/PSOCK
#     - C++ sequential
#     - C++/OpenMP
#     - C++/CUDA, when available
#
# Panel B:
#   Paired implementation-specific speedups.
#
# CUDA end-to-end elapsed time is the primary comparison. Kernel-only timing,
# when available, remains preserved in the raw and summary benchmark tables.
#
# Important:
#   - Only implementations actually present in the raw benchmark are plotted.
#   - CUDA appears automatically when RUN_CUDA_BENCH=TRUE successfully produces
#     cpp_cuda rows.
#   - Confidence intervals are plotted only when at least two repetitions exist.
#   - Workloads use equal visual spacing to avoid compressed local smoke tests.
# ==============================================================================

source(file.path("scripts", "01_config_utils.R"))

required_packages <- c(
  "ggplot2",
  "dplyr",
  "tidyr",
  "readr",
  "scales",
  "patchwork"
)

missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    logical(1),
    quietly = TRUE
  )
]

if (length(missing_packages) > 0L) {
  stop(
    "Missing packages: ",
    paste(missing_packages, collapse = ", ")
  )
}

# ------------------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------------------

raw_path <- file.path(
  "outputs",
  "tables",
  "Table_Cross_Language_Runtime_Benchmark_Raw.csv"
)

figure_source_dir <- file.path(
  "outputs",
  "tables",
  "figure_source"
)

figure_dir <- file.path(
  "outputs",
  "figures"
)

if (!file.exists(raw_path)) {
  stop(
    "Cross-language raw benchmark table not found: ",
    raw_path,
    "\nRun scripts/13_run_cross_language_benchmark.R first."
  )
}

dir.create(
  figure_source_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  figure_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# ------------------------------------------------------------------------------
# Read and validate raw benchmark
# ------------------------------------------------------------------------------

raw <- readr::read_csv(
  raw_path,
  show_col_types = FALSE
)

required_columns <- c(
  "n_records",
  "rep",
  "implementation",
  "elapsed_sec"
)

missing_columns <- setdiff(required_columns, names(raw))

if (length(missing_columns) > 0L) {
  stop(
    "The cross-language benchmark table is missing required columns: ",
    paste(missing_columns, collapse = ", ")
  )
}

raw <- raw |>
  dplyr::mutate(
    n_records = as.numeric(n_records),
    rep = as.integer(rep),
    implementation = as.character(implementation),
    elapsed_sec = as.numeric(elapsed_sec)
  ) |>
  dplyr::filter(
    is.finite(n_records),
    n_records > 0,
    is.finite(elapsed_sec),
    elapsed_sec > 0,
    !is.na(implementation)
  )

if (nrow(raw) == 0L) {
  stop("The cross-language benchmark table contains no valid observations.")
}

# ------------------------------------------------------------------------------
# Detect worker and thread counts
# ------------------------------------------------------------------------------

read_positive_integer <- function(name, default) {
  value <- suppressWarnings(
    as.integer(Sys.getenv(name, unset = as.character(default)))
  )

  if (!is.finite(value) || value < 1L) {
    return(as.integer(default))
  }

  value
}

detect_thread_count <- function(
  data,
  implementation_name,
  environment_variable,
  default
) {
  if ("threads" %in% names(data)) {
    values <- suppressWarnings(
      as.integer(
        data$threads[
          data$implementation == implementation_name
        ]
      )
    )

    values <- unique(
      values[
        is.finite(values) &
          values > 0L
      ]
    )

    if (length(values) > 0L) {
      return(as.integer(values[[1]]))
    }
  }

  read_positive_integer(environment_variable, default)
}

psock_workers <- detect_thread_count(
  data = raw,
  implementation_name = "r_psock",
  environment_variable = "RCS_PARALLEL_WORKERS",
  default = 4L
)

openmp_threads <- detect_thread_count(
  data = raw,
  implementation_name = "cpp_openmp",
  environment_variable = "RCS_OPENMP_THREADS",
  default = 4L
)

# ------------------------------------------------------------------------------
# Dynamic implementation labels
# ------------------------------------------------------------------------------

all_implementation_labels <- c(
  r_sequential = "R sequential",
  r_psock = sprintf(
    "R/PSOCK (%d workers)",
    psock_workers
  ),
  cpp_sequential = "C++ sequential",
  cpp_openmp = sprintf(
    "C++/OpenMP (%d threads)",
    openmp_threads
  ),
  cpp_cuda = "C++/CUDA (total)"
)

present_implementations <- names(all_implementation_labels)[
  names(all_implementation_labels) %in%
    unique(raw$implementation)
]

if (length(present_implementations) == 0L) {
  stop("No recognized benchmark implementations were found.")
}

implementation_labels <- all_implementation_labels[
  present_implementations
]

implementation_levels <- unname(implementation_labels)

raw <- raw |>
  dplyr::mutate(
    mode = factor(
      unname(
        implementation_labels[implementation]
      ),
      levels = implementation_levels
    )
  ) |>
  dplyr::filter(!is.na(mode))

if (nrow(raw) == 0L) {
  stop("No recognized implementation rows remain after validation.")
}

# ------------------------------------------------------------------------------
# Workload labels
#
# Workloads are represented as an ordered factor. This gives equal visual
# spacing and prevents the smoke-test workloads from being compressed at the
# left side of the figure.
# ------------------------------------------------------------------------------

workloads <- sort(unique(raw$n_records))

format_workload <- function(x) {
  vapply(
    x,
    function(value) {
      if (value >= 1e6) {
        millions <- value / 1e6

        if (abs(millions - round(millions)) < 1e-10) {
          return(
            paste0(
              format(
                round(millions),
                trim = TRUE,
                scientific = FALSE
              ),
              "M"
            )
          )
        }

        return(
          paste0(
            format(
              millions,
              trim = TRUE,
              scientific = FALSE,
              nsmall = 1
            ),
            "M"
          )
        )
      }

      scales::comma(value, accuracy = 1)
    },
    character(1)
  )
}

workload_labels <- stats::setNames(
  format_workload(workloads),
  as.character(workloads)
)

raw <- raw |>
  dplyr::mutate(
    workload = factor(
      as.character(n_records),
      levels = as.character(workloads),
      ordered = TRUE
    )
  )

# ------------------------------------------------------------------------------
# Helper for mean, standard deviation and 95% confidence interval
#
# BENCH_REPS=1 produces no variance estimate. In that case, sd, se, ci95,
# ymin and ymax remain NA and no misleading confidence interval is plotted.
# ------------------------------------------------------------------------------

summarise_ci95 <- function(data, value_column) {
  data |>
    dplyr::summarise(
      repetitions = dplyr::n(),
      mean = mean(
        .data[[value_column]],
        na.rm = TRUE
      ),
      sd = if (dplyr::n() > 1L) {
        stats::sd(
          .data[[value_column]],
          na.rm = TRUE
        )
      } else {
        NA_real_
      },
      se = if (repetitions > 1L) {
        sd / sqrt(repetitions)
      } else {
        NA_real_
      },
      ci95 = if (repetitions > 1L) {
        stats::qt(
          0.975,
          df = repetitions - 1L
        ) * se
      } else {
        NA_real_
      },
      ymin = if (is.finite(ci95)) {
        pmax(
          .Machine$double.eps,
          mean - ci95
        )
      } else {
        NA_real_
      },
      ymax = if (is.finite(ci95)) {
        mean + ci95
      } else {
        NA_real_
      },
      .groups = "drop"
    )
}

# ------------------------------------------------------------------------------
# Panel A source: elapsed time by implementation
# ------------------------------------------------------------------------------

elapsed <- raw |>
  dplyr::group_by(
    n_records,
    workload,
    mode
  ) |>
  summarise_ci95("elapsed_sec")

elapsed_ci <- elapsed |>
  dplyr::filter(
    is.finite(ymin),
    is.finite(ymax),
    ymin > 0,
    ymax > 0
  )

# ------------------------------------------------------------------------------
# Paired benchmark data
# ------------------------------------------------------------------------------

wide <- raw |>
  dplyr::select(
    n_records,
    workload,
    rep,
    implementation,
    elapsed_sec
  ) |>
  tidyr::pivot_wider(
    names_from = implementation,
    values_from = elapsed_sec,
    values_fn = mean
  )

# Add absent implementations as NA so that local execution without CUDA remains
# valid. CUDA comparisons will automatically appear on the GCP when cpp_cuda
# observations are present.
expected_implementations <- c(
  "r_sequential",
  "r_psock",
  "cpp_sequential",
  "cpp_openmp",
  "cpp_cuda"
)

for (implementation_name in expected_implementations) {
  if (!implementation_name %in% names(wide)) {
    wide[[implementation_name]] <- NA_real_
  }
}

paired <- wide |>
  dplyr::mutate(
    language_gain =
      r_sequential / cpp_sequential,

    openmp_gain =
      cpp_sequential / cpp_openmp,

    gpu_gain =
      cpp_sequential / cpp_cuda,

    psock_openmp_gain =
      r_psock / cpp_openmp,

    psock_gpu_gain =
      r_psock / cpp_cuda
  ) |>
  dplyr::select(
    n_records,
    workload,
    rep,
    language_gain,
    openmp_gain,
    gpu_gain,
    psock_openmp_gain,
    psock_gpu_gain
  ) |>
  tidyr::pivot_longer(
    cols = -c(
      n_records,
      workload,
      rep
    ),
    names_to = "comparison_id",
    values_to = "speedup"
  ) |>
  dplyr::filter(
    is.finite(speedup),
    speedup > 0
  )

all_comparison_labels <- c(
  language_gain =
    "R sequential / C++ sequential",

  openmp_gain =
    "C++ sequential / C++ OpenMP",

  gpu_gain =
    "C++ sequential / C++ CUDA",

  psock_openmp_gain =
    "R/PSOCK / C++ OpenMP",

  psock_gpu_gain =
    "R/PSOCK / C++ CUDA"
)

present_comparisons <- names(all_comparison_labels)[
  names(all_comparison_labels) %in%
    unique(paired$comparison_id)
]

if (length(present_comparisons) == 0L) {
  stop(
    "No valid paired speedup comparisons could be calculated. ",
    "Check whether the implementations used the same workloads and repetitions."
  )
}

comparison_labels <- all_comparison_labels[
  present_comparisons
]

comparison_levels <- unname(comparison_labels)

paired <- paired |>
  dplyr::mutate(
    comparison = factor(
      unname(
        comparison_labels[comparison_id]
      ),
      levels = comparison_levels
    )
  )

# ------------------------------------------------------------------------------
# Panel B source: paired speedups
# ------------------------------------------------------------------------------

speed <- paired |>
  dplyr::group_by(
    n_records,
    workload,
    comparison
  ) |>
  summarise_ci95("speedup")

speed_ci <- speed |>
  dplyr::filter(
    is.finite(ymin),
    is.finite(ymax),
    ymin > 0,
    ymax > 0
  )

# ------------------------------------------------------------------------------
# Figure source tables
# ------------------------------------------------------------------------------

readr::write_csv(
  elapsed,
  file.path(
    figure_source_dir,
    "Figure_7_Source_Cross_Language_Elapsed_CI95.csv"
  )
)

readr::write_csv(
  speed,
  file.path(
    figure_source_dir,
    "Figure_7_Source_Cross_Language_Paired_Speedup_CI95.csv"
  )
)

readr::write_csv(
  paired,
  file.path(
    figure_source_dir,
    "Figure_7_Source_Cross_Language_Paired_Speedup_Raw.csv"
  )
)

# ------------------------------------------------------------------------------
# Colour and shape scales
# ------------------------------------------------------------------------------

all_implementation_colours <- c(
  "R sequential" = "#595959",
  "R/PSOCK" = "#CC79A7",
  "C++ sequential" = "#009E73",
  "C++/OpenMP" = "#0072B2",
  "C++/CUDA (total)" = "#D55E00"
)

names(all_implementation_colours)[2] <- sprintf(
  "R/PSOCK (%d workers)",
  psock_workers
)

names(all_implementation_colours)[4] <- sprintf(
  "C++/OpenMP (%d threads)",
  openmp_threads
)

all_implementation_shapes <- c(
  "R sequential" = 16,
  "R/PSOCK" = 17,
  "C++ sequential" = 15,
  "C++/OpenMP" = 3,
  "C++/CUDA (total)" = 18
)

names(all_implementation_shapes)[2] <- sprintf(
  "R/PSOCK (%d workers)",
  psock_workers
)

names(all_implementation_shapes)[4] <- sprintf(
  "C++/OpenMP (%d threads)",
  openmp_threads
)

implementation_colours <- all_implementation_colours[
  implementation_levels
]

implementation_shapes <- all_implementation_shapes[
  implementation_levels
]

all_speedup_colours <- c(
  "R sequential / C++ sequential" = "#009E73",
  "C++ sequential / C++ OpenMP" = "#D55E00",
  "C++ sequential / C++ CUDA" = "#E69F00",
  "R/PSOCK / C++ OpenMP" = "#0072B2",
  "R/PSOCK / C++ CUDA" = "#CC79A7"
)

all_speedup_shapes <- c(
  "R sequential / C++ sequential" = 17,
  "C++ sequential / C++ OpenMP" = 16,
  "C++ sequential / C++ CUDA" = 18,
  "R/PSOCK / C++ OpenMP" = 15,
  "R/PSOCK / C++ CUDA" = 8
)

speedup_colours <- all_speedup_colours[
  comparison_levels
]

speedup_shapes <- all_speedup_shapes[
  comparison_levels
]

# ------------------------------------------------------------------------------
# Shared publication theme
# ------------------------------------------------------------------------------

base_theme <- ggplot2::theme_minimal(base_size = 13) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),

    panel.grid.major.x = ggplot2::element_blank(),

    legend.position = "bottom",

    legend.box = "vertical",

    legend.justification = "center",

    legend.text = ggplot2::element_text(
      size = 9.2
    ),

    legend.key.width = grid::unit(
      1.35,
      "lines"
    ),

    legend.spacing.x = grid::unit(
      0.25,
      "cm"
    ),

    plot.title = ggplot2::element_text(
      face = "bold",
      size = 14,
      margin = ggplot2::margin(
        b = 10
      )
    ),

    axis.title = ggplot2::element_text(
      size = 13
    ),

    axis.text.x = ggplot2::element_text(
      size = 10,
      margin = ggplot2::margin(
        t = 5
      )
    ),

    axis.text.y = ggplot2::element_text(
      size = 10
    ),

    plot.margin = ggplot2::margin(
      t = 14,
      r = 20,
      b = 18,
      l = 20
    )
  )

# ------------------------------------------------------------------------------
# Panel A — elapsed runtime
# ------------------------------------------------------------------------------

p1 <- ggplot2::ggplot(
  elapsed,
  ggplot2::aes(
    x = workload,
    y = mean,
    colour = mode,
    shape = mode,
    group = mode
  )
) +
  ggplot2::geom_errorbar(
    data = elapsed_ci,
    ggplot2::aes(
      ymin = ymin,
      ymax = ymax
    ),
    width = 0.12,
    linewidth = 0.55,
    show.legend = FALSE
  ) +
  ggplot2::geom_line(
    linewidth = 0.9
  ) +
  ggplot2::geom_point(
    size = 2.9
  ) +
  ggplot2::scale_x_discrete(
    labels = workload_labels,
    drop = FALSE,
    expand = ggplot2::expansion(
      mult = c(0.04, 0.04)
    )
  ) +
  ggplot2::scale_y_log10(
    breaks = scales::breaks_log(n = 6),
    labels = scales::label_number(
      accuracy = 0.0001,
      trim = TRUE
    )
  ) +
  ggplot2::scale_colour_manual(
    values = implementation_colours,
    breaks = implementation_levels,
    limits = implementation_levels,
    drop = TRUE,
    name = NULL
  ) +
  ggplot2::scale_shape_manual(
    values = implementation_shapes,
    breaks = implementation_levels,
    limits = implementation_levels,
    drop = TRUE,
    name = NULL
  ) +
  ggplot2::guides(
    colour = ggplot2::guide_legend(
      nrow = 2,
      byrow = TRUE,
      override.aes = list(
        linewidth = 0.9,
        size = 2.9
      )
    ),
    shape = "none"
  ) +
  ggplot2::labs(
    title =
      "A. Cross-language and heterogeneous-computing runtime",

    x = NULL,

    y =
      "Mean elapsed time (s; log scale)"
  ) +
  base_theme

# ------------------------------------------------------------------------------
# Panel B — paired speedup
# ------------------------------------------------------------------------------

p2 <- ggplot2::ggplot(
  speed,
  ggplot2::aes(
    x = workload,
    y = mean,
    colour = comparison,
    shape = comparison,
    group = comparison
  )
) +
  ggplot2::geom_hline(
    yintercept = 1,
    linetype = "dashed",
    colour = "#6F6F6F",
    linewidth = 0.55
  ) +
  ggplot2::geom_errorbar(
    data = speed_ci,
    ggplot2::aes(
      ymin = ymin,
      ymax = ymax
    ),
    width = 0.12,
    linewidth = 0.55,
    show.legend = FALSE
  ) +
  ggplot2::geom_line(
    linewidth = 0.9
  ) +
  ggplot2::geom_point(
    size = 2.9
  ) +
  ggplot2::scale_x_discrete(
    labels = workload_labels,
    drop = FALSE,
    expand = ggplot2::expansion(
      mult = c(0.04, 0.04)
    )
  ) +
  ggplot2::scale_y_log10(
    breaks = scales::breaks_log(n = 6),
    labels = scales::label_number(
    accuracy = 1,
    big.mark = ",",
    decimal.mark = ".",
    suffix = "\u00d7",
    trim = TRUE
    )
  ) +
  ggplot2::scale_colour_manual(
    values = speedup_colours,
    breaks = comparison_levels,
    limits = comparison_levels,
    drop = TRUE,
    name = NULL
  ) +
  ggplot2::scale_shape_manual(
    values = speedup_shapes,
    breaks = comparison_levels,
    limits = comparison_levels,
    drop = TRUE,
    name = NULL
  ) +
  ggplot2::guides(
    colour = ggplot2::guide_legend(
      nrow = 2,
      byrow = TRUE,
      override.aes = list(
        linewidth = 0.9,
        size = 2.9
      )
    ),
    shape = "none"
  ) +
  ggplot2::labs(
    title =
      "B. Paired implementation-specific speedup",

    x =
      "Number of biospecimen profiles",

    y =
      "Mean paired speedup (log scale)"
  ) +
  base_theme +
  ggplot2::theme(
    axis.title.x = ggplot2::element_text(
      margin = ggplot2::margin(
        t = 10
      )
    )
  )

# ------------------------------------------------------------------------------
# Combine panels
#
# The legends must remain separate:
#   Panel A = implementations
#   Panel B = speedup comparisons
#
# Collecting them would mix different semantic variables and was one of the
# causes of the malformed original Figure 7.
# ------------------------------------------------------------------------------

figure <- p1 / p2 +
  patchwork::plot_layout(
    heights = c(1, 1),
    guides = "keep"
  )

# ------------------------------------------------------------------------------
# Save publication outputs
# ------------------------------------------------------------------------------

pdf_path <- file.path(
  figure_dir,
  "Figure_7_Cross_Language_Runtime_Benchmark.pdf"
)

png_path <- file.path(
  figure_dir,
  "Figure_7_Cross_Language_Runtime_Benchmark.png"
)

ggplot2::ggsave(
  filename = pdf_path,
  plot = figure,
  width = 11.5,
  height = 8.8,
  units = "in",
  device = grDevices::cairo_pdf,
  bg = "white"
)

ggplot2::ggsave(
  filename = png_path,
  plot = figure,
  width = 11.5,
  height = 8.8,
  units = "in",
  dpi = 600,
  bg = "white"
)

log_message(
  "Cross-language Figure 7 and source tables generated"
)

message("Generated Figure 7:")
message("  - ", pdf_path)
message("  - ", png_path)

message("Generated Figure 7 source tables:")
message(
  "  - ",
  file.path(
    figure_source_dir,
    "Figure_7_Source_Cross_Language_Elapsed_CI95.csv"
  )
)
message(
  "  - ",
  file.path(
    figure_source_dir,
    "Figure_7_Source_Cross_Language_Paired_Speedup_CI95.csv"
  )
)
message(
  "  - ",
  file.path(
    figure_source_dir,
    "Figure_7_Source_Cross_Language_Paired_Speedup_Raw.csv"
  )
)

if ("cpp_cuda" %in% unique(raw$implementation)) {
  message(
    "CUDA benchmark detected: CUDA results were included in Figure 7."
  )
} else {
  message(
    "CUDA benchmark not detected: CUDA was omitted from Figure 7."
  )
}