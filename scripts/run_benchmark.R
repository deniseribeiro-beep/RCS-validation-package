#!/usr/bin/env Rscript

source(file.path("scripts", "check_benchmark_requirements.R"), local = new.env(parent = globalenv()))
source(file.path("scripts", "benchmark_run.R"))
source(file.path("scripts", "benchmark_analyze.R"))
source(file.path("scripts", "07_export_environment.R"))
