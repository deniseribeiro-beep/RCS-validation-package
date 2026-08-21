#!/usr/bin/env Rscript

# Export the optional R sequential-versus-PSOCK benchmark as audit tables.
# No standalone manuscript figure is generated: the R/PSOCK observations are
# included with C++, OpenMP and CUDA in the unified Figure 6 produced by script
# 14 during the aligned cross-language experiment.

source(file.path("scripts", "01_config_utils.R"))

table_dir <- file.path("outputs", "tables")
source_dir <- file.path(table_dir, "figure_source")
supplementary_dir <- file.path(table_dir, "supplementary")
dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(supplementary_dir, recursive = TRUE, showWarnings = FALSE)

raw_path <- file.path(table_dir, "Table_Parallel_Runtime_Benchmark_Raw.csv")
summary_path <- file.path(
  table_dir, "Table_Parallel_Runtime_Benchmark_Summary.csv"
)
equivalence_path <- file.path(
  table_dir, "Table_Parallel_Runtime_Equivalence_Check.csv"
)
required <- c(raw_path, summary_path, equivalence_path)
missing <- required[!file.exists(required)]
if (length(missing)) {
  stop(
    "Missing R/PSOCK benchmark tables: ",
    paste(missing, collapse = ", "),
    ". Run scripts/10_parallel_runtime_benchmark.R first."
  )
}

raw <- readr::read_csv(raw_path, show_col_types = FALSE, progress = FALSE)
summary <- readr::read_csv(summary_path, show_col_types = FALSE, progress = FALSE)
equivalence <- readr::read_csv(
  equivalence_path, show_col_types = FALSE, progress = FALSE
)

manuscript_table <- summary |>
  dplyr::transmute(
    profiles = n_records,
    workers,
    repetitions = reps,
    mean_r_sequential_seconds = round(mean_sequential_sec, 6),
    mean_r_psock_seconds = round(mean_parallel_sec, 6),
    mean_paired_psock_speedup = round(mean_speedup, 4),
    mean_r_psock_microseconds_per_profile = round(
      mean_parallel_per_sample_microsec, 6
    ),
    deterministic_equivalence = ifelse(
      all_equivalence_checks_passed, "Passed", "Failed"
    )
  )

readr::write_csv(
  manuscript_table,
  file.path(table_dir, "Table_R_PSOCK_Runtime_Benchmark_Manuscript.csv")
)
readr::write_csv(
  manuscript_table,
  file.path(
    supplementary_dir,
    "Additional_File_S12_R_PSOCK_Runtime_Benchmark.csv"
  )
)
readr::write_csv(
  raw,
  file.path(source_dir, "R_PSOCK_Runtime_Benchmark_Raw.csv")
)
readr::write_csv(
  summary,
  file.path(source_dir, "R_PSOCK_Runtime_Benchmark_Summary.csv")
)
readr::write_csv(
  equivalence,
  file.path(source_dir, "R_PSOCK_Runtime_Equivalence_Check.csv")
)

log_message("R/PSOCK benchmark audit tables generated; no separate figure created")
