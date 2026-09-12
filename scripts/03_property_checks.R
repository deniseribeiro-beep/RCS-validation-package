source(file.path("scripts", "02_model.R"))
log_message("Running property-based logical checks")

check <- function(name, passed, evidence) {
  tibble::tibble(check = name, passed = isTRUE(passed), evidence = as.character(evidence))
}

cohort <- generate_synthetic_cohort(n_per_scenario = 50)
checks <- list()

checks[[1]] <- check(
  "Governance failure routes directly to Grade E",
  all(cohort$final_grade[cohort$G_gov == 0] == "Grade E"),
  paste("Profiles tested:", sum(cohort$G_gov == 0))
)

checks[[2]] <- check(
  "RCS identity equals 100 minus Pbio",
  max(abs(cohort$RCS - (100 - cohort$P_bio)), na.rm = TRUE) < 1e-9,
  paste("Maximum absolute deviation:", max(abs(cohort$RCS - (100 - cohort$P_bio)), na.rm = TRUE))
)

checks[[3]] <- check(
  "Pbio remains within 0 to 100",
  all(cohort$P_bio >= -1e-9 & cohort$P_bio <= 100 + 1e-9),
  paste("Observed range:", paste(round(range(cohort$P_bio), 4), collapse = " to "))
)

mono <- purrr::map_lgl(c("fluid", "solid"), function(mt) {
  axes <- axis_names(mt)
  low <- add_admissible_analysis_governance(tibble::tibble(matrix = mt))
  high <- add_admissible_analysis_governance(tibble::tibble(matrix = mt))
  for (a in axes) {
    low[[paste0(a, "_severity")]] <- 0.2
    high[[paste0(a, "_severity")]] <- 0.2
  }
  high[[paste0(axes[1], "_severity")]] <- 0.8
  s <- score_profiles(dplyr::bind_rows(low, high))
  s$P_bio[2] >= s$P_bio[1] && s$RCS[2] <= s$RCS[1]
})
checks[[4]] <- check("Severity increase is monotonic", all(mono), "One-axis increase tested for each matrix")

single <- cohort[1,] |>
  dplyr::select(matrix, dplyr::all_of(c(
    "metadata_complete", "terminology_valid", "traceability_ok",
    "monitoring_ok", "documentation_ok", "semantic_compatible"
  )), dplyr::ends_with("_severity"), dplyr::ends_with("_code"))
dup <- score_profiles(dplyr::bind_rows(single, single))
checks[[5]] <- check(
  "Identical inputs produce identical outputs",
  dup$P_bio[1] == dup$P_bio[2] && dup$RCS[1] == dup$RCS[2] && dup$final_grade[1] == dup$final_grade[2],
  "Duplicated input profile evaluated twice"
)

checks[[6]] <- check(
  "Matrix-specific axes are distinct and correctly defined",
  !identical(axis_names("fluid"), axis_names("solid")) && sum(axis_weights$fluid) == 100 && sum(axis_weights$solid) == 100,
  paste("Fluid axes:", paste(axis_names("fluid"), collapse = ", "), "| Solid axes:", paste(axis_names("solid"), collapse = ", "))
)

not_scored <- tibble::tibble(
  matrix = "fluid",
  metadata_complete = TRUE,
  terminology_valid = TRUE,
  traceability_ok = TRUE,
  monitoring_ok = TRUE,
  documentation_ok = TRUE,
  semantic_compatible = FALSE,
  P_pre_severity = NA_real_,
  P_cent1_severity = 0,
  P_cent2_severity = 0,
  P_post_severity = 0,
  P_store_severity = 0
) |>
  score_profiles()
checks[[7]] <- check(
  "Not-scored conditions are not represented as zero severity",
  not_scored$G_gov == 0L &&
    is.na(not_scored$P_bio) &&
    is.na(not_scored$RCS) &&
    not_scored$final_grade == "Grade E" &&
    not_scored$grade_route == "Governance failure",
  "An unresolved axis produced governance failure, Grade E, and no numerical Pbio/RCS."
)

missing_governance_rejected <- tryCatch(
  {
    score_profiles(tibble::tibble(
      matrix = "fluid",
      P_pre_severity = 0,
      P_cent1_severity = 0,
      P_cent2_severity = 0,
      P_post_severity = 0,
      P_store_severity = 0
    ))
    FALSE
  },
  error = function(e) grepl("Missing explicit governance evidence fields", conditionMessage(e), fixed = TRUE)
)
checks[[8]] <- check(
  "Missing governance evidence is never promoted to pass",
  missing_governance_rejected,
  "A profile without explicit governance evidence must be rejected as incomplete input."
)

property_checks <- dplyr::bind_rows(checks)
safe_write_csv(property_checks, "Table_Property_Based_Checks.csv")
if (!all(property_checks$passed)) stop("At least one property-based check failed")
log_message("Property-based logical checks completed")
