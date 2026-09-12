# RCS classification/scoring-kernel benchmark protocol

This protocol evaluates computational equivalence and execution behaviour of the RCS classification/scoring kernel. The ISO C11 implementation is the **computational reference** and is the sole generator of expected benchmark outputs. R, Cython, C++, OpenMP, and CUDA implementations are secondary implementations whose outputs must first match the C reference before their timings are accepted.

The benchmark does not use one language as a performance reference for another and does not report cross-language speedups. Parallel speedup is calculated only within each implementation family. CUDA acceleration is compared only with C++ sequential.

The benchmark operates on deterministic, pre-resolved binary inputs containing matrix, governance decision, and numerical severities. It therefore measures the scoring/classification kernel, not the complete raw-SPREC/governance-certification workflow.

## Implementations

| Role/family | Sequential implementation | Parallel/accelerated implementation |
|---|---|---|
| Computational reference | ISO C11 `c_reference` | none |
| R | `r_sequential` | persistent `r_psock` processes |
| Python/Cython | `cython_sequential` | `cython_openmp` threads |
| C++ | `cpp_sequential` | `cpp_openmp` threads |
| CUDA | not a separate CPU family | `cpp_cuda`, compared only with C++ sequential |

The C reference is also timed so its own runtime can be reported, but no C-reference-versus-other-language speedup is computed.

## Deterministic workloads and expected outputs

Default seeds are:

```text
BENCHMARK_DATA_SEED  = 20260504
BENCHMARK_ORDER_SEED = 20260824
```

For every workload, `scripts/benchmark_prepare_inputs.R` creates deterministic input files. The C reference implementation then generates the expected output binary for each workload before any secondary implementation is accepted.

Each implementation must preserve:

- record order;
- `P_bio`;
- RCS score;
- final grade;
- grade route.

The numerical equivalence tolerance for `P_bio` and RCS is `1e-9`. Grade and route must be identical.

Governance-failed benchmark records have no numerical `P_bio` or RCS and must preserve the same missing-value pattern as the C reference output.

## Timing regions

Two timing regions are recorded:

- `compute`: warmed-up, calibrated scoring/classification time with input already available to the implementation;
- `end_to_end`: a fresh process including startup, read/decode, initialization, classification, serialization, and write.

Compute timing uses an accepted-measurement calibration loop. The retained measurement block must reach `BENCHMARK_MIN_SAMPLE_SEC`. Calibration failure is a mandatory gate.

Gross timing anomalies are identified on the log scale using the implemented robust diagnostic and remain in the statistical summaries rather than being silently removed.

## Statistical summaries and quality gates

Runtime summaries include the median, bootstrap 95% confidence interval for the median, geometric mean, arithmetic mean, standard deviation, IQR, coefficient of variation, throughput, outlier count, and stability indicators.

For the final publication-oriented configuration:

- 30 repetitions are planned per benchmark condition;
- 5,000 bootstrap repetitions are used;
- workload sizes are `10,000`, `50,000`, `100,000`, `500,000`, `1,000,000`, `2,000,000`, and `5,000,000` profiles;
- R/PSOCK worker counts are `1,2,4,8,16`;
- Cython/OpenMP and C++/OpenMP thread counts are `1,2,4,8,16`;
- the minimum calibrated compute block is `0.50 s`;
- compute stability requires bootstrap-median 95% CI relative half-width `<=10%`;
- the minimum accepted compute-stability rate is `90%`;
- end-to-end stability is reported separately and is diagnostic by default.

The final GCP run has **not yet been executed for the restructured package**. These values define the frozen planned configuration and must not be reported as new study results until that execution is completed.

## Requirements

Benchmark requirements are checked independently from scientific validation and figure generation:

```bash
python3 -m pip install numpy cython setuptools
BENCHMARK_RUN_PYTHON=TRUE \
BENCHMARK_RUN_CUDA=FALSE \
Rscript scripts/00_check_environment.R benchmark
```

CPU benchmarking requires R, `cc`, `g++`, OpenMP support through `g++`, and Python/NumPy/Cython/setuptools when Python/Cython is enabled. CUDA additionally requires `nvcc` and an NVIDIA GPU when `BENCHMARK_RUN_CUDA=TRUE`.

## Local or diagnostic smoke run

Smoke runs are transient and must not write to retained publication results.

