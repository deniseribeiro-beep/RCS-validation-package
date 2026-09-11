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

benchmark_score_core <- function(x) {
  fluid_w <- c(30, 15, 10, 20, 25)
  solid_w <- c(25, 25, 15, 20, 15)
  p_bio <- numeric(x$n)
  fluid <- x$matrix == 0L
  solid <- !fluid
  if (any(fluid)) p_bio[fluid] <- as.numeric(x$severity[fluid, 1:5, drop = FALSE] %*% fluid_w)
  if (any(solid)) p_bio[solid] <- as.numeric(x$severity[solid, 6:10, drop = FALSE] %*% solid_w)
  score <- 100 - p_bio
  grade <- ifelse(score >= 90, 0L, ifelse(score >= 80, 1L, ifelse(score >= 65, 2L, ifelse(score >= 50, 3L, 4L))))
  route <- ifelse(x$governance == 0L, 2L, ifelse(score < 50, 1L, 0L))
  grade[x$governance == 0L] <- 4L
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

benchmark_compare_results <- function(expected, observed, tolerance = 1e-9) {
  same_n <- length(expected$p_bio) == length(observed$p_bio)
  max_p <- if (same_n) max(abs(expected$p_bio - observed$p_bio)) else Inf
  max_r <- if (same_n) max(abs(expected$score - observed$score)) else Inf
  same_grade <- same_n && identical(expected$grade, observed$grade)
  same_route <- same_n && identical(expected$route, observed$route)
  list(
    pass = same_n && max_p <= tolerance && max_r <= tolerance && same_grade && same_route,
    max_abs_pbio_diff = max_p,
    max_abs_rcs_diff = max_r,
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
