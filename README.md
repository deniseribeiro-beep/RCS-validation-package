# Ribeiro Classification Score (RCS) validation package

This repository contains the reproducibility package for the governance-aware,
rule-based Ribeiro Classification Score (RCS) described in the manuscript
*A Governance-Aware Rule-Based Computational Framework for Biospecimen
Qualification in Biobank Information Systems*.

## What the pipeline validates

- non-compensable governance admissibility;
- matrix-specific SPREC-derived weighted penalties;
- the identity `RCS = 100 - P_bio`;
- deterministic A-E grade thresholds;
- property-based logical behaviour;
- synthetic internal validation and threshold margins;
- governance-failure sensitivity;
- combinatorial coverage and one-axis transitions;
- global sensitivity, weight perturbation, and ablation;
- sequential runtime scalability;
- optional deterministic-equivalence and persistent-cluster benchmark.

Unknown, missing, invalid, incompatible, or `Not scored` conditions are never
converted to zero severity. They invalidate governance/context admissibility.

## Requirements

- R 4.2.2 or newer;
- packages: `dplyr`, `tidyr`, `purrr`, `ggplot2`, `readr`, `stringr`,
  `scales`, `tibble`, `forcats`, `broom`, and `patchwork`.

Check the environment before execution:

```bash
Rscript validation/environment/00_check_environment.R
```

## Reproduce the main validation

From the repository root:

```bash
RUN_LARGE_BENCH=TRUE BENCH_REPS=5 RCS_SEED=20260504 \
  Rscript scripts/run_all.R
```

The main run generates Figures 2-5 as vector PDF and 600-dpi PNG files.
Figures use publication-scale dimensions and enlarged typography so labels
remain readable after insertion into the manuscript.

## Reproduce the parallel benchmark

```bash
RUN_LARGE_BENCH=TRUE BENCH_REPS=5 RUN_PARALLEL_BENCH=TRUE \
RCS_PARALLEL_WORKERS=4 RCS_SEED=20260504 \
  Rscript scripts/run_all.R
```

Runtime values are environment-specific and must be updated in the manuscript
after the final run. Deterministic scores, grades, and routes must remain
identical between sequential and parallel execution.

## Repository structure

```text
scripts/                         Validation and figure-generation scripts
outputs/figures/                 Main manuscript figures
outputs/tables/figure_source/    Machine-readable figure source tables
outputs/tables/supplementary/    Supplementary validation outputs
validation/environment/          Session and environment records
docs/                            Crosswalk and validation documentation
```
