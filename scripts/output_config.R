#!/usr/bin/env Rscript

rcs_bool_env <- function(name, default = FALSE) {
  value <- toupper(Sys.getenv(name, unset = if (default) "TRUE" else "FALSE"))
  if (!value %in% c("TRUE", "FALSE")) stop(name, " must be TRUE or FALSE.")
  value == "TRUE"
}

RCS_RUN_SCOPE <- tolower(Sys.getenv("RCS_RUN_SCOPE", unset = "local"))
if (!RCS_RUN_SCOPE %in% c("local", "smoke", "publication"))
  stop("RCS_RUN_SCOPE must be one of: local, smoke, publication.")

RCS_ALLOW_PUBLICATION_WRITE <- rcs_bool_env("RCS_ALLOW_PUBLICATION_WRITE", FALSE)
if (RCS_RUN_SCOPE == "publication" && !RCS_ALLOW_PUBLICATION_WRITE)
  stop("Publication output is protected. Set RCS_ALLOW_PUBLICATION_WRITE=TRUE only for the deliberate final publication run.")

root_override <- Sys.getenv("RCS_OUTPUT_ROOT", unset = "")
RCS_OUTPUT_ROOT <- if (nzchar(root_override)) {
  root_override
} else switch(
  RCS_RUN_SCOPE,
  local = file.path("outputs", "local"),
  smoke = file.path("outputs", "smoke"),
  publication = file.path("results", "publication")
)

RCS_TABLES_DIR <- file.path(RCS_OUTPUT_ROOT, "tables")
RCS_ENVIRONMENT_DIR <- file.path(RCS_OUTPUT_ROOT, "environment")
RCS_FIGURES_DIR <- file.path(RCS_OUTPUT_ROOT, "figures")

invisible(lapply(
  c(RCS_OUTPUT_ROOT, RCS_TABLES_DIR, RCS_ENVIRONMENT_DIR, RCS_FIGURES_DIR),
  dir.create, recursive = TRUE, showWarnings = FALSE
))
