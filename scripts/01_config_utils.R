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
    ". Run validation/environment/00_check_environment.R for installation guidance."
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
DIR_FIGURES <- file.path("outputs", "figures")
DIR_LOGS <- file.path("validation", "environment")
dir.create(DIR_TABLES, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_FIGURES, recursive = TRUE, showWarnings = FALSE)
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

fig_w_full <- 9.0
fig_h_standard <- 6.2
fig_h_tall <- 7.0

rcs_cols <- c(
  "Grade A" = "#D0E2FF",
  "Grade B" = "#BAE6FF",
  "Grade C" = "#E8DAFF",
  "Grade D" = "#FFD6A8",
  "Grade E" = "#FFD7D9"
)

matrix_cols <- c("fluid" = "#78A9FF", "solid" = "#BE95FF")
line_col <- "#525252"
text_col <- "#262626"

clean_axis_label <- function(x) {
  x |>
    stringr::str_replace_all("^P_", "") |>
    stringr::str_replace_all("_", " ") |>
    stringr::str_to_title()
}

theme_rcs <- function(base_size = 13) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = element_text(face = "bold", hjust = 0, size = base_size + 1, color = text_col),
      plot.subtitle = element_text(size = base_size, color = text_col),
      axis.title = element_text(size = base_size, color = text_col),
      axis.text = element_text(size = base_size - 1, color = text_col),
      strip.text = element_text(face = "bold", size = base_size, color = text_col),
      legend.title = element_text(size = base_size, color = text_col),
      legend.text = element_text(size = base_size - 1, color = text_col),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_line(linewidth = 0.25, color = "#E0E0E0"),
      panel.grid.major.y = element_line(linewidth = 0.25, color = "#E0E0E0"),
      plot.margin = margin(8, 12, 8, 8)
    )
}

save_main_figure <- function(plot, name, width = fig_w_full, height = fig_h_standard) {
  pdf_device <- if (capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf
  ggplot2::ggsave(file.path(DIR_FIGURES, paste0(name, ".pdf")), plot, width = width, height = height, device = pdf_device, bg = "white")
  ggplot2::ggsave(file.path(DIR_FIGURES, paste0(name, ".png")), plot, width = width, height = height, dpi = 600, bg = "white")
}
