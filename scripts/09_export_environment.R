source(file.path("scripts", "01_config_utils.R"))
log_message("Exporting computational environment")

sink(file.path(DIR_LOGS, "SessionInfo_RCS_validation.txt"))
print(sessionInfo())
sink()

env_lines <- c(
  paste("Date:", Sys.time()),
  paste("R version:", R.version.string),
  paste("Working directory:", getwd()),
  paste("RUN_LARGE_BENCH:", Sys.getenv("RUN_LARGE_BENCH", unset = "FALSE")),
  paste("BENCH_REPS:", Sys.getenv("BENCH_REPS", unset = "3")),
  paste("RCS_SEED:", RCS_SEED)
)
write_log_text(env_lines, "Computational_Environment.txt")
log_message("Computational environment exported")
