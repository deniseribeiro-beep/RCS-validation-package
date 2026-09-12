#!/usr/bin/env Rscript

source(file.path("scripts", "benchmark_config.R"))
source(file.path("scripts", "benchmark_common.R"))

status_ok <- function(x) is.null(attr(x, "status")) || identical(attr(x, "status"), 0L)
run_command <- function(command, args, timed = FALSE) {
  log <- tempfile("benchmark-engine-")
  on.exit(unlink(log), add = TRUE)
  start <- proc.time()[["elapsed"]]
  status <- system2(command, args, stdout = log, stderr = log)
  elapsed <- proc.time()[["elapsed"]] - start
  text <- if (file.exists(log)) readLines(log, warn = FALSE) else character()
  if (!identical(status, 0L)) stop("Command failed (", status, "): ", command, "\n", paste(text, collapse = "\n"))
  list(text = text, elapsed = if (timed) elapsed else NA_real_)
}

compile_native <- function() {
  cc <- Sys.which("cc")
  if (!nzchar(cc)) stop("A C compiler (cc) is required for the computational reference benchmark.")
  if (!nzchar(Sys.which("g++"))) stop("g++ is required for the C++ benchmark implementations.")

  c_ref_bin <- file.path(BENCHMARK_BIN, "rcs_c_reference")
  cpp_seq_bin <- file.path(BENCHMARK_BIN, "rcs_cpp_sequential")
  cpp_omp_bin <- file.path(BENCHMARK_BIN, "rcs_cpp_openmp")

  run_command(cc, c(
    "-std=c11", "-O3", "-DNDEBUG", "-march=native", "-Iinclude",
    "src/rcs_reference.c", "src/rcs_c_reference_benchmark.c", "-lm", "-o", c_ref_bin
  ))
  run_command("g++", c(
    "-std=c++17", "-O3", "-DNDEBUG", "-march=native",
    "src/rcs_sequential.cpp", "-o", cpp_seq_bin
  ))
  run_command("g++", c(
    "-std=c++17", "-O3", "-DNDEBUG", "-march=native", "-fopenmp",
    "src/rcs_openmp.cpp", "-o", cpp_omp_bin
  ))

  cuda_bin <- file.path(BENCHMARK_BIN, "rcs_cuda")
  if (BENCHMARK_RUN_CUDA) {
    if (!nzchar(Sys.which("nvcc"))) stop("BENCHMARK_RUN_CUDA=TRUE but nvcc was not found.")
    run_command("nvcc", c(
      "-std=c++17", "-O3", "-Xcompiler", "-march=native",
      "src/rcs_cuda.cu", "-o", cuda_bin
    ))
  }

  list(
    c_reference = c_ref_bin,
    cpp_sequential = cpp_seq_bin,
    cpp_openmp = cpp_omp_bin,
    cpp_cuda = cuda_bin
  )
}

compile_cython <- function() {
  if (!BENCHMARK_RUN_PYTHON) return(invisible(NULL))
  check <- system2("python3", c("-c", shQuote("import numpy, Cython, setuptools; print(Cython.__version__)")), stdout = TRUE, stderr = TRUE)
  if (!status_ok(check)) stop("Python NumPy, Cython, and setuptools are required.")
  run_command("python3", c(
    file.path("scripts", "setup_cython.py"), "build_ext",
    "--build-lib", file.path("scripts"),
    "--build-temp", file.path(BENCHMARK_BIN, "cython_build")
  ))
}

if (BENCHMARK_RUN_PYTHON) {
  if (!nzchar(Sys.which("python3"))) stop("python3 is required when BENCHMARK_RUN_PYTHON=TRUE.")
  check <- system2("python3", c("-c", shQuote("import numpy; print(numpy.__version__)")), stdout = TRUE, stderr = TRUE)
  if (!status_ok(check)) stop("Python NumPy is required.")
}

bins <- compile_native()
compile_cython()
source(file.path("scripts", "benchmark_prepare_inputs.R"))
manifest <- read.csv(file.path(BENCHMARK_WORK_ROOT, "Input_Manifest.csv"), stringsAsFactors = FALSE)

