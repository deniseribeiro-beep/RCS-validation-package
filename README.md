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

## Reproduce the aligned cross-language benchmark

This full run regenerates the R sequential/PSOCK results and Figure 6, then
evaluates C++ sequential, C++/OpenMP, and C++/CUDA on the exact same serialized
profiles. CUDA end-to-end time (allocation, transfers, kernel, and return) is
the primary GPU metric; kernel-only time is retained as a complementary value.

Requirements: C++17, OpenMP, CUDA Toolkit with `nvcc`, and a
double-precision-capable NVIDIA GPU. From the repository root:

```bash
RUN_LARGE_BENCH=TRUE BENCH_REPS=5 RCS_SEED=20260504 \
RUN_CROSS_LANGUAGE_BENCH=TRUE RCS_PARALLEL_WORKERS=4 \
RCS_OPENMP_THREADS=4 RUN_CUDA_BENCH=TRUE \
  Rscript scripts/run_all.R
```

For a CPU-only verification run, set `RUN_CUDA_BENCH=FALSE`. This omits CUDA
rows and is not a substitute for the final heterogeneous-computing run.

## Repository structure

```text
scripts/                         Validation and figure-generation scripts
outputs/figures/                 Main manuscript figures
outputs/tables/figure_source/    Machine-readable figure source tables
outputs/tables/supplementary/    Supplementary validation outputs
validation/environment/          Session and environment records
src/                             C++17, OpenMP, and CUDA scoring engines
docs/                            Crosswalk and validation documentation
```
