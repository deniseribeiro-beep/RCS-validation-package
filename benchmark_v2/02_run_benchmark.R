#!/usr/bin/env Rscript

source(file.path("benchmark_v2", "config.R"))
source(file.path("benchmark_v2", "common.R"))

status_ok <- function(x) is.null(attr(x, "status")) || identical(attr(x, "status"), 0L)
run_command <- function(command, args, timed = FALSE) {
  log <- tempfile("v2-engine-")
  on.exit(unlink(log), add = TRUE)
  start <- proc.time()[["elapsed"]]
  status <- system2(command, args, stdout = log, stderr = log)
  elapsed <- proc.time()[["elapsed"]] - start
  text <- if (file.exists(log)) readLines(log, warn = FALSE) else character()
  if (!identical(status, 0L)) stop("Command failed (", status, "): ", command, "\n", paste(text, collapse = "\n"))
  list(text = text, elapsed = if (timed) elapsed else NA_real_)
}

compile_native <- function() {
  if (!nzchar(Sys.which("g++"))) stop("g++ is required for benchmark V2.")
  seq_bin <- file.path(V2_BIN, "rcs_sequential_v2")
  omp_bin <- file.path(V2_BIN, "rcs_openmp_v2")
  run_command("g++", c("-std=c++17", "-O3", "-DNDEBUG", "-march=native", "src/v2/rcs_sequential_v2.cpp", "-o", seq_bin))
  run_command("g++", c("-std=c++17", "-O3", "-DNDEBUG", "-march=native", "-fopenmp", "src/v2/rcs_openmp_v2.cpp", "-o", omp_bin))
  cuda_bin <- file.path(V2_BIN, "rcs_cuda_v2")
  if (V2_RUN_CUDA) {
    if (!nzchar(Sys.which("nvcc"))) stop("V2_RUN_CUDA=TRUE but nvcc was not found.")
    run_command("nvcc", c("-std=c++17", "-O3", "-Xcompiler", "-march=native", "src/v2/rcs_cuda_v2.cu", "-o", cuda_bin))
  }
  list(cpp_sequential = seq_bin, cpp_openmp = omp_bin, cpp_cuda = cuda_bin)
}

if (V2_RUN_PYTHON) {
  if (!nzchar(Sys.which("python3"))) stop("python3 is required when V2_RUN_PYTHON=TRUE.")
  check <- system2("python3", c("-c", shQuote("import numpy; print(numpy.__version__)")), stdout = TRUE, stderr = TRUE)
  if (!status_ok(check)) stop("Python NumPy is required. Install it with: python3 -m pip install numpy")
}

source(file.path("benchmark_v2", "01_prepare_inputs.R"))
bins <- compile_native()
manifest <- read.csv(file.path(V2_ROOT, "Input_Manifest.csv"), stringsAsFactors = FALSE)

engines <- data.frame(implementation = c("r_sequential", "cpp_sequential"), workers = c(1L, 1L), family = c("r", "native"), stringsAsFactors = FALSE)
engines <- rbind(engines,
  data.frame(implementation = "r_psock", workers = V2_PROCESS_WORKERS, family = "r"),
  data.frame(implementation = "cpp_openmp", workers = V2_OPENMP_THREADS, family = "native"))
if (V2_RUN_PYTHON) engines <- rbind(engines,
  data.frame(implementation = "python_numpy", workers = 1L, family = "python"),
  data.frame(implementation = "python_process", workers = V2_PROCESS_WORKERS, family = "python"))
if (V2_RUN_CUDA) engines <- rbind(engines, data.frame(implementation = "cpp_cuda", workers = 1L, family = "cuda"))
rownames(engines) <- NULL

schedule <- merge(expand.grid(n_records = manifest$n_records, repetition = seq_len(V2_REPS)), engines, all = TRUE)
set.seed(V2_ORDER_SEED)
schedule$random_order <- ave(seq_len(nrow(schedule)), interaction(schedule$n_records, schedule$repetition), FUN = function(i) sample.int(length(i)))
schedule <- schedule[order(schedule$repetition, schedule$n_records, schedule$random_order), ]
write.csv(schedule, file.path(V2_ROOT, "Randomized_Execution_Schedule.csv"), row.names = FALSE)

raw_path <- file.path(V2_TABLES, "Table_V2_Runtime_Benchmark_Raw.csv")
raw <- if (V2_RESUME && file.exists(raw_path)) read.csv(raw_path, stringsAsFactors = FALSE) else data.frame()
completed_key <- function(implementation, workers, n_records, repetition, timing_region) {
  if (!nrow(raw)) return(FALSE)
  any(raw$implementation == implementation & raw$workers == workers & raw$n_records == n_records &
        raw$repetition == repetition & raw$timing_region == timing_region)
}

engine_command <- function(implementation) {
  if (implementation %in% c("r_sequential", "r_psock")) return(c("Rscript", file.path("benchmark_v2", "r_engine.R")))
  if (implementation %in% c("python_numpy", "python_process")) return(c("python3", file.path("benchmark_v2", "python_engine.py")))
  c(unname(bins[[implementation]]))
}

parse_compute <- function(text) {
  line <- tail(grep("^V2RESULT,", text, value = TRUE), 1L)
  if (!length(line)) stop("Engine did not emit a V2RESULT record:\n", paste(text, collapse = "\n"))
  fields <- strsplit(line, ",", fixed = TRUE)[[1]]
  list(inner_loops = as.integer(fields[[5]]), elapsed = as.numeric(fields[[6]]))
}

append_row <- function(row) {
  raw <<- if (!nrow(raw)) row else rbind(raw, row)
  write.csv(raw, raw_path, row.names = FALSE)
}

