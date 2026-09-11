#!/usr/bin/env Rscript

source(file.path("scripts", "benchmark_config.R"))
source(file.path("scripts", "benchmark_common.R"))

set.seed(BENCHMARK_DATA_SEED)
manifest <- lapply(BENCHMARK_WORKLOADS, function(n) {
  stem <- sprintf("n%08d", n)
  input <- file.path(BENCHMARK_INPUTS, paste0(stem, "_input.bin"))
  expected <- file.path(BENCHMARK_EXPECTED, paste0(stem, "_expected.bin"))
  matrix_code <- rep(c(0L, 1L), length.out = n)
  severity <- matrix(stats::runif(n * 10L), nrow = n, ncol = 10L)
  governance <- as.integer((seq_len(n) %% 20L) != 0L)
  profiles <- list(n = n, matrix = matrix_code, governance = governance, severity = severity)
  benchmark_write_profiles(profiles, input)
  benchmark_write_results(benchmark_score_core(profiles), expected)
  data.frame(n_records = n, input_file = input, expected_file = expected, stringsAsFactors = FALSE)
})
manifest <- do.call(rbind, manifest)
write.csv(manifest, file.path(BENCHMARK_WORK_ROOT, "Input_Manifest.csv"), row.names = FALSE)
cat("Prepared", nrow(manifest), "canonical benchmark workloads in", BENCHMARK_INPUTS, "\n")
