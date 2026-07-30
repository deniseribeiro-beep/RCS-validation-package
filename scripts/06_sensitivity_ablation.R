source(file.path("scripts", "02_model.R"))
log_message("Running sensitivity and ablation analyses")

# Weight perturbation around baseline weights, preserving total 100 by normalization.
perturb_weight_once <- function(mt, perturb_sd = 0.10, n = 1000) {
  axes <- axis_names(mt)
  base_w <- axis_weights[[mt]]
  profiles <- generate_synthetic_cohort(n_per_scenario = 100) |>
    dplyr::filter(matrix == mt, G_gov == 1)
  base <- profiles$final_grade
  purrr::map_dfr(seq_len(n), function(i) {
    mult <- pmax(0.05, stats::rnorm(length(base_w), 1, perturb_sd))
    w <- base_w * mult
    w <- w / sum(w) * 100
    sev <- as.matrix(profiles[, paste0(axes, "_severity"), drop = FALSE])
    pb <- as.numeric(sev %*% w)
    rcs <- 100 - pb
    fg <- factor(score_grade(rcs), levels = names(rcs_cols))
    tibble::tibble(matrix = mt, iteration = i, changed_rate = mean(fg != base), mean_abs_rcs_shift = mean(abs(rcs - profiles$RCS)))
  })
}
wp <- dplyr::bind_rows(perturb_weight_once("fluid"), perturb_weight_once("solid"))
safe_write_csv(wp, "Table_Weight_Perturbation_Sensitivity.csv")

# Axis maximum influence under severity 1, all other severities 0.
axis_inf <- purrr::map_dfr(c("fluid", "solid"), function(mt) {
  axes <- axis_names(mt)
  purrr::map_dfr(axes, function(axis) {
    df <- tibble::tibble(matrix = mt, G_gov = 1L, axis = axis)
    for (a in axes) df[[paste0(a, "_severity")]] <- ifelse(a == axis, 1, 0)
    score_profiles(df) |>
      dplyr::transmute(matrix, axis, P_bio, RCS, final_grade)
  })
})
safe_write_csv(axis_inf, "Table_Axis_Influence_Summary.csv")

# Ablation comparisons.
cohort <- generate_synthetic_cohort(n_per_scenario = 200)
full <- cohort |>
  dplyr::count(model = "Full governance-aware RCS", final_grade, name = "n")
no_gate <- cohort |>
  dplyr::mutate(final_grade = score_based_grade) |>
  dplyr::count(model = "Without governance gate", final_grade, name = "n")
# Equal weights by matrix.
equal_score <- function(df) {
  df2 <- df |> dplyr::select(-dplyr::any_of(c("P_bio", "RCS", "score_based_grade", "final_grade", "grade_route", "nearest_threshold", "threshold_margin")))
  pb <- numeric(nrow(df2))
  for (mt in c("fluid", "solid")) {
    idx <- which(df2$matrix == mt)
    axes <- axis_names(mt)
    if (length(idx) > 0) {
      w <- rep(100 / length(axes), length(axes))
      sev <- as.matrix(df2[idx, paste0(axes, "_severity"), drop = FALSE])
      pb[idx] <- as.numeric(sev %*% w)
    }
  }
  rcs <- 100 - pb
  df2 |> dplyr::mutate(P_bio = pb, RCS = rcs, final_grade = factor(ifelse(G_gov == 0, "Grade E", score_grade(rcs)), levels = names(rcs_cols)))
}
equal <- equal_score(cohort) |>
  dplyr::count(model = "Equal axis weights", final_grade, name = "n")
ablation <- dplyr::bind_rows(full, no_gate, equal) |>
  dplyr::group_by(model) |>
  dplyr::mutate(proportion = n / sum(n)) |>
  dplyr::ungroup()
safe_write_csv(ablation, "Table_Ablation_Analysis.csv")

# Morris-style elementary effects and additive variance contribution summaries.
global <- purrr::map_dfr(c("fluid", "solid"), function(mt) {
  w <- axis_weights[[mt]]
  tibble::tibble(
    matrix = mt,
    axis = names(w),
    weight = as.numeric(w),
    morris_mu_star_for_Pbio = as.numeric(w),
    sobol_style_first_order_Pbio = as.numeric(w^2 / sum(w^2))
  )
})
safe_write_csv(global, "Table_Global_Sensitivity_Summary.csv")
log_message("Sensitivity and ablation analyses completed")