# The C reference implementation is the sole generator of expected benchmark
# outputs. Every R/Cython/C++/CUDA result is compared against these files.
for (i in seq_len(nrow(manifest))) {
  run_command(bins$c_reference, c(
    "--input", manifest$input_file[[i]],
    "--output", manifest$expected_file[[i]],
    "--implementation", "c_reference",
    "--workers", "1",
    "--warmups", "0",
    "--min-sec", "0.01",
    "--max-loops", "1",
    "--mode", "e2e"
  ))
}

engines <- data.frame(
  implementation = c("c_reference", "r_sequential", "cpp_sequential"),
  workers = c(1L, 1L, 1L),
  family = c("c_reference", "r", "cpp"),
  stringsAsFactors = FALSE
)
engines <- rbind(
  engines,
  data.frame(implementation = "r_psock", workers = BENCHMARK_PROCESS_WORKERS, family = "r"),
  data.frame(implementation = "cpp_openmp", workers = BENCHMARK_OPENMP_THREADS, family = "cpp")
)
if (BENCHMARK_RUN_PYTHON) engines <- rbind(
  engines,
  data.frame(implementation = "cython_sequential", workers = 1L, family = "python_cython"),
  data.frame(implementation = "cython_openmp", workers = BENCHMARK_OPENMP_THREADS, family = "python_cython")
)
if (BENCHMARK_RUN_CUDA) engines <- rbind(
  engines, data.frame(implementation = "cpp_cuda", workers = 1L, family = "cuda")
)
rownames(engines) <- NULL

schedule <- merge(expand.grid(n_records = manifest$n_records, repetition = seq_len(BENCHMARK_REPS)), engines, all = TRUE)
set.seed(BENCHMARK_ORDER_SEED)
schedule$random_order <- ave(
  seq_len(nrow(schedule)), interaction(schedule$n_records, schedule$repetition),
  FUN = function(i) sample.int(length(i))
)
schedule <- schedule[order(schedule$repetition, schedule$n_records, schedule$random_order), ]
write.csv(schedule, file.path(BENCHMARK_WORK_ROOT, "Randomized_Execution_Schedule.csv"), row.names = FALSE)

raw_path <- file.path(BENCHMARK_TABLES, "Table_Benchmark_Runtime_Raw.csv")
raw <- if (BENCHMARK_RESUME && file.exists(raw_path)) read.csv(raw_path, stringsAsFactors = FALSE) else data.frame()
required_raw_columns <- c(
  "read_sec", "initialization_sec", "classification_sec", "write_sec", "internal_total_sec",
  "process_overhead_sec", "cuda_h2d_sec", "cuda_d2h_sec", "cuda_host_prepare_sec",
  "cuda_device_setup_sec", "cuda_kernel_sec", "cuda_device_teardown_sec",
  "cuda_host_finalize_sec", "cuda_disk_write_sec", "measurement_block_sec",
  "minimum_block_sec", "calibration_floor_passed", "calibration_attempts"
)
if (nrow(raw) && !all(required_raw_columns %in% names(raw)))
  stop("BENCHMARK_RESUME cannot reuse results with an incompatible schema.")

completed_key <- function(implementation, workers, n_records, repetition, timing_region) {
  if (!nrow(raw)) return(FALSE)
  any(raw$implementation == implementation & raw$workers == workers & raw$n_records == n_records &
        raw$repetition == repetition & raw$timing_region == timing_region)
}

engine_command <- function(implementation) {
  if (implementation == "c_reference") return(c(unname(bins$c_reference)))
  if (implementation %in% c("r_sequential", "r_psock")) return(c("Rscript", file.path("scripts", "r_engine.R")))
  if (implementation %in% c("cython_sequential", "cython_openmp")) return(c("python3", file.path("scripts", "python_engine.py")))
  c(unname(bins[[implementation]]))
}

