# Ribeiro Classification Score (RCS) validation package

> A publication-oriented second-generation implementation benchmark is
> available in [`benchmark_v2/README.md`](benchmark_v2/README.md). It is
> isolated from V1 and adds Python/Cython, standardized compute/end-to-end
> timing, calibrated samples, randomized repetitions, equivalence gates,
> uncertainty tables, and revised figures.

Reproducibility package for the governance-aware, rule-based Ribeiro
Classification Score (RCS) described in *A Governance-Aware Rule-Based
Computational Framework for Biospecimen Qualification in Biobank Information
Systems*.

The scientific validation remains canonical in R. The V2 performance protocol
evaluates sequential and parallel execution separately within R, Cython, and
C++ language families. CUDA is treated only as an accelerator of the C++
kernel. Cross-language speedups are intentionally outside scope.

## Validation scope

The pipeline evaluates:

- non-compensable governance admissibility;
- matrix-specific SPREC-derived weighted penalties;
- the identity `RCS = 100 - P_bio`;
- deterministic A-E grade thresholds and routing;
- property-based logical behaviour;
- synthetic internal validation and threshold margins;
- governance-failure sensitivity;
- combinatorial coverage and one-axis transitions;
- global sensitivity, weight perturbation and ablation;
- sequential runtime scalability;
- deterministic equivalence between R sequential and persistent R/PSOCK;
- independent R, Cython, and C++17 sequential/parallel reproduction;
- multicore CPU execution with PSOCK or OpenMP, evaluated within language;
- NVIDIA GPU execution with CUDA;
- paired runtime, speedup and 95% confidence-interval analysis.

Unknown, missing, invalid, incompatible or `Not scored` conditions are never
converted to zero severity. They invalidate governance/context admissibility.

## Computational question

The performance experiment asks:

> How does parallel execution affect RCS classification performance relative
> to the sequential baseline within each implementation family, under
> identical workloads and deterministic output-equivalence requirements?

No R-versus-Cython-versus-C++ speedup is estimated. Absolute runtimes may be
reported descriptively in separate language-specific figures, but acceleration
ratios use only the sequential baseline from the same family. CUDA uses C++
sequential as its sole denominator.

## Requirements

- R 4.2.2 or newer;
- R packages: `dplyr`, `tidyr`, `purrr`, `ggplot2`, `readr`,
  `stringr`, `scales`, `tibble`, `forcats`, `broom`, `patchwork`;
- a C++17 compiler (`g++`);
- OpenMP support (`-fopenmp`);
- NVIDIA CUDA Toolkit with `nvcc` and a compatible NVIDIA GPU for CUDA.

Check the R environment:

```bash
Rscript validation/environment/00_check_environment.R
```

## Experimental design

The controlled final run uses:

- seed `20260504`;
- five paired repetitions;
- workloads of 10,000; 50,000; 100,000; 500,000; 1,000,000; 2,000,000;
  and 5,000,000 profiles;
- four persistent PSOCK workers;
- four OpenMP threads;
- double precision in R, C++ and CUDA;
- the same canonical input for every implementation within each
  workload/repetition pair.

Each canonical input is generated once in R and reused unchanged by:

1. R sequential;
2. persistent R/PSOCK;
3. C++17 sequential;
4. C++17 with OpenMP and static scheduling;
5. C++17 with CUDA.

Compilation, data generation and serialization are excluded from the timed
scoring region. For CUDA, the primary device metric includes allocation,
host-to-device transfer, kernel execution, synchronization and device-to-host
transfer. Kernel-only time is retained as a complementary metric.

## RCS calculation

For matrix `k`:

```text
p_i^(k)   = W_i^(k) * s_i(x_i)
P_bio^(k) = sum_i p_i^(k)
RCS^(k)   = 100 - P_bio^(k)
```

Fluid weights are `(30, 15, 10, 20, 25)` for `P_pre`, `P_cent1`,
`P_cent2`, `P_post` and `P_store`. Solid weights are
`(25, 25, 15, 20, 15)` for `P_warm`, `P_cold`, `P_fix`,
`P_fixTime` and `P_store`.

