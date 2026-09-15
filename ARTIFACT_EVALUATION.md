# Artifact evaluation guide

## 1. Artifact identification

**Associated article:** *A Governance-Aware Rule-Based Computational Method for Biospecimen Qualification in Biobank Information Systems*

**Authors:** Denise Ribeiro; Fábio Andrijauskas; Lucas Miguel de Carvalho; Vicente Idalberto Becerra Sablón.

This artifact supports the computational claims of the article. It contains the
C11 computational reference implementation of the Ribeiro Classification Score
(RCS), deterministic reference tests, synthetic scientific-validation analyses,
secondary implementations used for equivalence and benchmarking, retained
publication results, and scripts for Figures 2-7.

The benchmark evaluates the scoring/classification kernel on deterministic,
pre-resolved synthetic inputs. It does not claim to benchmark an entire biobank
information system, database access, network transfer, SPREC parsing, or raw
governance-evidence aggregation.

## 2. Artifact claims

The artifact enables a reviewer to verify that:

1. the C11 reference implementation builds and passes deterministic tests;
2. scientific-validation outputs are deterministic for the frozen seed;
3. secondary implementations match C-reference outputs before timings are used;
4. retained publication outputs passed the declared quality gates;
5. Figures 2-7 are generated from named retained tables; and
6. reported speedups do not compare unrelated implementation families.

## 3. Requirements

### Quick CPU evaluation

- Linux, macOS, WSL, or a compatible CI runner;
- C11 compiler, `make`, and standard C math library;
- R 4.3.3 or a compatible version;
- Python 3.12.3 for Cython benchmark checks;
- C++17 compiler with OpenMP support;
- Gnuplot with `pdfcairo` support for figure generation;
- Poppler tools (`pdfinfo` and `pdffonts`) for release verification.
- SHA-256 checksum utility: `sha256sum` on Linux/WSL or the native
  `shasum` utility on macOS; the verification script detects either one.

The direct R and Python versions from the retained publication run are listed in
`requirements-r.txt` and `requirements-python.txt`. Complete resolved package
versions are retained in `results/publication/environment/`.

### Full CUDA reproduction

The retained full benchmark was executed on Ubuntu 24.04 with an NVIDIA L4
(23,034 MiB), CUDA 12.9, GCC/G++ 13.3.0, R 4.3.3, and Python 3.12.3. A compatible
NVIDIA GPU and CUDA toolchain are required when `BENCHMARK_RUN_CUDA=TRUE`.

The retained artifact is approximately 7 MB. The completed full benchmark used
a transient workspace of approximately 134 GB. Reviewers should allocate at
least 150 GB if they elect to repeat the complete publication run.

## 4. Installation

Clone the immutable release tag rather than the moving default branch:

```bash
git clone --branch v1.0.0 --depth 1 \
  https://github.com/deniseribeiro-beep/RCS-validation-package.git
cd RCS-validation-package
```

Install the exact direct Python dependencies:

```bash
python3 -m pip install -r requirements-python.txt
```

Install the exact direct R dependencies:

```bash
Rscript scripts/install_r_dependencies.R
```

On Ubuntu, install the system tools when absent:

```bash
sudo apt-get update
sudo apt-get install -y build-essential g++ make gnuplot-nox poppler-utils
```

## 5. Level 1 - deterministic reference test

Expected duration: less than 10 minutes on a conventional CPU runner.

```bash
make clean
make reference
make test
```

Expected result: `tests/test_reference.c` exits successfully and both
`bin/rcs-reference` and `bin/test-reference` are executable.

## 6. Level 2 - scientific validation and CPU smoke benchmark

Scientific validation is bounded by the 30-minute CI timeout on the supported
GitHub-hosted runner:

```bash
Rscript scripts/00_check_environment.R scientific
RCS_RUN_SCOPE=smoke \
RCS_OUTPUT_ROOT="$(pwd)/review-scientific" \
RCS_SEED=20260504 \
RUN_BENCHMARK=FALSE \
Rscript scripts/run_all.R
```

