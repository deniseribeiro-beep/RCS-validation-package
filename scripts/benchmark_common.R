#!/usr/bin/env Rscript

benchmark_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list()
  i <- 1L
  while (i <= length(args)) {
    key <- sub("^--", "", args[[i]])
    if (i == length(args)) stop("Missing value after --", key)
    out[[key]] <- args[[i + 1L]]
    i <- i + 2L
  }
  out
}

benchmark_read_profiles <- function(path) {
  con <- file(path, "rb"); on.exit(close(con), add = TRUE)
  if (!identical(readBin(con, "raw", 8L), c(charToRaw("RCSBIN1"), as.raw(0L))))
    stop("Invalid RCS input header: ", path)
  n <- as.integer(readBin(con, "numeric", 1L, size = 8L, endian = "little"))
  matrix_code <- as.integer(readBin(con, "raw", n))
  governance <- as.integer(readBin(con, "raw", n))
  severity <- matrix(0, nrow = n, ncol = 10L)
  for (j in seq_len(10L)) severity[, j] <- readBin(con, "numeric", n, size = 8L, endian = "little")
  if (nrow(severity) != n) stop("Truncated RCS input: ", path)
  list(n = n, matrix = matrix_code, governance = governance, severity = severity)
}

benchmark_write_profiles <- function(x, path) {
  con <- file(path, "wb"); on.exit(close(con), add = TRUE)
  writeBin(c(charToRaw("RCSBIN1"), as.raw(0L)), con)
  writeBin(as.numeric(x$n), con, size = 8L, endian = "little")
  writeBin(as.raw(x$matrix), con)
  writeBin(as.raw(x$governance), con)
  for (j in seq_len(10L)) writeBin(as.double(x$severity[, j]), con, size = 8L, endian = "little")
}

# Secondary R implementation used only for equivalence/benchmarking. The C
# reference implementation is the computational reference and generates the
# expected benchmark outputs.
benchmark_score_r_secondary <- function(x) {
  fluid_w <- c(30, 15, 10, 20, 25)
  solid_w <- c(25, 25, 15, 20, 15)
  if (any(!x$matrix %in% c(0L, 1L))) stop("Invalid benchmark matrix code.")
  if (any(!x$governance %in% c(0L, 1L))) stop("Invalid benchmark governance code.")

  p_bio <- rep(NaN, x$n)
  score <- rep(NaN, x$n)
  grade <- rep(4L, x$n)
  route <- rep(2L, x$n)
  admissible <- x$governance == 1L
  fluid <- admissible & x$matrix == 0L
  solid <- admissible & x$matrix == 1L

  if (any(fluid)) p_bio[fluid] <- as.numeric(x$severity[fluid, 1:5, drop = FALSE] %*% fluid_w)
  if (any(solid)) p_bio[solid] <- as.numeric(x$severity[solid, 6:10, drop = FALSE] %*% solid_w)
  score[admissible] <- 100 - p_bio[admissible]
  grade[admissible] <- ifelse(
    score[admissible] >= 90, 0L,
    ifelse(score[admissible] >= 80, 1L,
      ifelse(score[admissible] >= 65, 2L,
        ifelse(score[admissible] >= 50, 3L, 4L)))
  )
  route[admissible] <- ifelse(score[admissible] < 50, 1L, 0L)
  list(p_bio = p_bio, score = score, grade = as.integer(grade), route = as.integer(route))
}

benchmark_write_results <- function(x, path) {
  con <- file(path, "wb"); on.exit(close(con), add = TRUE)
  writeBin(c(charToRaw("RCSOUT1"), as.raw(0L)), con)
  writeBin(as.numeric(length(x$p_bio)), con, size = 8L, endian = "little")
  writeBin(as.double(x$p_bio), con, size = 8L, endian = "little")
  writeBin(as.double(x$score), con, size = 8L, endian = "little")
  writeBin(as.raw(x$grade), con)
  writeBin(as.raw(x$route), con)
}

benchmark_read_results <- function(path) {
  con <- file(path, "rb"); on.exit(close(con), add = TRUE)
  if (!identical(readBin(con, "raw", 8L), c(charToRaw("RCSOUT1"), as.raw(0L))))
    stop("Invalid RCS output header: ", path)
  n <- as.integer(readBin(con, "numeric", 1L, size = 8L, endian = "little"))
  list(
    p_bio = readBin(con, "numeric", n, size = 8L, endian = "little"),
    score = readBin(con, "numeric", n, size = 8L, endian = "little"),
    grade = as.integer(readBin(con, "raw", n)),
    route = as.integer(readBin(con, "raw", n))
  )
}

benchmark_numeric_equivalence <- function(expected, observed, tolerance) {
  if (length(expected) != length(observed)) return(list(pass = FALSE, max_diff = Inf))
  expected_missing <- is.na(expected)
  observed_missing <- is.na(observed)
  if (!identical(expected_missing, observed_missing)) return(list(pass = FALSE, max_diff = Inf))
  keep <- !expected_missing
  if (!any(keep)) return(list(pass = TRUE, max_diff = 0))
  diffs <- abs(expected[keep] - observed[keep])
  if (any(!is.finite(diffs))) return(list(pass = FALSE, max_diff = Inf))
  max_diff <- max(diffs)
  list(pass = max_diff <= tolerance, max_diff = max_diff)
}

benchmark_compare_results <- function(expected, observed, tolerance = 1e-9) {
  same_n <- length(expected$p_bio) == length(observed$p_bio)
  if (!same_n) return(list(
    pass = FALSE, max_abs_pbio_diff = Inf, max_abs_rcs_diff = Inf,
    identical_grade = FALSE, identical_route = FALSE
  ))
  p_cmp <- benchmark_numeric_equivalence(expected$p_bio, observed$p_bio, tolerance)
  r_cmp <- benchmark_numeric_equivalence(expected$score, observed$score, tolerance)
  same_grade <- identical(expected$grade, observed$grade)
  same_route <- identical(expected$route, observed$route)
  list(
    pass = p_cmp$pass && r_cmp$pass && same_grade && same_route,
    max_abs_pbio_diff = p_cmp$max_diff,
    max_abs_rcs_diff = r_cmp$max_diff,
    identical_grade = same_grade,
    identical_route = same_route
  )
}

benchmark_measure_calibrated <- function(fun, minimum_seconds, maximum_loops) {
  loops <- 1L
  attempts <- 0L
  repeat {
    attempts <- attempts + 1L
    start <- proc.time()[["elapsed"]]
    for (i in seq_len(loops)) result <- fun()
    block_seconds <- proc.time()[["elapsed"]] - start
    if (is.finite(block_seconds) && block_seconds >= minimum_seconds) {
      return(list(
        result = result, loops = loops, block_seconds = block_seconds,
        seconds_per_call = block_seconds / loops, floor_passed = TRUE, attempts = attempts
      ))
    }
    if (loops >= maximum_loops) {
      return(list(
        result = result, loops = as.integer(maximum_loops), block_seconds = block_seconds,
        seconds_per_call = block_seconds / loops, floor_passed = FALSE, attempts = attempts
      ))
    }
    estimate <- if (is.finite(block_seconds) && block_seconds > 0) {
      ceiling(1.10 * loops * minimum_seconds / block_seconds)
    } else {
      loops * 2
    }
    loops <- as.integer(min(maximum_loops, max(loops + 1, loops * 2, estimate)))
  }
}