Score-based grades are A for `RCS >= 90`, B for `80 <= RCS < 90`, C for
`65 <= RCS < 80`, D for `50 <= RCS < 65`, and E for `RCS < 50`.
A failed governance gate is non-compensable and routes directly to Grade E.

## Equivalence criteria

R is the canonical output. Every native result must preserve record order and
pass all criteria:

```text
same number and order of profiles
max(abs(P_bio_R - P_bio_native)) < 1e-9
max(abs(RCS_R - RCS_native)) < 1e-9
identical final_grade
identical grade_route
```

The pipeline stops on any equivalence failure.

## Performance calculations

All ratios are computed inside each paired workload/repetition before summary.
Ratios of unpaired means are not used.

```text
PSOCK effect        = T_R,sequential / T_R,PSOCK
language effect     = T_R,sequential / T_C++,sequential
OpenMP effect       = T_C++,sequential / T_C++,OpenMP
CUDA effect         = T_C++,sequential / T_C++,CUDA,total

overall PSOCK       = T_R,sequential / T_R,PSOCK
overall C++ seq.    = T_R,sequential / T_C++,sequential
overall OpenMP      = T_R,sequential / T_C++,OpenMP
overall CUDA        = T_R,sequential / T_C++,CUDA,total

direct PSOCK/OpenMP = T_R,PSOCK / T_C++,OpenMP
direct PSOCK/CUDA   = T_R,PSOCK / T_C++,CUDA,total
```

Figure 6 is the single computational comparison:

- Panel A: elapsed time for every implementation;
- Panel B: overall speedup relative to canonical R sequential;
- Panel C: decomposed PSOCK, language, OpenMP and CUDA effects.

Individual repetitions are displayed. Arithmetic means and 95% confidence
intervals are added when at least two repetitions exist. Direct PSOCK/OpenMP
and PSOCK/CUDA comparisons are exported as supplementary audit tables.

## Run locally

CPU-only smoke test:

```bash
RUN_LARGE_BENCH=FALSE \
BENCH_REPS=1 \
RCS_SEED=20260504 \
RUN_CROSS_LANGUAGE_BENCH=TRUE \
RCS_PARALLEL_WORKERS=2 \
RCS_OPENMP_THREADS=2 \
RUN_CUDA_BENCH=FALSE \
Rscript scripts/run_all.R 2>&1 | tee local_smoke_test.log
```

This run validates the full R workflow, R/PSOCK, C++ sequential, OpenMP,
equivalence checks, tables and Figures 2-6. CUDA is omitted dynamically.

## Run the controlled GCP experiment

```bash
RUN_LARGE_BENCH=TRUE \
BENCH_REPS=5 \
RCS_SEED=20260504 \
RUN_CROSS_LANGUAGE_BENCH=TRUE \
RCS_PARALLEL_WORKERS=4 \
RCS_OPENMP_THREADS=4 \
RUN_CUDA_BENCH=TRUE \
Rscript scripts/run_all.R 2>&1 | tee gcp_final_benchmark.log
```

Before the final run, verify `nvidia-smi` and `nvcc --version`. CUDA series
appear automatically when CUDA observations are present.

## Generated artifacts

- Figures 2-6 as vector PDF and 600-dpi PNG;
- validation, sensitivity, ablation, runtime and equivalence tables;
- machine-readable figure-source tables;
- supplementary audit tables, including direct optimized-path speedups;
- temporary canonical binary inputs/native outputs under
  `outputs/cross_language/`;
- R session and compiler/GPU environment records under
  `validation/environment/`.

Generated results, binaries, logs and environment snapshots are ignored by
Git. The repository intentionally keeps output directories empty except for
`.gitkeep` markers; every controlled run starts from regenerated artifacts.

## Repository structure

```text
scripts/                         validation, benchmarking and figure scripts
src/                             C++17, OpenMP and CUDA scoring engines
outputs/figures/                 generated main manuscript figures
outputs/tables/figure_source/    generated machine-readable figure sources
outputs/tables/supplementary/    generated supplementary audit tables
outputs/cross_language/          generated canonical/native binary artifacts
validation/environment/          checks and generated environment records
.github/workflows/               CPU smoke validation
```
