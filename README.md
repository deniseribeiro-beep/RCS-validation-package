# Ribeiro Classification Score (RCS) validation package

Reproducibility package for the governance-aware, rule-based Ribeiro Classification Score (RCS) described in *A Governance-Aware Rule-Based Computational Framework for Biospecimen Qualification in Biobank Information Systems*.

The scientific definition of the RCS is language-independent. The **ISO C11 implementation is the computational reference implementation** in this repository. R, Cython, C++, OpenMP, and CUDA implementations are secondary implementations used for analysis, equivalence testing, and benchmarking; they do not define the RCS.

The repository currently contains no retained legacy study results. Final publication outputs will be generated again only after code/protocol freeze and the planned complete execution on GCP.

## Package components

The executable package contains:

- the C reference scoring and certification implementation;
- executable SPREC 2.0 reference vocabularies and SPREC-to-severity mapping from Supplementary File 1;
- explicit metadata-governance aggregation from Supplementary File 2;
- deterministic C reference tests;
- R-based scientific-validation analyses;
- equivalence and performance benchmarking across the C reference, R/PSOCK, Cython/OpenMP, C++/OpenMP, and optional CUDA;
- Gnuplot scripts for Figures 2–7;
- isolated local, smoke/CI, and publication output scopes.

Cross-language speedups are outside scope. Parallel speedup is calculated only against the sequential baseline of the same implementation family. CUDA acceleration is compared only with C++ sequential. All secondary implementations must first pass equivalence against C-reference expected outputs.

## Scientific definition and complete C API

For a governance-admissible biospecimen of matrix `k`:

```text
p_i^(k)   = W_i^(k) * s_i(x_i)
P_bio^(k) = sum_i p_i^(k)
RCS^(k)   = 100 - P_bio^(k)
```

Fluid weights are `(30, 15, 10, 20, 25)` for `P_pre`, `P_cent1`, `P_cent2`, `P_post`, and `P_store`. Solid weights are `(25, 25, 15, 20, 15)` for `P_warm`, `P_cold`, `P_fix`, `P_fixTime`, and `P_store`.

Score-based grades are A for `RCS >= 90`, B for `80 <= RCS < 90`, C for `65 <= RCS < 80`, D for `50 <= RCS < 65`, and E for `RCS < 50`. Governance non-admissibility is non-compensable and routes to Grade E without a numerical `P_bio` or RCS.

The complete C API is exposed by `rcs_certify()` in `include/rcs_certification.h` / `src/rcs_certification.c`:

```text
raw SPREC 2.0 components
+ explicit SPREC context
+ explicit governance evidence
        ↓
SPREC controlled-vocabulary validation
        ↓
governance aggregation
        ↓
SPREC severity resolution
        ↓
weighted P_bio / RCS / grade / route
```

Unknown, missing, invalid, other/non-standard, incompatible, unresolved, or `Not scored` conditions are never converted to zero severity.

See [`SCIENTIFIC_SPECIFICATION.md`](SCIENTIFIC_SPECIFICATION.md), [`SPREC_MAPPING.md`](SPREC_MAPPING.md), and [`GOVERNANCE_MODEL.md`](GOVERNANCE_MODEL.md).

## Build and deterministic C tests

From the repository root:

```bash
make clean
make reference
make test
```

`make test` executes the deterministic C reference tests in `tests/test_reference.c`.

## Requirements are separated by task

Scientific validation, benchmarking, and figure generation have independent requirement checks.

Scientific validation:

```bash
Rscript scripts/00_check_environment.R scientific
```

This requires `cc`, `make`, R, and the scientific-analysis R packages used by the scripts.

Benchmarking:

```bash
python3 -m pip install numpy cython setuptools
Rscript scripts/00_check_environment.R benchmark
```

The CPU benchmark additionally requires `g++` with OpenMP support. CUDA requires `nvcc` and an NVIDIA GPU only when `BENCHMARK_RUN_CUDA=TRUE`.

Figure generation:

```bash
bash scripts/check_figure_requirements.sh
```

or, on Windows:

```bat
scripts\check_figure_requirements.cmd
```

Figure generation requires Gnuplot and does not require the benchmark toolchain.

## Scientific validation

Run the validation-analysis pipeline with:

```bash
Rscript scripts/run_all.R
```

