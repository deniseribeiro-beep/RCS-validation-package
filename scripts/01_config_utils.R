required_packages <- c(
  "dplyr", "tidyr", "purrr", "ggplot2", "readr", "stringr",
  "scales", "tibble", "forcats", "broom", "patchwork"
)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop(
    "Missing required R packages: ", paste(missing_packages, collapse = ", "),
    ". Run scripts/00_check_environment.R for installation guidance."
  )
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(readr)
  library(stringr)
  library(scales)
  library(tibble)
  library(forcats)
  library(broom)
})

RCS_SEED <- as.integer(Sys.getenv("RCS_SEED", unset = "20260504"))
if (is.na(RCS_SEED)) stop("RCS_SEED must be an integer.")
set.seed(RCS_SEED)

DIR_TABLES <- file.path("outputs", "tables")
DIR_LOGS <- file.path("outputs", "environment")
dir.create(DIR_TABLES, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_LOGS, recursive = TRUE, showWarnings = FALSE)

log_message <- function(msg) {
  cat(sprintf("%s | %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
}

safe_write_csv <- function(x, filename) {
  readr::write_csv(x, file.path(DIR_TABLES, filename))
}

write_log_text <- function(lines, filename) {
  writeLines(lines, file.path(DIR_LOGS, filename))
}

rcs_cols <- c(
  "Grade A" = "#D0E2FF",
  "Grade B" = "#BAE6FF",
  "Grade C" = "#E8DAFF",
  "Grade D" = "#FFD6A8",
  "Grade E" = "#FFD7D9"
)