parse_phases <- function(text) {
  line <- tail(grep("^RCSPHASES,", text, value = TRUE), 1L)
  if (!length(line)) stop("Engine did not emit an RCSPHASES record:\n", paste(text, collapse = "\n"))
  fields <- as.numeric(strsplit(line, ",", fixed = TRUE)[[1]][-1L])
  names(fields) <- c("read_sec", "initialization_sec", "classification_sec", "write_sec", "internal_total_sec")
  as.list(fields)
}

parse_cuda <- function(text) {
  values <- setNames(as.list(rep(NA_real_, 8L)), c(
    "host_prepare_sec", "device_setup_sec", "h2d_sec", "kernel_sec", "d2h_sec",
    "device_teardown_sec", "host_finalize_sec", "disk_write_sec"
  ))
  line <- tail(grep("^RCSCUDA,", text, value = TRUE), 1L)
  if (!length(line)) return(values)
  fields <- as.numeric(strsplit(line, ",", fixed = TRUE)[[1]][-1L])
  if (length(fields) != 8L || any(!is.finite(fields))) stop("Invalid RCSCUDA record: ", line)
  as.list(setNames(fields, names(values)))
}

parse_compute <- function(text) {
  line <- tail(grep("^RCSRESULT,", text, value = TRUE), 1L)
  if (!length(line)) stop("Engine did not emit an RCSRESULT record:\n", paste(text, collapse = "\n"))
  fields <- strsplit(line, ",", fixed = TRUE)[[1]]
  if (length(fields) != 9L) stop("Invalid RCSRESULT compute record: ", line)
  parsed <- list(
    inner_loops = as.integer(fields[[5]]), elapsed = as.numeric(fields[[6]]),
    block_seconds = as.numeric(fields[[7]]), floor_passed = identical(fields[[8]], "TRUE"),
    calibration_attempts = as.integer(fields[[9]])
  )
  if (any(!is.finite(unlist(parsed[c("inner_loops", "elapsed", "block_seconds", "calibration_attempts")]))) ||
      parsed$inner_loops < 1L || parsed$elapsed <= 0 || parsed$block_seconds <= 0)
    stop("Invalid calibrated measurement: ", line)
  parsed
}

append_row <- function(row) {
  raw <<- if (!nrow(raw)) row else rbind(raw, row)
  write.csv(raw, raw_path, row.names = FALSE)
}

