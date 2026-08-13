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
- deterministic equivalence between sequential R and persistent PSOCK;
- independent C++17 reproduction of the RCS scoring kernel;
- shared-memory CPU parallelism with OpenMP;
- heterogeneous GPU execution with CUDA;
- cross-language numerical, grade, and route equivalence;
- paired runtime, speedup, and 95% confidence-interval analysis.

Unknown, missing, invalid, incompatible, or `Not scored` conditions are never
converted to zero severity. They invalidate governance/context admissibility.

## Requirements

- R 4.2.2 or newer;
- packages: `dplyr`, `tidyr`, `purrr`, `ggplot2`, `readr`, `stringr`,
  `scales`, `tibble`, `forcats`, `broom`, and `patchwork`;
- a C++17 compiler (`g++`);
- OpenMP support (`-fopenmp`);
- NVIDIA CUDA Toolkit with `nvcc` and a double-precision-capable NVIDIA GPU
  for the final CUDA benchmark.

Check the environment before execution:

```bash
Rscript validation/environment/00_check_environment.R
```

## Complete aligned validation

The final experiment uses seed `20260504`, five repetitions, and the workloads
10,000; 50,000; 100,000; 500,000; 1,000,000; 2,000,000; and 5,000,000 profiles.
Each repetition is generated once in R, serialized, and reused unchanged by:

1. sequential R;
2. persistent four-worker R/PSOCK;
3. sequential C++17;
4. four-thread C++/OpenMP with static scheduling;
5. C++/CUDA using double precision.

From the repository root, run:

```bash
RUN_LARGE_BENCH=TRUE BENCH_REPS=5 RCS_SEED=20260504 \
RUN_CROSS_LANGUAGE_BENCH=TRUE RCS_PARALLEL_WORKERS=4 \
RCS_OPENMP_THREADS=4 RUN_CUDA_BENCH=TRUE \
  Rscript scripts/run_all.R
```

This command regenerates the complete validation, all tables, all supplementary
outputs, Figures 2-7, figure-source tables, and computational-environment logs.
Figures are exported as vector PDF and 600-dpi PNG files.

For CPU-only development checks, set `RUN_CUDA_BENCH=FALSE`. Results from that
reduced run must not replace the final heterogeneous-computing results.

## RCS calculation reproduced by every implementation

For matrix `k`, the axis penalty and accumulated biological-operational penalty
are:

```text
p_i^(k) = W_i^(k) * s_i(x_i)
P_bio^(k) = sum_i p_i^(k)
RCS^(k) = 100 - P_bio^(k)
```

Fluid weights are `(30, 15, 10, 20, 25)` for `P_pre`, `P_cent1`, `P_cent2`,
`P_post`, and `P_store`. Solid weights are `(25, 25, 15, 20, 15)` for
`P_warm`, `P_cold`, `P_fix`, `P_fixTime`, and `P_store`.

Score-based grades are A for `RCS >= 90`, B for `80 <= RCS < 90`, C for
`65 <= RCS < 80`, D for `50 <= RCS < 65`, and E for `RCS < 50`. A failed
governance gate is non-compensable and routes the profile directly to Grade E.

## Equivalence criteria

Every native output is compared with the R canonical output for the same record
order. A run passes only when all conditions hold:

```text
same number and order of profiles
max(abs(P_bio_R - P_bio_native)) < 1e-9
max(abs(RCS_R - RCS_native)) < 1e-9
identical final_grade
identical grade_route
```

The pipeline stops if any equivalence check fails.

## Runtime and speedup calculations

All primary speedups are calculated separately within each paired repetition
and then summarized. They are not calculated as ratios of unpaired means.

```text
S_PSOCK        = T_R,sequential / T_R,PSOCK
S_language     = T_R,sequential / T_C++,sequential
S_OpenMP       = T_C++,sequential / T_C++,OpenMP
S_GPU          = T_C++,sequential / T_C++,CUDA,total
S_PSOCK/OpenMP = T_R,PSOCK / T_C++,OpenMP
S_PSOCK/GPU    = T_R,PSOCK / T_C++,CUDA,total
```

Arithmetic means and 95% confidence intervals use five repetitions per
workload. Figure 6 reports sequential R versus persistent PSOCK. Figure 7
separates language gain, OpenMP gain, GPU gain, and direct PSOCK comparisons.

For CUDA, the primary operational metric is end-to-end device time:

```text
T_CUDA,total = allocation + host-to-device transfer + kernel
             + device-to-host transfer + synchronization
```

Kernel-only CUDA time is retained as a complementary metric and is not used as
the primary denominator for operational speedup.

## Expected generated artifacts

- Figures 2-7 in PDF and 600-dpi PNG;
- validation, sensitivity, ablation, runtime, and equivalence tables;
- Figure 6 and Figure 7 machine-readable source tables;
- supplementary output tables;
- canonical binary inputs and outputs under `outputs/cross_language/`;
- R session information and cross-language compiler/GPU environment logs.

The repository intentionally keeps `outputs/` empty until a complete final run
is executed. Runtime values are environment-specific and must only be reported
after that controlled run.

## Repository structure

```text
scripts/                         Validation and figure-generation scripts
outputs/figures/                 Main manuscript figures
outputs/tables/figure_source/    Machine-readable figure source tables
outputs/tables/supplementary/    Supplementary validation outputs
outputs/cross_language/          Canonical binary inputs and native results
validation/environment/          Session and environment records
src/                             C++17, OpenMP, and CUDA scoring engines
docs/                            Crosswalk and validation documentation
```