Run the reduced CPU benchmark:

```bash
RCS_RUN_SCOPE=smoke \
RCS_OUTPUT_ROOT="$(pwd)/review-benchmark" \
BENCHMARK_SMOKE=TRUE \
BENCHMARK_REPS=2 \
BENCHMARK_BOOT_REPS=200 \
BENCHMARK_MIN_SAMPLE_SEC=0.10 \
BENCHMARK_WORKLOADS=10000,50000 \
BENCHMARK_RUN_PYTHON=TRUE \
BENCHMARK_RUN_CUDA=FALSE \
BENCHMARK_PROCESS_WORKERS=1,2 \
BENCHMARK_OPENMP_THREADS=1,2 \
BENCHMARK_PRIMARY_WORKERS=2 \
BENCHMARK_RESUME=FALSE \
BENCHMARK_ENFORCE_QUALITY_GATES=FALSE \
Rscript scripts/run_benchmark.R
```

This level is bounded by the 30-minute CI timeout. Hardware-dependent timing
values need not match the retained GCP timings. Equivalence, deterministic
scientific outputs, schemas, and mandatory calibration behaviour must match.

## 7. Level 3 - retained publication results

Verify the immutable retained artifacts:

```bash
bash scripts/verify_release_artifact.sh
```

The retained quality-gate table must report:

- `equivalence_gate_passed=TRUE`;
- `4200/4200` calibrated compute measurements passing;
- `139/140` stable compute conditions;
- `139/140` stable end-to-end conditions; and
- `all_quality_gates_passed=TRUE`.

The single unstable compute condition is R/PSOCK at 50,000 records with one
worker (relative bootstrap CI half-width 13.93%). The single unstable diagnostic
end-to-end condition is the C reference at 10,000 records (12.50%). These are
retained and disclosed rather than removed.

## 8. Complete publication run

The frozen full command and environment variables are specified in
`BENCHMARK_PROTOCOL.md`. The run is intentionally not part of hosted CPU CI
because it requires CUDA-capable hardware, 30 repetitions per condition, 5,000
bootstrap repetitions, and substantial transient storage.

Exact timing values are hardware-specific. Reproduction is evaluated through
equivalence, protocol adherence, quality-gate behaviour, and consistency of the
reported analyses, not bitwise equality of elapsed times.

## 9. Acknowledgments and AI-assisted preparation

This material is based upon work supported by the Google Cloud Research Credits program with the award number 529423026.

During preparation of the associated article and this reproducibility artifact,
the authors used OpenAI ChatGPT and Codex solely to support grammatical review
and limited textual corrections, LaTeX formatting troubleshooting,
configuration of the Google Cloud execution environment, and assistance with
software-testing agents and targeted corrections to validation and Gnuplot
scripts. AI assistance affected language and LaTeX formatting throughout the
manuscript and the supplementary artifact's environment-configuration
instructions, automated tests, validation scripts, and Gnuplot scripts. The AI
tools were not used to generate the synthetic data, execute or select the
retained measurements, define the scientific method, interpret the results, or
formulate the conclusions. All AI-assisted suggestions and code changes were
reviewed, tested, and validated by the authors, who take full responsibility
for the final content.

## 10. Provenance

- Publication benchmark-producing commit: `a6fd359d3ff41536cb4ec0424b0c4f82ffe4792f`.
- Publication release-candidate base: `0584a4a9bd1402ebff8d6cb28325cdbfdc464b47`.
- Commits after the benchmark-producing commit changed publication figures,
  smoke fixtures, and documentation; they did not rerun or replace benchmark
  measurements.
- The execution environment is recorded under
  `results/publication/environment/`.
- File integrity is verified by `SHA256SUMS`.

## 11. Expected variability

Elapsed times, throughput, speedup, and confidence intervals may differ on other
hardware. Deterministic scores, grades, routes, table schemas, and equivalence
checks must remain consistent with the stated tolerances.

Questions about the artifact should be submitted through the repository issue
tracker so that clarifications remain public and versioned.
