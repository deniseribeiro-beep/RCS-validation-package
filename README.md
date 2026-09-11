# Ribeiro Classification Score (RCS) validation package

Reproducibility package for the governance-aware, rule-based Ribeiro Classification Score (RCS) described in *A Governance-Aware Rule-Based Computational Framework for Biospecimen Qualification in Biobank Information Systems*.

The repository contains two complementary components in one executable structure:

- scientific validation of the RCS in R;
- implementation benchmark across R/PSOCK, Cython/OpenMP, C++/OpenMP, and CUDA acceleration of the C++ kernel.

Cross-language speedups are outside scope. Parallel speedup is calculated only against the sequential baseline of the same implementation family. CUDA is compared only with C++ sequential.

## Validation scope

The scientific pipeline evaluates non-compensable governance admissibility, matrix-specific weighted penalties, the identity `RCS = 100 - P_bio`, deterministic grade thresholds and routing, property-based logical behaviour, synthetic internal validation, combinatorial coverage, threshold margins, governance-failure sensitivity, one-axis transitions, global sensitivity, weight perturbation, and ablation.

Unknown, missing, invalid, incompatible or `Not scored` conditions are never converted to zero severity. They invalidate governance/context admissibility.

## RCS calculation

For matrix `k`:

```text
p_i^(k)   = W_i^(k) * s_i(x_i)
P_bio^(k) = sum_i p_i^(k)
RCS^(k)   = 100 - P_bio^(k)
```

Fluid weights are `(30, 15, 10, 20, 25)` for `P_pre`, `P_cent1`, `P_cent2`, `P_post`, and `P_store`. Solid weights are `(25, 25, 15, 20, 15)` for `P_warm`, `P_cold`, `P_fix`, `P_fixTime`, and `P_store`.

Score-based grades are A for `RCS >= 90`, B for `80 <= RCS < 90`, C for `65 <= RCS < 80`, D for `50 <= RCS < 65`, and E for `RCS < 50`. A failed governance gate is non-compensable and routes directly to Grade E.

## Environment

Check the complete environment with:

```bash
python3 -m pip install numpy cython setuptools
Rscript scripts/00_check_environment.R
```

The scientific validation requires the R packages listed in `scripts/00_check_environment.R`. The benchmark additionally requires Python 3, NumPy, Cython, setuptools, a C++17 compiler with OpenMP support, and, when CUDA is enabled, `nvcc` and a compatible NVIDIA GPU.

## Scientific validation

Run the validation pipeline from the repository root:

```bash
Rscript scripts/run_all.R
```

The scientific validation writes authoritative CSV tables to `outputs/tables/` and environment information to `outputs/environment/`.

The repository retains the canonical machine-readable tables used to support the manuscript. In particular, threshold-transition and weight-perturbation evidence are preserved both at detailed level and as the article-facing summaries:

```text
outputs/tables/Table_Threshold_Transition_Detail.csv
outputs/tables/Table_Threshold_Transition_Summary.csv
outputs/tables/Table_Weight_Perturbation_Sensitivity.csv
outputs/tables/Table_Weight_Perturbation_Summary.csv
```

The summary tables are deterministically derived by the validation scripts from their corresponding detailed tables/results. Redundant `figure_source` caches and duplicated supplementary-export tables are not retained in the repository structure.

## Benchmark

The benchmark evaluates identical deterministic workloads in R sequential, persistent R/PSOCK, Cython sequential, Cython/OpenMP, C++ sequential, C++/OpenMP, and optional C++/CUDA execution. It records `compute` and `end_to_end` timing regions and enforces deterministic output equivalence before accepting a timing.

Run it with:

```bash
Rscript scripts/run_benchmark.R
```

The detailed smoke and publication configurations are documented in [`BENCHMARK_PROTOCOL.md`](BENCHMARK_PROTOCOL.md).

Equivalence requires preservation of record order, `P_bio`, RCS score, final grade, and grade route, with numerical tolerance `1e-9` for `P_bio` and RCS.

## Performance calculations

All acceleration ratios are paired inside each workload/repetition and remain within the same implementation family:

```text
R parallel effect       = T_R,sequential / T_R,PSOCK
Cython parallel effect  = T_Cython,sequential / T_Cython,OpenMP
C++ parallel effect     = T_C++,sequential / T_C++,OpenMP
CUDA acceleration       = T_C++,sequential / T_CUDA
```

No R-versus-Cython, R-versus-C++, or Cython-versus-C++ speedup is estimated.

## Repository structure

```text
scripts/               scientific validation, benchmark orchestration, and language engines
src/                   native C++/OpenMP/CUDA benchmark sources
outputs/tables/        authoritative scientific-validation and benchmark tables
outputs/environment/   computational-environment records
outputs/figures/       figure destination; figures are regenerated from validated tables
.github/workflows/     automated CPU smoke validation
```

Documentation and metadata remain at repository root: `README.md`, `BENCHMARK_PROTOCOL.md`, `CITATION.cff`, and `LICENSE`.

## Figure generation

Publication figures are generated with Gnuplot from the retained CSV tables in `outputs/tables/`. The figure scripts are stored in `scripts/gnuplot/`, the shared graphical configuration is defined in `scripts/gnuplot/ieee_access_style.gp`, and the adopted publication standard is documented in [`FIGURE_STANDARD.md`](FIGURE_STANDARD.md).

Generate the complete figure set from the repository root with:

```bash
bash scripts/generate_figures.sh
```

The generated files are written to `outputs/figures/`. The plotting scripts read the retained result tables directly and do not modify them.

## Reproducibility package contents

The repository brings together the executable RCS validation workflow, benchmark orchestration and language-specific implementations, native C++/OpenMP/CUDA sources, retained result tables, computational-environment records, figure-generation scripts, citation metadata, and license in a single reproducibility package.
