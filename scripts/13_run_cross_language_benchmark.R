#!/usr/bin/env Rscript

# Compile and run C++ sequential, C++/OpenMP, and C++/CUDA on the exact
# canonical inputs emitted by script 12. CUDA total time is the primary metric.
source(file.path("scripts", "01_config_utils.R"))
artifact_dir <- file.path("outputs", "cross_language")
raw_r_path <- file.path(artifact_dir, "R_Canonical_Runtime_Raw.csv")
if (!file.exists(raw_r_path)) stop("Run scripts/12_generate_cross_language_inputs.R first.")

threads <- as.integer(Sys.getenv("RCS_OPENMP_THREADS", unset = "4"))
run_cuda <- toupper(Sys.getenv("RUN_CUDA_BENCH", unset = "TRUE")) == "TRUE"
dir.create(file.path(artifact_dir, "bin"), recursive = TRUE, showWarnings = FALSE)

compile <- function(command, args) {
  status <- system2(command, args, stdout = TRUE, stderr = TRUE)
  if (!identical(attr(status, "status"), NULL) && attr(status, "status") != 0L)
    stop(paste(status, collapse = "\n"))
}
cpp_bin <- file.path(artifact_dir, "bin", "rcs_sequential")
omp_bin <- file.path(artifact_dir, "bin", "rcs_openmp")
cuda_bin <- file.path(artifact_dir, "bin", "rcs_cuda")
compile("g++", c("-std=c++17", "-O3", "-DNDEBUG", "-march=native", "src/rcs_sequential.cpp", "-o", cpp_bin))
compile("g++", c("-std=c++17", "-O3", "-DNDEBUG", "-march=native", "-fopenmp", "src/rcs_openmp.cpp", "-o", omp_bin))
if (run_cuda) {
  if (!nzchar(Sys.which("nvcc"))) stop("RUN_CUDA_BENCH=TRUE but nvcc was not found.")
  compile("nvcc", c("-std=c++17", "-O3", "-Xcompiler", "-march=native", "src/rcs_cuda.cu", "-o", cuda_bin))
}

read_result <- function(path) {
  con <- file(path, "rb"); on.exit(close(con), add=TRUE)
  expected_header <- c(charToRaw("RCSOUT1"), as.raw(0L))

if (!identical(readBin(con, "raw", 8L), expected_header)) {
  stop("Bad result header: ", path)
}
  n <- readBin(con, "numeric", 1L, size=8L, endian="little")
  pbio <- readBin(con, "numeric", n, size=8L, endian="little")
  rcs <- readBin(con, "numeric", n, size=8L, endian="little")
  grade <- as.integer(readBin(con, "raw", n)); route <- as.integer(readBin(con, "raw", n))
  list(pbio=pbio, rcs=rcs, grade=grade, route=route)
}

run_engine <- function(binary, implementation, row, engine_threads) {
  input <- file.path(artifact_dir, row$input_file)
  output <- file.path(artifact_dir, sprintf("%s_n%07d_rep%02d.bin", implementation, row$n_records, row$rep))
  args <- c("--input", input, "--output", output, "--threads", engine_threads)
  text <- system2(binary, args, stdout=TRUE, stderr=TRUE)
  status <- attr(text, "status"); if (!is.null(status) && status != 0L) stop(paste(text, collapse="\n"))
  fields <- strsplit(tail(text, 1), ",", fixed=TRUE)[[1]]
  expected <- read_result(file.path(artifact_dir, row$expected_file)); observed <- read_result(output)
  eq <- length(expected$pbio) == length(observed$pbio)
  max_p <- if (eq) max(abs(expected$pbio-observed$pbio)) else Inf
  max_r <- if (eq) max(abs(expected$rcs-observed$rcs)) else Inf
  grades <- eq && identical(expected$grade, observed$grade)
  routes <- eq && identical(expected$route, observed$route)
  tibble::tibble(n_records=row$n_records, rep=row$rep, implementation=implementation,
    threads=engine_threads, elapsed_sec=as.numeric(fields[4]),
    kernel_sec=if (length(fields)>=5 && nzchar(fields[5])) as.numeric(fields[5]) else NA_real_,
    max_abs_pbio_diff=max_p, max_abs_rcs_diff=max_r,
    identical_final_grade=grades, identical_grade_route=routes,
    deterministic_equivalence_passed=eq && max_p < 1e-9 && max_r < 1e-9 && grades && routes)
}

