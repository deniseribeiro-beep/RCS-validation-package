#!/usr/bin/env Rscript

required_r <- c("dplyr", "tidyr", "purrr", "readr", "stringr", "tibble")
available_r <- vapply(required_r, requireNamespace, logical(1), quietly = TRUE)

command_available <- function(command) nzchar(Sys.which(command))

cat("Scientific-validation requirements\n")
cat("R version:", R.version.string, "\n")
cat("Platform:", R.version$platform, "\n")
cat("C compiler (cc):", if (command_available("cc")) unname(Sys.which("cc")) else "MISSING", "\n")
cat("make:", if (command_available("make")) unname(Sys.which("make")) else "MISSING", "\n")
cat("R packages:\n")
for (i in seq_along(required_r)) {
  version <- if (available_r[[i]]) as.character(utils::packageVersion(required_r[[i]])) else "MISSING"
  cat(sprintf("  %-10s %s\n", required_r[[i]], version))
}

missing_tools <- c(
  if (!command_available("cc")) "cc" else character(),
  if (!command_available("make")) "make" else character()
)

if (length(missing_tools)) {
  stop("Missing scientific-validation tools: ", paste(missing_tools, collapse = ", "))
}
if (!all(available_r)) {
  stop("Missing scientific-validation R packages: ", paste(required_r[!available_r], collapse = ", "))
}

cat("Scientific-validation requirements passed.\n")
