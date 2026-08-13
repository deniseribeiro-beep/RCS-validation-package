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
source(file.path("scripts", "07_runtime_benchmark.R"))
source(file.path("scripts", "08_generate_main_figures.R"))
source(file.path("scripts", "09_export_environment.R"))

run_cross_language <- toupper(Sys.getenv("RUN_CROSS_LANGUAGE_BENCH", unset = "FALSE")) == "TRUE"
run_parallel <- toupper(Sys.getenv("RUN_PARALLEL_BENCH", unset = "FALSE")) == "TRUE"
if (run_cross_language) {
  source(file.path("scripts", "12_generate_cross_language_inputs.R"))
  source(file.path("scripts", "11_generate_parallel_benchmark_outputs.R"))
  source(file.path("scripts", "13_run_cross_language_benchmark.R"))
  source(file.path("scripts", "14_generate_cross_language_outputs.R"))
} else if (run_parallel) {
  source(file.path("scripts", "10_parallel_runtime_benchmark.R"))
  source(file.path("scripts", "11_generate_parallel_benchmark_outputs.R"))
}

end_time <- Sys.time()
cat("Pipeline completed successfully.\n")
cat("Elapsed time:", as.numeric(difftime(end_time, start_time, units = "secs")), "seconds\n")