for (i in seq_len(nrow(schedule))) {
  item <- schedule[i, ]
  files <- manifest[manifest$n_records == item$n_records, ]
  expected <- benchmark_read_results(files$expected_file)
  command_spec <- engine_command(item$implementation)
  command <- command_spec[[1]]
  prefix_args <- command_spec[-1]
  warmups <- if (item$implementation == "cpp_cuda") BENCHMARK_WARMUP_CUDA else if (
    item$workers > 1L || item$implementation %in% c("r_psock", "cython_openmp", "cpp_openmp")
  ) BENCHMARK_WARMUP_PARALLEL else BENCHMARK_WARMUP_CPU
  base_args <- c(
    prefix_args, "--input", files$input_file, "--implementation", item$implementation,
    if (item$family %in% c("cpp", "python_cython")) "--threads" else "--workers", item$workers,
    "--warmups", warmups, "--min-sec", BENCHMARK_MIN_SAMPLE_SEC,
    "--max-loops", BENCHMARK_MAX_INNER_LOOPS
  )
  message(sprintf("Benchmark block rep=%d n=%d implementation=%s workers=%d",
                  item$repetition, item$n_records, item$implementation, item$workers))

  if (!completed_key(item$implementation, item$workers, item$n_records, item$repetition, "compute")) {
    output <- file.path(BENCHMARK_RESULTS, sprintf(
      "compute_%s_w%02d_n%08d_rep%02d.bin", item$implementation, item$workers, item$n_records, item$repetition
    ))
    execution <- run_command(command, c(base_args, "--output", output, "--mode", "compute"))
    parsed <- parse_compute(execution$text)
    comparison <- benchmark_compare_results(expected, benchmark_read_results(output))
    if (!comparison$pass) stop("C-reference equivalence failed for ", output)
    append_row(data.frame(
      n_records = item$n_records, repetition = item$repetition, random_order = item$random_order,
      implementation = item$implementation, workers = item$workers, timing_region = "compute",
      inner_loops = parsed$inner_loops, elapsed_sec = parsed$elapsed,
      throughput_profiles_sec = item$n_records / parsed$elapsed,
      measurement_block_sec = parsed$block_seconds, minimum_block_sec = BENCHMARK_MIN_SAMPLE_SEC,
      calibration_floor_passed = parsed$floor_passed, calibration_attempts = parsed$calibration_attempts,
      read_sec = NA_real_, initialization_sec = NA_real_, classification_sec = parsed$elapsed,
      write_sec = NA_real_, internal_total_sec = NA_real_, process_overhead_sec = NA_real_,
      cuda_host_prepare_sec = NA_real_, cuda_device_setup_sec = NA_real_, cuda_h2d_sec = NA_real_,
      cuda_kernel_sec = if (item$implementation == "cpp_cuda") parsed$elapsed else NA_real_,
      cuda_d2h_sec = NA_real_, cuda_device_teardown_sec = NA_real_, cuda_host_finalize_sec = NA_real_,
      cuda_disk_write_sec = NA_real_, equivalence_passed = comparison$pass,
      max_abs_pbio_diff = comparison$max_abs_pbio_diff, max_abs_rcs_diff = comparison$max_abs_rcs_diff,
      identical_final_grade = comparison$identical_grade, identical_grade_route = comparison$identical_route,
      stringsAsFactors = FALSE
    ))
  }

  if (!completed_key(item$implementation, item$workers, item$n_records, item$repetition, "end_to_end")) {
    output <- file.path(BENCHMARK_RESULTS, sprintf(
      "e2e_%s_w%02d_n%08d_rep%02d.bin", item$implementation, item$workers, item$n_records, item$repetition
    ))
    execution <- run_command(command, c(base_args, "--output", output, "--mode", "e2e"), timed = TRUE)
    phases <- parse_phases(execution$text)
    cuda <- parse_cuda(execution$text)
    if (item$implementation == "cpp_cuda" && is.na(cuda$kernel_sec)) stop("CUDA engine did not emit phase details.")
    comparison <- benchmark_compare_results(expected, benchmark_read_results(output))
    if (!comparison$pass) stop("C-reference equivalence failed for ", output)
    append_row(data.frame(
      n_records = item$n_records, repetition = item$repetition, random_order = item$random_order,
      implementation = item$implementation, workers = item$workers, timing_region = "end_to_end",
      inner_loops = 1L, elapsed_sec = execution$elapsed,
      throughput_profiles_sec = item$n_records / execution$elapsed,
      measurement_block_sec = NA_real_, minimum_block_sec = NA_real_, calibration_floor_passed = NA,
      calibration_attempts = NA_integer_, read_sec = phases$read_sec,
      initialization_sec = phases$initialization_sec, classification_sec = phases$classification_sec,
      write_sec = phases$write_sec, internal_total_sec = phases$internal_total_sec,
      process_overhead_sec = max(0, execution$elapsed - phases$internal_total_sec),
      cuda_host_prepare_sec = cuda$host_prepare_sec, cuda_device_setup_sec = cuda$device_setup_sec,
      cuda_h2d_sec = cuda$h2d_sec, cuda_kernel_sec = cuda$kernel_sec, cuda_d2h_sec = cuda$d2h_sec,
      cuda_device_teardown_sec = cuda$device_teardown_sec, cuda_host_finalize_sec = cuda$host_finalize_sec,
      cuda_disk_write_sec = cuda$disk_write_sec, equivalence_passed = comparison$pass,
      max_abs_pbio_diff = comparison$max_abs_pbio_diff, max_abs_rcs_diff = comparison$max_abs_rcs_diff,
      identical_final_grade = comparison$identical_grade, identical_grade_route = comparison$identical_route,
      stringsAsFactors = FALSE
    ))
  }
}

cat("Benchmark raw execution completed with C-reference equivalence enforced.\n")
