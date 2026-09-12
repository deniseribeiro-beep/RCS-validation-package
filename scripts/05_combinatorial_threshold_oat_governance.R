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
    df <- add_admissible_analysis_governance(
      tibble::tibble(matrix = mt, varied_axis = axis, severity_state = states)
    )
    for (a in axes) df[[paste0(a, "_severity")]] <- ifelse(a == axis, states, 0)
    score_profiles(df)
  })
})
safe_write_csv(oat, "Table_One_Axis_Transition_Analysis.csv")

# Deterministic threshold-transition analysis under five isolated
# axis-weight perturbation scenarios: -20%, -10%, nominal, +10%, +20%.
weight_perturbations <- c(
  "-20%" = -0.20,
  "-10%" = -0.10,
  "Nominal" = 0,
  "+10%" = 0.10,
  "+20%" = 0.20
)

transition_thresholds <- c(
  "A to B" = 10,
  "B to C" = 20,
  "C to D" = 35,
  "D to E" = 50
)

axis_labels <- c(
  P_pre = "Pre-centrifugation",
  P_cent1 = "First centrifugation",
  P_cent2 = "Second centrifugation",
  P_post = "Post-centrifugation",
  P_store = "Storage",
  P_warm = "Warm ischemia",
  P_cold = "Cold ischemia",
  P_fix = "Fixation",
  P_fixTime = "Fixation time"
)

threshold_transition_detail <- purrr::map_dfr(
  c("fluid", "solid"),
  function(mt) {
    base_weights <- axis_weights[[mt]]
    axes <- names(base_weights)
    purrr::map_dfr(
      seq_along(axes),
      function(axis_index) {
        axis <- axes[[axis_index]]
        purrr::imap_dfr(
          weight_perturbations,
          function(perturbation, perturbation_label) {
            perturbed_weights <- base_weights
            perturbed_weights[[axis]] <- perturbed_weights[[axis]] * (1 + perturbation)
            normalized_weights <- perturbed_weights / sum(perturbed_weights) * 100
            isolated_axis_weight <- normalized_weights[[axis]]
            purrr::imap_dfr(
              transition_thresholds,
              function(threshold, threshold_transition) {
                severity_required <- threshold / isolated_axis_weight
                reached <- is.finite(severity_required) && severity_required >= 0 && severity_required <= 1
                tibble::tibble(
                  matrix = mt,
                  axis = axis,
                  axis_label = unname(axis_labels[[axis]]),
                  axis_order = axis_index,
                  perturbation_scenario = perturbation_label,
                  perturbation_fraction = perturbation,
                  baseline_weight = unname(base_weights[[axis]]),
                  normalized_perturbed_weight = isolated_axis_weight,
                  threshold_transition = threshold_transition,
                  transition_label = dplyr::recode(
                    threshold_transition,
                    "A to B" = "A→B",
                    "B to C" = "B→C",
                    "C to D" = "C→D",
                    "D to E" = "D→E"
                  ),
                  penalty_threshold = threshold,
                  severity_required = severity_required,
                  severity_plot = pmin(severity_required, 1),
                  reached = reached
                )
              }
            )
          }
        )
      }
    )
  }
)
safe_write_csv(threshold_transition_detail, "Table_Threshold_Transition_Detail.csv")

# Canonical published summary derived directly from the complete transition table.
threshold_transition_summary <- threshold_transition_detail |>
  dplyr::group_by(matrix, threshold_transition) |>
  dplyr::summarise(
    reached_n = sum(reached, na.rm = TRUE),
    total_n = dplyr::n(),
    reached_fraction = reached_n / total_n,
    .groups = "drop"
  ) |>
  dplyr::mutate(
    transition = dplyr::recode(
      threshold_transition,
      "A to B" = "A-to-B",
      "B to C" = "B-to-C",
      "C to D" = "C-to-D",
      "D to E" = "D-to-E"
    ),
    reached = paste0(reached_n, "/", total_n),
    interpretation = dplyr::case_when(
      matrix == "fluid" & threshold_transition == "A to B" ~ "Second centrifugation did not reach the transition under -20% and -10% perturbation.",
      matrix == "fluid" & threshold_transition == "B to C" ~ "Intermediate threshold transitions occurred in approximately half of perturbation scenarios.",
      matrix == "fluid" & threshold_transition == "C to D" ~ "No isolated fluid axis reached the Grade D threshold.",
      matrix == "fluid" & threshold_transition == "D to E" ~ "No isolated fluid axis produced critical Grade E degradation.",
      matrix == "solid" & threshold_transition == "A to B" ~ "All solid axes reproducibly reached the first threshold transition.",
      matrix == "solid" & threshold_transition == "B to C" ~ "Intermediate threshold transitions occurred in approximately half of perturbation scenarios.",
      matrix == "solid" & threshold_transition == "C to D" ~ "No isolated solid axis reached the Grade D threshold.",
      matrix == "solid" & threshold_transition == "D to E" ~ "No isolated solid axis produced critical Grade E degradation.",
      TRUE ~ NA_character_
    )
  ) |>
  dplyr::select(matrix, transition, reached_n, total_n, reached_fraction, reached, interpretation)
safe_write_csv(threshold_transition_summary, "Table_Threshold_Transition_Summary.csv")

failures <- c(
  "metadata_incompleteness", "invalid_terminology", "traceability_failure",
  "monitoring_failure", "documentation_failure", "semantic_incompatibility"
)
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
