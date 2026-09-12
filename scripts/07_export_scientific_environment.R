#!/usr/bin/env Rscript

source(file.path("scripts", "01_config_utils.R"))
log_message("Exporting scientific-validation environment")

capture_command <- function(command, args = character()) {
  if (!nzchar(Sys.which(command))) return(paste(command, "not found"))
  paste(system2(command, args, stdout = TRUE, stderr = TRUE), collapse = " | ")
}

scientific_packages <- c("dplyr", "tidyr", "purrr", "readr", "stringr", "tibble")
package_lines <- vapply(scientific_packages, function(package) {
  version <- if (requireNamespace(package, quietly = TRUE)) as.character(utils::packageVersion(package)) else "MISSING"
  paste0("R package ", package, ": ", version)
}, character(1))

sink(file.path(DIR_LOGS, "SessionInfo_Scientific_Validation.txt"))
print(sessionInfo())
sink()

env_lines <- c(
  paste("Environment profile: scientific-validation"),
  paste("Date:", Sys.time()),
  paste("Git commit:", capture_command("git", c("rev-parse", "HEAD"))),
  paste("R:", R.version.string),
  paste("C compiler:", capture_command("cc", "--version")),
  paste("make:", capture_command("make", "--version")),
  paste("OS:", paste(Sys.info(), collapse = " ")),
  paste("RCS seed:", RCS_SEED),
  package_lines
)
write_log_text(env_lines, "Scientific_Validation_Environment.txt")
log_message("Scientific-validation environment exported")
