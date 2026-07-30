source(file.path("scripts", "01_config_utils.R"))

axis_weights <- list(
  fluid = c(P_pre = 30, P_cent1 = 15, P_cent2 = 10, P_post = 20, P_store = 25),
  solid = c(P_warm = 25, P_cold = 25, P_fix = 15, P_fixTime = 20, P_store = 15)
)

axis_names <- function(matrix_type) names(axis_weights[[matrix_type]])

score_grade <- function(rcs) {
  dplyr::case_when(
    rcs >= 90 ~ "Grade A",
    rcs >= 80 ~ "Grade B",
    rcs >= 65 ~ "Grade C",
    rcs >= 50 ~ "Grade D",
    TRUE ~ "Grade E"
  )
}

score_profiles <- function(df) {
  stopifnot("matrix" %in% names(df))
  allowed_matrices <- names(axis_weights)
  if (any(!df$matrix %in% allowed_matrices)) {
    stop("Unknown matrix type. Allowed values: ", paste(allowed_matrices, collapse = ", "))
  }

  governance_fields <- c(
    "metadata_complete", "terminology_valid", "traceability_ok",
    "monitoring_ok", "documentation_ok", "semantic_compatible"
  )
  for (field in governance_fields) {
    if (!field %in% names(df)) df[[field]] <- TRUE
  }
  governance_matrix <- as.matrix(df[, governance_fields, drop = FALSE])
  if (anyNA(governance_matrix)) {
    stop("Governance evidence cannot be NA. Use FALSE for failed or unresolved evidence.")
  }
  computed_gate <- as.integer(apply(governance_matrix, 1, all))
  if ("G_gov" %in% names(df) && any(as.integer(df$G_gov) != computed_gate)) {
    stop("G_gov conflicts with the explicit governance evidence fields.")
  }
  df$G_gov <- computed_gate

  # Make scoring idempotent.
  df <- df |>
    dplyr::select(-dplyr::any_of(c("P_bio", "RCS", "score_based_grade", "final_grade", "grade_route", "nearest_threshold", "threshold_margin")))

  all_axes <- unique(unlist(lapply(axis_weights, names)))
  for (axis in all_axes) {
    col <- paste0(axis, "_severity")
    if (!col %in% names(df)) df[[col]] <- NA_real_
  }

  pbio <- rep(NA_real_, nrow(df))
  for (mt in names(axis_weights)) {
    idx <- which(df$matrix == mt)
    if (length(idx) > 0) {
      axes <- names(axis_weights[[mt]])
      sev <- as.matrix(df[idx, paste0(axes, "_severity"), drop = FALSE])
      storage.mode(sev) <- "double"
      invalid <- apply(sev, 1, function(x) anyNA(x) || any(x < 0 | x > 1))
      if (any(invalid & df$G_gov[idx] == 1L)) {
        stop("Admissible profiles must contain complete severities in [0,1] for every matrix-specific axis.")
      }
      scoreable <- !invalid
      pbio[idx[scoreable]] <- as.numeric(
        sev[scoreable, , drop = FALSE] %*% axis_weights[[mt]]
      )
      # Missing, invalid, or not-scored axis values are non-compensable
      # semantic/context failures; they are never converted to severity zero.
      if (any(invalid)) {
        df$semantic_compatible[idx[invalid]] <- FALSE
        df$G_gov[idx[invalid]] <- 0L
      }
    }
  }

  rcs <- 100 - pbio
  score_based <- score_grade(rcs)
  final <- ifelse(df$G_gov == 0, "Grade E", score_based)
  route <- dplyr::case_when(
    df$G_gov == 0 ~ "Governance failure",
    rcs < 50 ~ "Critical penalty burden",
    TRUE ~ "Score-based certification"
  )

  thresholds <- c(10, 20, 35, 50)
  margins <- purrr::map_dbl(pbio, ~ if (is.na(.x)) NA_real_ else min(abs(.x - thresholds)))
  nearest <- purrr::map_dbl(pbio, ~ if (is.na(.x)) NA_real_ else thresholds[which.min(abs(.x - thresholds))])

  df |>
    dplyr::mutate(
      P_bio = pbio,
      RCS = rcs,
      score_based_grade = factor(score_based, levels = names(rcs_cols)),
      final_grade = factor(final, levels = names(rcs_cols)),
      grade_route = route,
      nearest_threshold = nearest,
      threshold_margin = margins
    )
}

severity_for_target <- function(matrix_type, target_pbio) {
  axes <- axis_names(matrix_type)
  val <- pmin(1, pmax(0, target_pbio / sum(axis_weights[[matrix_type]])))
  stats::setNames(rep(val, length(axes)), paste0(axes, "_severity"))
}

make_profile_block <- function(matrix_type, scenario, n) {
  target <- c(
    optimal = 5,
    mild_suboptimal = 15,
    moderate_suboptimal = 27,
    severe_suboptimal = 42,
    critical_penalty_burden = 65,
    governance_failure = 5
  )[[scenario]]
  jitter_sd <- c(
    optimal = 1.5,
    mild_suboptimal = 2,
    moderate_suboptimal = 3,
    severe_suboptimal = 3,
    critical_penalty_burden = 5,
    governance_failure = 1.5
  )[[scenario]]

  pb <- pmin(90, pmax(0, stats::rnorm(n, target, jitter_sd)))
  axes <- axis_names(matrix_type)
  out <- tibble::tibble(
    specimen_id = paste(matrix_type, scenario, seq_len(n), sep = "_"),
    matrix = matrix_type,
    scenario = scenario,
    expected_grade = dplyr::case_when(
      scenario == "optimal" ~ "Grade A",
      scenario == "mild_suboptimal" ~ "Grade B",
      scenario == "moderate_suboptimal" ~ "Grade C",
      scenario == "severe_suboptimal" ~ "Grade D",
      TRUE ~ "Grade E"
    ),
    metadata_complete = scenario != "governance_failure",
    terminology_valid = TRUE,
    traceability_ok = TRUE,
    monitoring_ok = TRUE,
    documentation_ok = TRUE,
    semantic_compatible = TRUE
  )
  for (axis in axes) {
    # Distributed around target while preserving total interpretation.
    out[[paste0(axis, "_severity")]] <- pmin(1, pmax(0, pb / 100 + stats::rnorm(n, 0, 0.015)))
    out[[paste0(axis, "_code")]] <- paste0(axis, "_", scenario)
  }
  out
}

generate_synthetic_cohort <- function(n_per_scenario = 300) {
  scenarios <- c("optimal", "mild_suboptimal", "moderate_suboptimal", "severe_suboptimal", "critical_penalty_burden", "governance_failure")
  tidyr::expand_grid(matrix = c("fluid", "solid"), scenario = scenarios) |>
    purrr::pmap_dfr(~ make_profile_block(..1, ..2, n_per_scenario)) |>
    score_profiles() |>
    dplyr::mutate(expected_grade = factor(expected_grade, levels = names(rcs_cols)))
}

make_combinatorial_grid <- function(matrix_type, states = c(0, 0.25, 0.5, 0.75, 1)) {
  axes <- axis_names(matrix_type)
  grid <- expand.grid(rep(list(states), length(axes)))
  names(grid) <- paste0(axes, "_severity")
  tibble::as_tibble(grid) |>
    dplyr::mutate(matrix = matrix_type) |>
    dplyr::select(matrix, dplyr::everything()) |>
    score_profiles()
}
