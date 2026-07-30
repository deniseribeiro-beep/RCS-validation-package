source(file.path("scripts", "02_model.R"))
log_message("Running synthetic validation")

N_PER_SCENARIO <- as.integer(Sys.getenv("N_PER_SCENARIO", unset = "500"))
cohort <- generate_synthetic_cohort(N_PER_SCENARIO)
safe_write_csv(cohort, "Synthetic_Cohort_RCS.csv")

cal <- cohort |>
  dplyr::mutate(match = final_grade == expected_grade) |>
  dplyr::summarise(
    N = dplyr::n(),
    internal_calibration_index = mean(match),
    matches = sum(match),
    mismatches = sum(!match)
  )
safe_write_csv(cal, "Table_Internal_Calibration_Index.csv")

summary <- cohort |>
  dplyr::count(matrix, scenario, expected_grade, final_grade, grade_route, name = "n") |>
  dplyr::group_by(matrix, scenario) |>
  dplyr::mutate(proportion = n / sum(n)) |>
  dplyr::ungroup()
safe_write_csv(summary, "Table_Synthetic_Validation_Grade_Distribution.csv")

validation_summary <- tibble::tibble(
  metric = c("synthetic_profiles", "internal_calibration_index", "governance_failure_profiles", "critical_penalty_profiles"),
  value = c(nrow(cohort), cal$internal_calibration_index, sum(cohort$grade_route == "Governance failure"), sum(cohort$grade_route == "Critical penalty burden"))
)
safe_write_csv(validation_summary, "Table_Validation_Summary.csv")
log_message("Synthetic validation completed")
