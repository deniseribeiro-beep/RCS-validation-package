#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
scope <- if (length(args)) tolower(args[[1]]) else tolower(Sys.getenv("RCS_REQUIREMENT_SCOPE", unset = "scientific"))

allowed <- c("scientific", "benchmark", "all")
if (!scope %in% allowed) {
  stop("Requirement scope must be one of: ", paste(allowed, collapse = ", "), ". Figure requirements are checked by scripts/check_figure_requirements.sh or .cmd.")
}

cat("Requirement scope:", scope, "\n")

if (scope %in% c("scientific", "all")) {
  source(file.path("scripts", "check_scientific_requirements.R"), local = new.env(parent = globalenv()))
}

if (scope %in% c("benchmark", "all")) {
  source(file.path("scripts", "check_benchmark_requirements.R"), local = new.env(parent = globalenv()))
}

cat("Requested requirement checks passed.\n")
