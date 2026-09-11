#!/usr/bin/env Rscript

start_time <- Sys.time()
cat("Starting RCS validation pipeline...\n")
cat("Working directory:", getwd(), "\n")

if (!file.exists(file.path("scripts", "02_model.R"))) {
  stop("Run this script from the repository root.")
}

source(file.path("scripts", "03_property_checks.R"))
source(file.path("scripts", "04_synthetic_validation.R"))
source(file.path("scripts", "05_combinatorial_threshold_oat_governance.R"))
source(file.path("scripts", "06_sensitivity_ablation.R"))
source(file.path("scripts", "07_export_environment.R"))

run_benchmark <- toupper(Sys.getenv("RUN_BENCHMARK", unset = "FALSE")) == "TRUE"
if (run_benchmark) {
  source(file.path("scripts", "run_benchmark.R"))
}

end_time <- Sys.time()
cat("Pipeline completed successfully.\n")
cat("Elapsed time:", as.numeric(difftime(end_time, start_time, units = "secs")), "seconds\n")
