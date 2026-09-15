#!/usr/bin/env Rscript

required <- c(
  dplyr = "1.2.1",
  tidyr = "1.3.2",
  purrr = "1.2.2",
  readr = "2.2.0",
  stringr = "1.6.0",
  tibble = "3.3.1"
)

repos <- getOption("repos")
if (is.null(repos) || identical(unname(repos[["CRAN"]]), "@CRAN@")) {
  repos["CRAN"] <- "https://cloud.r-project.org"
  options(repos = repos)
}

if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}

for (package in names(required)) {
  expected <- unname(required[[package]])
  installed <- if (requireNamespace(package, quietly = TRUE)) {
    as.character(utils::packageVersion(package))
  } else {
    NA_character_
  }

  if (!identical(installed, expected)) {
    message("Installing ", package, " ", expected)
    remotes::install_version(package, version = expected, upgrade = "never")
  }
}

observed <- vapply(names(required), function(package) {
  as.character(utils::packageVersion(package))
}, character(1))

if (!identical(unname(observed), unname(required))) {
  stop("Resolved R package versions do not match requirements-r.txt.")
}

message("Pinned R dependencies installed successfully.")