```bash
RCS_RUN_SCOPE=smoke \
BENCHMARK_SMOKE=TRUE \
BENCHMARK_REPS=5 \
BENCHMARK_BOOT_REPS=1000 \
BENCHMARK_MIN_SAMPLE_SEC=0.50 \
BENCHMARK_MAX_INNER_LOOPS=1000000 \
BENCHMARK_WORKLOADS=10000,50000,100000 \
BENCHMARK_RUN_PYTHON=TRUE \
BENCHMARK_RUN_CUDA=FALSE \
BENCHMARK_PROCESS_WORKERS=1,2 \
BENCHMARK_OPENMP_THREADS=1,2 \
BENCHMARK_PRIMARY_WORKERS=2 \
BENCHMARK_RESUME=FALSE \
Rscript scripts/run_benchmark.R
```

GitHub Actions uses an even smaller diagnostic configuration in an isolated runner-temporary output root. Smoke variability is diagnostic; C-reference equivalence and the compute calibration floor remain mandatory.

## Final publication-oriented GCP run

Publication output is protected and must be enabled deliberately. The planned complete run is:

```bash
export OMP_PROC_BIND=true
export OMP_PLACES=cores
export OMP_DYNAMIC=false
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

RCS_RUN_SCOPE=publication \
RCS_ALLOW_PUBLICATION_WRITE=TRUE \
BENCHMARK_SMOKE=FALSE \
BENCHMARK_REPS=30 \
BENCHMARK_BOOT_REPS=5000 \
BENCHMARK_MIN_SAMPLE_SEC=0.50 \
BENCHMARK_MAX_INNER_LOOPS=1000000 \
BENCHMARK_WORKLOADS=10000,50000,100000,500000,1000000,2000000,5000000 \
BENCHMARK_PROCESS_WORKERS=1,2,4,8,16 \
BENCHMARK_OPENMP_THREADS=1,2,4,8,16 \
BENCHMARK_PRIMARY_WORKERS=8 \
BENCHMARK_MIN_STABILITY_RATE=0.90 \
BENCHMARK_MAX_RELATIVE_CI_PERCENT=10 \
BENCHMARK_ENFORCE_QUALITY_GATES=TRUE \
BENCHMARK_ENFORCE_E2E_STABILITY=FALSE \
BENCHMARK_RUN_PYTHON=TRUE \
BENCHMARK_RUN_CUDA=TRUE \
BENCHMARK_RESUME=FALSE \
Rscript scripts/run_benchmark.R
```

This command is reserved for the deliberate final GPU-enabled GCP execution after the pre-publication repository audit.

## Speedup estimands

Paired speedups are computed only within a compatible implementation family and workload/repetition:

```text
R parallel effect       = T_R,sequential / T_R,PSOCK
Cython parallel effect  = T_Cython,sequential / T_Cython,OpenMP
C++ parallel effect     = T_C++,sequential / T_C++,OpenMP
CUDA acceleration       = T_C++,sequential / T_CUDA
```

No R-versus-Cython, R-versus-C++, C-reference-versus-C++, or other cross-language speedup is estimated.

## Benchmark outputs

For local and smoke runs, tables are written under the selected transient output root. The future retained final benchmark tables will be promoted under:

```text
results/publication/tables/
```

The benchmark table set includes:

- `Table_Benchmark_Runtime_Raw.csv`;
- `Table_Benchmark_Runtime_Summary.csv`;
- `Table_Benchmark_Within_Language_Speedup_Summary.csv`;
- `Table_Benchmark_CUDA_Speedup_Summary.csv` when CUDA is enabled;
- `Table_Benchmark_Equivalence_Check.csv`;
- `Table_Benchmark_Calibration_Diagnostics.csv`;
- `Table_Benchmark_Measurement_Stability.csv`;
- `Table_Benchmark_Outlier_Diagnostics.csv`;
- `Table_Benchmark_Quality_Gates.csv`;
- `Table_Benchmark_End_to_End_Phase_Decomposition.csv`;
- `Table_Benchmark_CUDA_Phase_Decomposition.csv` when CUDA is enabled.

The benchmark workspace (`.benchmark_work`) is transient and is never part of the retained publication package. Figure rendering is separated from benchmark analysis so figures can be regenerated from validated retained tables without recomputing benchmark statistics.