r_raw <- readr::read_csv(raw_r_path, show_col_types=FALSE)
engines <- list(list(cpp_bin,"cpp_sequential",1L), list(omp_bin,"cpp_openmp",threads))
if (run_cuda) engines <- c(engines, list(list(cuda_bin,"cpp_cuda",0L)))
inputs <- r_raw |> dplyr::distinct(n_records,rep,input_file,expected_file)
native <- purrr::map_dfr(seq_len(nrow(inputs)), function(i)
  purrr::map_dfr(engines, function(e) run_engine(e[[1]],e[[2]],inputs[i,],e[[3]])))
r_rows <- r_raw |> dplyr::transmute(n_records,rep,implementation,threads,elapsed_sec,kernel_sec,
  max_abs_pbio_diff=0,max_abs_rcs_diff=0,identical_final_grade=TRUE,
  identical_grade_route=TRUE,deterministic_equivalence_passed=TRUE)
raw <- dplyr::bind_rows(r_rows,native)
readr::write_csv(raw,file.path("outputs","tables","Table_Cross_Language_Runtime_Benchmark_Raw.csv"))
summary <- raw |> dplyr::group_by(n_records,implementation,threads) |> dplyr::summarise(
  reps=dplyr::n(),mean_elapsed_sec=mean(elapsed_sec),median_elapsed_sec=median(elapsed_sec),
  sd_elapsed_sec=sd(elapsed_sec),se_elapsed_sec=sd_elapsed_sec/sqrt(reps),
  ci95_elapsed_sec=stats::qt(.975,pmax(reps-1,1))*se_elapsed_sec,
  mean_kernel_sec=if(all(is.na(kernel_sec))) NA_real_ else mean(kernel_sec,na.rm=TRUE),
  all_equivalence_checks_passed=all(deterministic_equivalence_passed),
  max_abs_pbio_diff=max(max_abs_pbio_diff),max_abs_rcs_diff=max(max_abs_rcs_diff),.groups="drop")
readr::write_csv(summary,file.path("outputs","tables","Table_Cross_Language_Runtime_Benchmark_Summary.csv"))
equivalence <- raw |> dplyr::filter(implementation != "r_sequential") |>
  dplyr::group_by(implementation,threads) |> dplyr::summarise(
    benchmark_runs=dplyr::n(),min_n_records=min(n_records),max_n_records=max(n_records),
    all_equivalence_checks_passed=all(deterministic_equivalence_passed),
    max_abs_pbio_diff=max(max_abs_pbio_diff),max_abs_rcs_diff=max(max_abs_rcs_diff),
    all_final_grades_identical=all(identical_final_grade),
    all_grade_routes_identical=all(identical_grade_route),.groups="drop")
readr::write_csv(equivalence,file.path("outputs","tables","Table_Cross_Language_Equivalence_Check.csv"))

capture_version <- function(command,args=character()) {
  if(!nzchar(Sys.which(command))) return(paste(command,"not found"))
  paste(system2(command,args,stdout=TRUE,stderr=TRUE),collapse=" | ")
}
environment <- c(paste("Date:",Sys.time()),paste("R version:",R.version.string),
  paste("Platform:",R.version$platform),paste("OS:",paste(Sys.info(),collapse=" ")),
  paste("RCS_SEED:",RCS_SEED),paste("BENCH_REPS:",Sys.getenv("BENCH_REPS",unset="5")),
  paste("PSOCK workers:",Sys.getenv("RCS_PARALLEL_WORKERS",unset="4")),
  paste("OpenMP threads:",threads),paste("C++ compiler:",capture_version("g++","--version")),
  paste("CUDA compiler:",capture_version("nvcc","--version")),
  paste("NVIDIA GPU:",capture_version("nvidia-smi",c("--query-gpu=name,driver_version","--format=csv,noheader"))),
  "C++ flags: -std=c++17 -O3 -DNDEBUG -march=native",
  "OpenMP flags: -std=c++17 -O3 -DNDEBUG -march=native -fopenmp",
  "CUDA flags: -std=c++17 -O3 -Xcompiler -march=native")
writeLines(environment,file.path("validation","environment","Cross_Language_Computational_Environment.txt"))
if(!all(raw$deterministic_equivalence_passed)) stop("Cross-language deterministic equivalence failed.")
log_message("Cross-language benchmark completed")
