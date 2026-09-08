#!/usr/bin/env Rscript

source(file.path("benchmark_v2", "config.R"))
source(file.path("benchmark_v2", "common.R"))

set.seed(V2_DATA_SEED)
manifest <- lapply(V2_WORKLOADS, function(n) {
  stem <- sprintf("n%08d", n)
  input <- file.path(V2_INPUTS, paste0(stem, "_input.bin"))
  expected <- file.path(V2_EXPECTED, paste0(stem, "_expected.bin"))
  matrix_code <- rep(c(0L, 1L), length.out = n)
  severity <- matrix(stats::runif(n * 10L), nrow = n, ncol = 10L)
  # Governance failures are deterministic and sufficiently represented while
  # preserving the same scoring workload for all implementations.
  governance <- as.integer((seq_len(n) %% 20L) != 0L)
  profiles <- list(n = n, matrix = matrix_code, governance = governance, severity = severity)
  v2_write_profiles(profiles, input)
  v2_write_results(v2_score_core(profiles), expected)
  data.frame(n_records = n, input_file = input, expected_file = expected, stringsAsFactors = FALSE)
})
manifest <- do.call(rbind, manifest)
write.csv(manifest, file.path(V2_ROOT, "Input_Manifest.csv"), row.names = FALSE)
cat("Prepared", nrow(manifest), "canonical V2 workloads in", V2_INPUTS, "\n")