The exact experimental parameters are frozen in [`VALIDATION_PROTOCOL.md`](VALIDATION_PROTOCOL.md). They include the synthetic generator, five-state combinatorial grid, one-axis analysis, renormalized threshold perturbation, multiplicative weight perturbation, analytical sensitivity identities, and ablation design.

R is an analysis harness here; it is not the computational reference implementation. The complete executable SPREC/governance certification path is the C reference API.

## Benchmark

Run a local/smoke benchmark with:

```bash
Rscript scripts/run_benchmark.R
```

The C reference implementation generates the expected deterministic benchmark outputs. Every timed implementation is compared with those expected outputs before its measurement is accepted. Equivalence covers record order, `P_bio`, RCS, final grade, and route, with numerical tolerance `1e-9` for `P_bio` and RCS.

The benchmark measures the **classification/scoring kernel on pre-resolved benchmark inputs**. It does not measure SPREC parsing/resolution, governance-evidence aggregation, database access, network transfer, or a complete biobank information-system workflow.

Performance comparisons remain within implementation families:

```text
R parallel effect       = T_R,sequential / T_R,PSOCK
Cython parallel effect  = T_Cython,sequential / T_Cython,OpenMP
C++ parallel effect     = T_C++,sequential / T_C++,OpenMP
CUDA acceleration       = T_C++,sequential / T_CUDA
```

No R-versus-Cython, R-versus-C++, C-reference-versus-C++, or other cross-language speedup is reported. See [`BENCHMARK_PROTOCOL.md`](BENCHMARK_PROTOCOL.md).

## Output isolation and publication protection

All scripts use one of three output scopes:

```text
local       -> outputs/local/
smoke       -> outputs/smoke/
publication -> results/publication/
```

`outputs/local/` and `outputs/smoke/` are transient and ignored by Git. CI additionally redirects its runs to temporary runner directories.

Publication output is protected. Writing to `results/publication/` requires the deliberate combination:

```bash
RCS_RUN_SCOPE=publication \
RCS_ALLOW_PUBLICATION_WRITE=TRUE \
<command>
```

`RCS_OUTPUT_ROOT` can override the destination root for an isolated run.

The future final GCP execution will populate `results/publication/` only after the repository passes the pre-publication audit. Until then, no existing file should be interpreted as a final study result.

## Figure generation

`Figure_1` is the conceptual workflow maintained with the manuscript and is not generated by Gnuplot. Figures 2–7 are generated from validated tables under the selected output root.

On Linux, macOS, or WSL:

```bash
bash scripts/generate_figures.sh
```

On Windows:

```bat
scripts\generate_figures.cmd
```

For a future retained publication run, figure generation must use the deliberately enabled publication scope. Plotting scripts read columns by header name and do not use a persistent `figure_source` cache. See [`FIGURE_STANDARD.md`](FIGURE_STANDARD.md).

## Continuous integration

The GitHub Actions validation workflow performs:

- a clean build and deterministic tests of the C reference implementation;
- two independent scientific-validation runs with the same seed followed by a table diff;
- an isolated CPU benchmark smoke run with mandatory C-reference equivalence gates;
- analytical-sensitivity and generated threshold-summary consistency checks;
- verification that smoke runs do not modify repository publication/local output trees.

The figure workflow uses CI-only schema fixtures in a temporary directory to validate Figures 2–7 without depending on retained scientific results. CUDA equivalence is not executed on the CPU-only hosted CI runner and will be exercised during the final GPU-enabled GCP run.

## Repository structure

```text
include/                 C reference public headers
src/                     C reference implementation and native benchmark engines
reference/               machine-readable SPREC/governance reference material
scripts/                 validation, benchmark, requirement, and figure orchestration
tests/                   deterministic C reference tests
outputs/                 transient local/smoke outputs only
results/publication/     protected destination for the future final retained run
.github/workflows/       clean-build, determinism, equivalence, and figure smoke CI
```

Root documentation includes `SCIENTIFIC_SPECIFICATION.md`, `SPREC_MAPPING.md`, `GOVERNANCE_MODEL.md`, `VALIDATION_PROTOCOL.md`, `BENCHMARK_PROTOCOL.md`, `FIGURE_STANDARD.md`, `CITATION.cff`, and `LICENSE`.
