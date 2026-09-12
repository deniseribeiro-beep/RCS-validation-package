source(file.path("scripts", "output_config.R"))

required_packages <- c("dplyr", "tidyr", "purrr", "readr", "stringr", "tibble")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop(
    "Missing required scientific-validation R packages: ",
    paste(missing_packages, collapse = ", ")
  )
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readr)
  library(stringr)
  library(tibble)
})

RCS_SEED <- as.integer(Sys.getenv("RCS_SEED", unset = "20260504"))
if (is.na(RCS_SEED)) stop("RCS_SEED must be an integer.")
set.seed(RCS_SEED)

DIR_TABLES <- RCS_TABLES_DIR
DIR_LOGS <- RCS_ENVIRONMENT_DIR

log_message <- function(msg) {
  cat(sprintf("%s | %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
}

safe_write_csv <- function(x, filename) {
  readr::write_csv(x, file.path(DIR_TABLES, filename))
}

write_log_text <- function(lines, filename) {
  writeLines(lines, file.path(DIR_LOGS, filename))
}
