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

The repository contains two complementary execution layers: the original
scientific-validation pipeline and the publication-oriented Benchmark V2.4.

The scientific-validation pipeline requires R 4.2.2 or newer and the R
packages `dplyr`, `tidyr`, `purrr`, `ggplot2`, `readr`, `stringr`, `scales`,
`tibble`, `forcats`, `broom`, and `patchwork`.

Benchmark V2.4 requires R with `ggplot2`, `patchwork`, and `scales`; Python 3
with `numpy`, `cython`, and `setuptools`; a C++17 compiler with OpenMP support;
and, when CUDA is enabled, `nvcc` and a compatible NVIDIA GPU.

Check the scientific-validation environment with:

```bash
Rscript validation/environment/00_check_environment.R
```

Check the Benchmark V2.4 environment with:

```bash
python3 -m pip install numpy cython setuptools
Rscript benchmark_v2/00_check_environment.R
```

## Experimental design

The publication-oriented Benchmark V2.4 uses data seed `20260504`, order seed
`20260824`, 30 repetitions per condition, 5,000 bootstrap repetitions, a
minimum calibrated compute-measurement duration of 0.50 s, and a maximum of
1,000,000 inner loops.

The evaluated workloads contain 10,000; 50,000; 100,000; 500,000; 1,000,000;
2,000,000; and 5,000,000 profiles. R/PSOCK process counts and OpenMP thread
counts are evaluated at 1, 2, 4, 8, and 16, with 8 designated as the primary
worker count.

Each canonical input is generated from the same deterministic R specification
and reused unchanged for:

1. R sequential;
2. persistent R/PSOCK;
3. Cython sequential;
4. Cython with OpenMP;
5. C++17 sequential;
6. C++17 with OpenMP;
7. C++17 with CUDA acceleration.

Two timing regions are recorded. `compute` is a warmed-up, calibrated
classification measurement with input already available in memory.
`end_to_end` uses a fresh process and includes startup, input reading and
decoding, initialization, classification, serialization, and output writing.
Internal phases and residual process/runtime overhead are retained separately.

CUDA is treated as an accelerator of the C++ implementation, not as a separate
language family.

In publication mode, compute conditions are considered stable when the
bootstrap 95% confidence interval for the median has relative half-width at
most 10%. The configured minimum accepted compute-stability rate is 90%.
End-to-end stability is reported separately and remains diagnostic by default.

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

R is the canonical output. Every independent implementation must preserve
record order and pass all criteria:

```text
same number and order of profiles
max(abs(P_bio_R - P_bio_native)) < 1e-9
max(abs(RCS_R - RCS_native)) < 1e-9
identical final_grade
identical grade_route
```

The pipeline stops on any equivalence failure.

## Performance calculations

All speedup ratios are computed within the same implementation family and
inside each paired workload/repetition before summary. Ratios of unpaired
means and cross-language speedups are not used.

```text
R parallel effect       = T_R,sequential / T_R,PSOCK
Cython parallel effect  = T_Cython,sequential / T_Cython,OpenMP
C++ parallel effect     = T_C++,sequential / T_C++,OpenMP
```

CUDA acceleration is reported separately relative only to C++ sequential,
using kernel-only and end-to-end measurements.

No R-versus-Cython, R-versus-C++, or Cython-versus-C++ acceleration ratio is
estimated.

The performance figures are separated by implementation family:

- Figure 6: R sequential versus R/PSOCK;
- Figure S15: Cython sequential versus Cython/OpenMP;
- Figure S16: C++ sequential versus C++/OpenMP;
- Figure S17: CUDA acceleration relative only to C++ sequential.

The `1×` horizontal reference identifies no acceleration. No ideal-scaling
diagonal is used because the reported estimand is the paired
sequential-to-parallel ratio rather than strong scaling from one parallel
worker to `p` workers.

Gross timing anomalies are identified with the protocol's robust diagnostic
rule and are reported rather than silently removed.

## Execution

The original scientific-validation pipeline under `scripts/` is preserved for
the scientific-validation analyses and V1 artifacts. It is not the source of
the final publication-oriented V2 performance figures.

Benchmark V2.4 is executed through:

```bash
Rscript scripts/run_benchmark_v2.R
```

The authoritative smoke-test and publication-oriented configurations are
documented in [`benchmark_v2/README.md`](benchmark_v2/README.md).

For the publication-oriented run, the protocol uses 30 repetitions, 5,000
bootstrap repetitions, workloads from 10,000 to 5,000,000 profiles, R/PSOCK
process counts of 1, 2, 4, 8, and 16, OpenMP thread counts of 1, 2, 4, 8, and
16, mandatory compute quality gates, and diagnostic end-to-end stability.

`V2_RESUME=TRUE` may be used only to continue results generated with the same
protocol version, commit, inputs, and configuration.

## Generated artifacts

The repository preserves two artifact groups.

The scientific-validation artifacts are stored under `outputs/figures/` and
`outputs/tables/` and correspond to the canonical R validation pipeline.
Figures 2-5 and their source tables belong to this scientific-validation
layer. Earlier V1 computational-performance artifacts are retained for
provenance but must not be used to infer Benchmark V2.4 performance.

The final Benchmark V2.4 publication artifacts are versioned under
`outputs/benchmark_v2/` and include:

- `figures/`: Figure 6, Figure S15, Figure S16, and Figure S17 in PDF and PNG;
- `tables/`: raw and summarized runtime, within-family speedup, equivalence,
  calibration, stability, outlier-diagnostic, phase-decomposition,
  quality-gate, CUDA, and figure-source tables;
- `environment/`: the computational-environment snapshot for the final run.

Large transient benchmark inputs, expected binary outputs, compiled artifacts,
and per-run intermediate result files are generated locally and are not part
of the versioned publication artifact set.

## Legacy V1 artifacts

The V1 pipeline and its retained artifacts are preserved for provenance and
are not modified by Benchmark V2.4. In particular, legacy cross-language
runtime tables, the earlier unified implementation-performance Figure 6, and
its figure-source tables must not be interpreted as V2 performance outputs.

The root-level `gcp_full_benchmark.log` is a retained V1 execution log.
Likewise, `benchmark_git_commit.txt` is a retained V1 commit marker and must
not be interpreted as the commit identifier for the final V2 execution. The
V2 execution commit and computational environment are recorded in
`outputs/benchmark_v2/environment/Computational_Environment_V2.txt`.

## Repository structure

```text
benchmark_v2/                     Benchmark V2.4 protocol and language-family engines
scripts/                          scientific validation and benchmark orchestration
src/                              native C++/OpenMP/CUDA implementations
src/v2/                           Benchmark V2 native scoring engines
outputs/figures/                  scientific-validation and retained V1 artifacts
outputs/tables/                   scientific-validation and retained V1 tables
outputs/benchmark_v2/figures/     final V2 publication figures
outputs/benchmark_v2/tables/      final V2 publication tables and figure sources
outputs/benchmark_v2/environment/ final V2 computational-environment record
validation/environment/           scientific-validation environment checks
.github/workflows/                automated CPU smoke validation for the retained V1 pipeline
```

## Archival scope

The versioned repository is intended to preserve the executable validation
code, Benchmark V2.4 protocol, scientific-validation outputs, final V2 tables
and figures, computational-environment record, citation metadata, and license.
Transient virtual environments, compiled binaries, large expected-output
binaries, and raw per-run intermediate benchmark files are intentionally
excluded from the versioned publication package.
