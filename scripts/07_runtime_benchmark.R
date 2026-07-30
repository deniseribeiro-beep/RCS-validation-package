source(file.path("scripts", "02_model.R"))
log_message("Running runtime benchmark")

RUN_LARGE <- toupper(Sys.getenv("RUN_LARGE_BENCH", unset = "FALSE")) == "TRUE"
REPS <- as.integer(Sys.getenv("BENCH_REPS", unset = "3"))
sizes <- if (RUN_LARGE) c(1e4, 5e4, 1e5, 5e5, 1e6, 2e6, 5e6) else c(1e4, 5e4, 1e5, 5e5)

make_bench_df <- function(n) {
  matrix <- rep(c("fluid", "solid"), length.out = n)
  df <- tibble::tibble(matrix = matrix)
  all_axes <- unique(unlist(lapply(axis_weights, names)))
  for (a in all_axes) df[[paste0(a, "_severity")]] <- stats::runif(n, 0, 1)
  df
}

raw <- purrr::map_dfr(sizes, function(n) {
  purrr::map_dfr(seq_len(REPS), function(rep_id) {
    df <- make_bench_df(n)
    gc()
    t <- system.time({ scored <- score_profiles(df) })
    tibble::tibble(n_records = n, rep = rep_id, elapsed_sec = unname(t[["elapsed"]]), per_sample_microsec = elapsed_sec / n * 1e6)
  })
})
safe_write_csv(raw, "Table_Runtime_Benchmark_Raw.csv")

summary <- raw |>
  dplyr::group_by(n_records) |>
  dplyr::summarise(
    reps = dplyr::n(),
    mean_sec = mean(elapsed_sec),
    median_sec = median(elapsed_sec),
    sd_sec = sd(elapsed_sec),
    iqr_sec = IQR(elapsed_sec),
    mean_per_sample_microsec = mean(per_sample_microsec),
    .groups = "drop"
  )
safe_write_csv(summary, "Table_Runtime_Benchmark_Summary.csv")

fit <- lm(elapsed_sec ~ n_records, data = raw)
fit_tbl <- broom::glance(fit) |>
  dplyr::bind_cols(broom::tidy(fit) |> dplyr::select(term, estimate) |> tidyr::pivot_wider(names_from = term, values_from = estimate))
safe_write_csv(fit_tbl, "Table_Runtime_Linear_Fit.csv")
log_message("Runtime benchmark completed")
