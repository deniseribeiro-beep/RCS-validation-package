#!/usr/bin/env Rscript

required <- c(
  "dplyr", "tidyr", "purrr", "ggplot2", "readr", "stringr",
  "scales", "tibble", "forcats", "broom", "patchwork"
)
available <- vapply(required, requireNamespace, logical(1), quietly = TRUE)

cat("R version:", R.version.string, "\n")
cat("Platform:", R.version$platform, "\n")
cat("OS:", Sys.info()[["sysname"]], Sys.info()[["release"]], "\n")
cat("Logical cores:", parallel::detectCores(logical = TRUE), "\n")
cat("Physical cores:", parallel::detectCores(logical = FALSE), "\n")
cat("Cairo PDF available:", capabilities("cairo"), "\n")
cat("\nRequired packages:\n")
for (i in seq_along(required)) {
  version <- if (available[[i]]) as.character(utils::packageVersion(required[[i]])) else "MISSING"
  cat(sprintf("  %-12s %s\n", required[[i]], version))
}

if (!all(available)) {
  stop(
    "Missing required packages: ",
    paste(required[!available], collapse = ", "),
    "\nInstall them before running the validation pipeline."
  )
}

cat("\nOK: required R packages are installed.\n")
