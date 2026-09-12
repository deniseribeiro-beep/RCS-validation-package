#!/usr/bin/env Rscript

source(file.path("scripts", "benchmark_common.R"))
args <- benchmark_parse_args()
required <- c("input", "output", "implementation", "workers", "warmups", "min-sec", "max-loops", "mode")
missing <- setdiff(required, names(args))
if (length(missing)) stop("Missing arguments: ", paste(missing, collapse = ", "))

workers <- as.integer(args$workers)
warmups <- as.integer(args$warmups)
minimum_seconds <- as.numeric(args[["min-sec"]])
maximum_loops <- as.integer(args[["max-loops"]])
read_start <- proc.time()[["elapsed"]]
profiles <- benchmark_read_profiles(args$input)
read_sec <- proc.time()[["elapsed"]] - read_start

score_chunk <- function(x) benchmark_score_r_secondary(x)

cluster <- NULL
init_start <- proc.time()[["elapsed"]]
if (args$implementation == "r_psock") {
  cluster <- parallel::makePSOCKcluster(workers)
  on.exit(parallel::stopCluster(cluster), add = TRUE)
  parallel::clusterExport(cluster, "benchmark_score_r_secondary", envir = environment())
  starts <- floor((seq_len(workers) - 1L) * profiles$n / workers) + 1L
  ends <- floor(seq_len(workers) * profiles$n / workers)
  bounds <- Map(function(first, last) seq.int(first, last), starts, ends)
  chunks <- lapply(bounds, function(i) list(
    n = length(i), matrix = profiles$matrix[i], governance = profiles$governance[i],
    severity = profiles$severity[i, , drop = FALSE]
  ))
  score_once <- function() {
    parts <- parallel::parLapply(cluster, chunks, benchmark_score_r_secondary)
    list(
      p_bio = unlist(lapply(parts, `[[`, "p_bio"), use.names = FALSE),
      score = unlist(lapply(parts, `[[`, "score"), use.names = FALSE),
      grade = as.integer(unlist(lapply(parts, `[[`, "grade"), use.names = FALSE)),
      route = as.integer(unlist(lapply(parts, `[[`, "route"), use.names = FALSE))
    )
  }
} else if (args$implementation == "r_sequential") {
  score_once <- function() benchmark_score_r_secondary(profiles)
} else stop("Unknown R implementation: ", args$implementation)
init_sec <- proc.time()[["elapsed"]] - init_start

if (args$mode == "e2e") {
  compute_start <- proc.time()[["elapsed"]]
  result <- score_once()
  compute_sec <- proc.time()[["elapsed"]] - compute_start
  write_start <- proc.time()[["elapsed"]]
  benchmark_write_results(result, args$output)
  write_sec <- proc.time()[["elapsed"]] - write_start
  internal_sec <- read_sec + init_sec + compute_sec + write_sec
  cat(sprintf("RCSPHASES,%.12g,%.12g,%.12g,%.12g,%.12g\n",
              read_sec, init_sec, compute_sec, write_sec, internal_sec))
  cat(sprintf("RCSRESULT,%s,%d,%d,1,NA,NA,FALSE,0\n", args$implementation, profiles$n, workers))
  quit(status = 0L)
}
if (args$mode != "compute") stop("mode must be compute or e2e")

if (warmups > 0L) for (i in seq_len(warmups)) invisible(score_once())
measurement <- benchmark_measure_calibrated(score_once, minimum_seconds, maximum_loops)
benchmark_write_results(measurement$result, args$output)
cat(sprintf("RCSRESULT,%s,%d,%d,%d,%.12g,%.12g,%s,%d\n",
            args$implementation, profiles$n, workers, measurement$loops,
            measurement$seconds_per_call, measurement$block_seconds,
            if (measurement$floor_passed) "TRUE" else "FALSE", measurement$attempts))
