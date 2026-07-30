source(file.path("scripts", "02_model.R"))
log_message("Running combinatorial, threshold, one-axis, and governance analyses")

combo <- dplyr::bind_rows(make_combinatorial_grid("fluid"), make_combinatorial_grid("solid"))
safe_write_csv(combo, "Combinatorial_Admissible_Profiles.csv")

combo_dist <- combo |>
  dplyr::count(matrix, final_grade, name = "n") |>
  dplyr::group_by(matrix) |>
  dplyr::mutate(proportion = n / sum(n), total = sum(n)) |>
  dplyr::ungroup()
safe_write_csv(combo_dist, "Table_Combinatorial_Grade_Distribution.csv")

threshold_summary <- combo |>
  dplyr::group_by(matrix, final_grade) |>
  dplyr::summarise(
    n = dplyr::n(),
    mean_margin = mean(threshold_margin),
    median_margin = median(threshold_margin),
    q1_margin = quantile(threshold_margin, 0.25),
    q3_margin = quantile(threshold_margin, 0.75),
    min_margin = min(threshold_margin),
    max_margin = max(threshold_margin),
    .groups = "drop"
  )
safe_write_csv(threshold_summary, "Table_Threshold_Margin_Summary.csv")

# One-axis-at-a-time transitions: all other axes set to 0, one varies from 0 to 1.
oat <- purrr::map_dfr(c("fluid", "solid"), function(mt) {
  axes <- axis_names(mt)
  purrr::map_dfr(axes, function(axis) {
    states <- seq(0, 1, by = 0.05)
    df <- tibble::tibble(matrix = mt, varied_axis = axis, severity_state = states)
    for (a in axes) df[[paste0(a, "_severity")]] <- ifelse(a == axis, states, 0)
    score_profiles(df)
  })
})
safe_write_csv(oat, "Table_One_Axis_Transition_Analysis.csv")

failures <- c("metadata_incompleteness", "invalid_terminology", "traceability_failure", "monitoring_failure", "documentation_failure", "semantic_incompatibility")
gov <- purrr::map_dfr(c("fluid", "solid"), function(mt) {
  axes <- axis_names(mt)
  purrr::map_dfr(failures, function(f) {
    df <- tibble::tibble(matrix = mt, governance_failure_type = f)
    df$metadata_complete <- f != "metadata_incompleteness"
    df$terminology_valid <- f != "invalid_terminology"
    df$traceability_ok <- f != "traceability_failure"
    df$monitoring_ok <- f != "monitoring_failure"
    df$documentation_ok <- f != "documentation_failure"
    df$semantic_compatible <- f != "semantic_incompatibility"
    for (a in axes) df[[paste0(a, "_severity")]] <- 0.05
    score_profiles(df)
  })
})
safe_write_csv(gov, "Table_Governance_Sensitivity.csv")
log_message("Combinatorial, threshold, one-axis, and governance analyses completed")
