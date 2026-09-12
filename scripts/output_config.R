#!/usr/bin/env Rscript

rcs_bool_env <- function(name, default = FALSE) {
  value <- toupper(Sys.getenv(name, unset = if (default) "TRUE" else "FALSE"))
  if (!value %in% c("TRUE", "FALSE")) stop(name, " must be TRUE or FALSE.")
  value == "TRUE"
}

rcs_normalize_guard_path <- function(path) {
  normalized <- normalizePath(path.expand(path), winslash = "/", mustWork = FALSE)
  normalized <- sub("/+$", "", normalized)
  if (.Platform$OS.type == "windows") tolower(normalized) else normalized
}

rcs_path_is_within <- function(path, protected_root) {
  identical(path, protected_root) || startsWith(path, paste0(protected_root, "/"))
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

resolved_output_root <- rcs_normalize_guard_path(RCS_OUTPUT_ROOT)
protected_publication_root <- rcs_normalize_guard_path(file.path("results", "publication"))
if (rcs_path_is_within(resolved_output_root, protected_publication_root) &&
    !RCS_ALLOW_PUBLICATION_WRITE) {
  stop(
    "Publication output is protected. RCS_OUTPUT_ROOT resolves inside results/publication; ",
    "set RCS_ALLOW_PUBLICATION_WRITE=TRUE only for the deliberate final publication run."
  )
}

RCS_TABLES_DIR <- file.path(RCS_OUTPUT_ROOT, "tables")
RCS_ENVIRONMENT_DIR <- file.path(RCS_OUTPUT_ROOT, "environment")
RCS_FIGURES_DIR <- file.path(RCS_OUTPUT_ROOT, "figures")

invisible(lapply(
  c(RCS_OUTPUT_ROOT, RCS_TABLES_DIR, RCS_ENVIRONMENT_DIR, RCS_FIGURES_DIR),
  dir.create, recursive = TRUE, showWarnings = FALSE
))
