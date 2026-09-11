# RCS classification benchmark protocol

This protocol evaluates sequential and parallel execution within three CPU language families: R, Python/Cython, and C++. It does not use one language as the performance reference for another and does not report cross-language speedups. CUDA is retained as an optional accelerator of the C++ kernel and is compared only with C++ sequential.

## Experimental matrix

| Family | Sequential baseline | Parallel implementation |
|---|---|---|
| R | native R scoring core | PSOCK processes |
| Python/Cython | compiled Cython loop, one thread | same Cython loop with OpenMP threads |
| C++ | C++17 loop | same C++ kernel with OpenMP threads |

When `BENCHMARK_RUN_CUDA=TRUE`, the same classification rule is also executed by a CUDA kernel. CUDA is not treated as a separate language family. Kernel-only and end-to-end acceleration are both referenced to C++ sequential.

Every condition emits `P_bio`, RCS score, final grade, and route. These outputs must match the canonical expected binary before a timing is accepted.

Two timing regions are recorded:

- `compute`: warmed-up, calibrated classification time with input already in RAM;
- `end_to_end`: a fresh process including startup, read/decode, initialization, classification, serialization, and write.

Compute timing uses an accepted-measurement calibration loop. The retained block must reach the configured duration floor. Gross timing anomalies are flagged on the log scale using a robust MAD rule and remain in the reported estimates.

## Dependencies

- R and the packages listed by `scripts/00_check_environment.R`;
- Python 3 with `numpy`, `cython`, and `setuptools`;
- `g++` with C++17 and OpenMP support;
- `nvcc` and an NVIDIA GPU when CUDA is enabled.

```bash
python3 -m pip install numpy cython setuptools
Rscript scripts/00_check_environment.R
```

## Local smoke test

```bash
cd ~/RCS-validation-package

export OMP_PROC_BIND=true
export OMP_PLACES=cores
export OMP_DYNAMIC=false
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

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

## Publication-oriented run

The completed study used 30 repetitions, 5,000 bootstrap repetitions, workloads from 10,000 to 5,000,000 profiles, R/PSOCK process counts of 1, 2, 4, 8, and 16, and OpenMP thread counts of 1, 2, 4, 8, and 16.

```bash
BENCHMARK_SMOKE=FALSE \
BENCHMARK_REPS=30 \
BENCHMARK_BOOT_REPS=5000 \
BENCHMARK_MIN_SAMPLE_SEC=0.50 \
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

In publication mode, compute conditions are considered stable when the bootstrap 95% confidence interval for the median has relative half-width at most 10%. The configured minimum accepted compute-stability rate is 90%. End-to-end stability is reported separately and remains diagnostic by default.

## Authoritative benchmark tables

The final benchmark tables are stored in `outputs/tables/`:

- `Table_Benchmark_Runtime_Raw.csv`;
- `Table_Benchmark_Runtime_Summary.csv`;
- `Table_Benchmark_Within_Language_Speedup_Summary.csv`;
- `Table_Benchmark_CUDA_Speedup_Summary.csv`;
- `Table_Benchmark_Equivalence_Check.csv`;
- `Table_Benchmark_Calibration_Diagnostics.csv`;
- `Table_Benchmark_Measurement_Stability.csv`;
- `Table_Benchmark_Outlier_Diagnostics.csv`;
- `Table_Benchmark_Quality_Gates.csv`;
- `Table_Benchmark_End_to_End_Phase_Decomposition.csv`;
- `Table_Benchmark_CUDA_Phase_Decomposition.csv`.

All sequential-to-parallel speedups are paired within the same implementation family. CUDA uses C++ sequential as its sole denominator. Figure rendering is intentionally separated from the statistical analysis so that figures can be regenerated from these validated tables without recomputing benchmark statistics.
