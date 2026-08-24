#!/usr/bin/env Rscript

source(file.path("benchmark_v2", "common.R"))
args <- v2_parse_args()
required <- c("input", "output", "implementation", "workers", "warmups", "min-sec", "max-loops", "mode")
missing <- setdiff(required, names(args))
if (length(missing)) stop("Missing arguments: ", paste(missing, collapse = ", "))

workers <- as.integer(args$workers)
warmups <- as.integer(args$warmups)
minimum_seconds <- as.numeric(args[["min-sec"]])
maximum_loops <- as.integer(args[["max-loops"]])
profiles <- v2_read_profiles(args$input)

score_chunk <- function(x) {
  fluid_w <- c(30, 15, 10, 20, 25)
  solid_w <- c(25, 25, 15, 20, 15)
  n <- length(x$matrix)
  p_bio <- numeric(n)
  fluid <- x$matrix == 0L
  if (any(fluid)) p_bio[fluid] <- as.numeric(x$severity[fluid, 1:5, drop = FALSE] %*% fluid_w)
  if (any(!fluid)) p_bio[!fluid] <- as.numeric(x$severity[!fluid, 6:10, drop = FALSE] %*% solid_w)
  score <- 100 - p_bio
  grade <- ifelse(score >= 90, 0L, ifelse(score >= 80, 1L, ifelse(score >= 65, 2L, ifelse(score >= 50, 3L, 4L))))
  route <- ifelse(x$governance == 0L, 2L, ifelse(score < 50, 1L, 0L))
  grade[x$governance == 0L] <- 4L
  list(p_bio = p_bio, score = score, grade = as.integer(grade), route = as.integer(route))
}

cluster <- NULL
if (args$implementation == "r_psock") {
  cluster <- parallel::makePSOCKcluster(workers)
  on.exit(parallel::stopCluster(cluster), add = TRUE)
  parallel::clusterExport(cluster, "score_chunk", envir = environment())
  bounds <- split(seq_len(profiles$n), cut(seq_len(profiles$n), breaks = workers, labels = FALSE))
  chunks <- lapply(bounds, function(i) list(matrix = profiles$matrix[i], governance = profiles$governance[i], severity = profiles$severity[i, , drop = FALSE]))
  score_once <- function() {
    parts <- parallel::parLapply(cluster, chunks, score_chunk)
    list(p_bio = unlist(lapply(parts, `[[`, "p_bio"), use.names = FALSE),
         score = unlist(lapply(parts, `[[`, "score"), use.names = FALSE),
         grade = as.integer(unlist(lapply(parts, `[[`, "grade"), use.names = FALSE)),
         route = as.integer(unlist(lapply(parts, `[[`, "route"), use.names = FALSE)))
  }
} else if (args$implementation == "r_sequential") {
  score_once <- function() v2_score_core(profiles)
} else stop("Unknown R implementation: ", args$implementation)

if (args$mode == "e2e") {
  result <- score_once()
  v2_write_results(result, args$output)
  cat(sprintf("V2RESULT,%s,%d,%d,1,NA\n", args$implementation, profiles$n, workers))
  quit(status = 0L)
}
if (args$mode != "compute") stop("mode must be compute or e2e")

if (warmups > 0L) for (i in seq_len(warmups)) invisible(score_once())
inner_loops <- v2_calibrate_loops(score_once, minimum_seconds, maximum_loops)
start <- proc.time()[["elapsed"]]
for (i in seq_len(inner_loops)) result <- score_once()
elapsed <- (proc.time()[["elapsed"]] - start) / inner_loops
v2_write_results(result, args$output)
cat(sprintf("V2RESULT,%s,%d,%d,%d,%.12g\n", args$implementation, profiles$n, workers, inner_loops, elapsed))