for (i in seq_len(nrow(schedule))) {
  item <- schedule[i, ]
  files <- manifest[manifest$n_records == item$n_records, ]
  expected <- v2_read_results(files$expected_file)
  command_spec <- engine_command(item$implementation)
  command <- command_spec[[1]]
  prefix_args <- command_spec[-1]
  warmups <- if (item$implementation == "cpp_cuda") V2_WARMUP_CUDA else if (item$workers > 1L || item$implementation %in% c("r_psock", "python_process", "cpp_openmp")) V2_WARMUP_PARALLEL else V2_WARMUP_CPU
  base_args <- c(prefix_args, "--input", files$input_file, "--implementation", item$implementation,
                 if (item$family == "native") "--threads" else "--workers", item$workers,
                 "--warmups", warmups, "--min-sec", V2_MIN_SAMPLE_SEC, "--max-loops", V2_MAX_INNER_LOOPS)
  message(sprintf("V2 block rep=%d n=%d implementation=%s workers=%d", item$repetition, item$n_records, item$implementation, item$workers))

  if (!completed_key(item$implementation, item$workers, item$n_records, item$repetition, "compute")) {
    output <- file.path(V2_RESULTS, sprintf("compute_%s_w%02d_n%08d_rep%02d.bin", item$implementation, item$workers, item$n_records, item$repetition))
    execution <- run_command(command, c(base_args, "--output", output, "--mode", "compute"))
    parsed <- parse_compute(execution$text)
    comparison <- v2_compare_results(expected, v2_read_results(output))
    if (!comparison$pass) stop("Equivalence failed for ", output)
    append_row(data.frame(protocol_version = V2_PROTOCOL_VERSION, n_records = item$n_records,
      repetition = item$repetition, random_order = item$random_order, implementation = item$implementation,
      workers = item$workers, timing_region = "compute", inner_loops = parsed$inner_loops,
      elapsed_sec = parsed$elapsed, throughput_profiles_sec = item$n_records / parsed$elapsed,
      equivalence_passed = comparison$pass, max_abs_pbio_diff = comparison$max_abs_pbio_diff,
      max_abs_rcs_diff = comparison$max_abs_rcs_diff, identical_final_grade = comparison$identical_grade,
      identical_grade_route = comparison$identical_route, stringsAsFactors = FALSE))
  }

  if (!completed_key(item$implementation, item$workers, item$n_records, item$repetition, "end_to_end")) {
    output <- file.path(V2_RESULTS, sprintf("e2e_%s_w%02d_n%08d_rep%02d.bin", item$implementation, item$workers, item$n_records, item$repetition))
    execution <- run_command(command, c(base_args, "--output", output, "--mode", "e2e"), timed = TRUE)
    comparison <- v2_compare_results(expected, v2_read_results(output))
    if (!comparison$pass) stop("Equivalence failed for ", output)
    append_row(data.frame(protocol_version = V2_PROTOCOL_VERSION, n_records = item$n_records,
      repetition = item$repetition, random_order = item$random_order, implementation = item$implementation,
      workers = item$workers, timing_region = "end_to_end", inner_loops = 1L,
      elapsed_sec = execution$elapsed, throughput_profiles_sec = item$n_records / execution$elapsed,
      equivalence_passed = comparison$pass, max_abs_pbio_diff = comparison$max_abs_pbio_diff,
      max_abs_rcs_diff = comparison$max_abs_rcs_diff, identical_final_grade = comparison$identical_grade,
      identical_grade_route = comparison$identical_route, stringsAsFactors = FALSE))
  }
}

capture <- function(command, args = character()) {
  if (!nzchar(Sys.which(command))) return(paste(command, "not found"))
  paste(system2(command, args, stdout = TRUE, stderr = TRUE), collapse = " | ")
}
environment <- c(
  paste("Protocol version:", V2_PROTOCOL_VERSION), paste("Date:", Sys.time()),
  paste("Git commit:", capture("git", c("rev-parse", "HEAD"))), paste("R:", R.version.string),
  paste("Python:", capture("python3", "--version")), paste("NumPy:", capture("python3", c("-c", shQuote("import numpy; print(numpy.__version__)")))),
  paste("C++:", capture("g++", "--version")), paste("CUDA:", capture("nvcc", "--version")),
  paste("GPU:", capture("nvidia-smi", c("--query-gpu=name,driver_version,memory.total", "--format=csv,noheader"))),
  paste("OS:", paste(Sys.info(), collapse = " ")), paste("Data seed:", V2_DATA_SEED),
  paste("Order seed:", V2_ORDER_SEED), paste("Repetitions:", V2_REPS),
  paste("Minimum calibrated sample seconds:", V2_MIN_SAMPLE_SEC),
  paste("Process workers:", paste(V2_PROCESS_WORKERS, collapse = ",")),
  paste("OpenMP threads:", paste(V2_OPENMP_THREADS, collapse = ",")),
  "C++ flags: -std=c++17 -O3 -DNDEBUG -march=native",
  "OpenMP flags: -std=c++17 -O3 -DNDEBUG -march=native -fopenmp",
  "CUDA flags: -std=c++17 -O3 -Xcompiler -march=native",
  paste("OMP_PROC_BIND:", Sys.getenv("OMP_PROC_BIND", unset = "not set")),
  paste("OMP_PLACES:", Sys.getenv("OMP_PLACES", unset = "not set")),
  paste("OPENBLAS_NUM_THREADS:", Sys.getenv("OPENBLAS_NUM_THREADS", unset = "not set")))
writeLines(environment, file.path(V2_LOGS, "Computational_Environment_V2.txt"))
cat("Benchmark V2 raw execution completed successfully.\n")

