# RCS implementation benchmark V2

Benchmark V2 is isolated from the original validation pipeline and published
V1 artifacts. It compares functionally equivalent implementations of the RCS
scoring core in R, Python/NumPy, C++17, OpenMP, and optionally CUDA.

## Methodological changes

- Every implementation emits the same four outputs: `P_bio`, `RCS`, final
  grade, and grade route.
- Every result is checked against the canonical expected binary.
- `compute` reports calibrated steady-state scoring time after warm-up.
- `end_to_end` is measured externally in a fresh process and includes process
  startup, input reading, runtime/worker/device initialization, scoring,
  serialization, and output writing.
- Short measurements are repeated internally until the configured minimum
  sample duration. Inner loops form one observation, not independent samples.
- Outer repetitions use randomized balanced blocks.
- Paired speedups and bootstrap 95% confidence intervals are reported.
- Python uses idiomatic NumPy. Numba, CuPy, JAX, PyTorch, `numpy.vectorize`,
  and row-wise pandas `apply` are deliberately outside this protocol.

## Dependencies

- R with `ggplot2`, `patchwork`, and `scales`
- Python 3 with NumPy
- `g++` with C++17 and OpenMP
- `nvcc` and an NVIDIA GPU only when CUDA is enabled

```bash
Rscript benchmark_v2/00_check_environment.R
```

## Local smoke test

The default smoke profile uses 10,000 and 50,000 profiles, two repetitions,
1/2 workers or threads, a 50 ms calibrated sample, and no CUDA.

```bash
cd ~/RCS-validation-package

export OMP_PROC_BIND=true
export OMP_PLACES=cores
export OMP_DYNAMIC=false
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

V2_SMOKE=TRUE \
V2_RUN_PYTHON=TRUE \
V2_RUN_CUDA=FALSE \
Rscript scripts/run_benchmark_v2.R 2>&1 | tee benchmark_v2_smoke.log
```

## Full publication-oriented run

Run this only after reviewing the smoke outputs.

```bash
V2_SMOKE=FALSE \
V2_REPS=20 \
V2_MIN_SAMPLE_SEC=0.25 \
V2_PROCESS_WORKERS=1,2,4,8 \
V2_OPENMP_THREADS=1,2,4,8,16 \
V2_PRIMARY_WORKERS=8 \
V2_RUN_PYTHON=TRUE \
V2_RUN_CUDA=TRUE \
Rscript scripts/run_benchmark_v2.R 2>&1 | tee benchmark_v2_full.log
```

Use `V2_RESUME=TRUE` only to continue an interrupted run made with the same
commit and configuration. The raw CSV is updated after every valid condition.

## Generated artifacts

All generated files are placed under `outputs/benchmark_v2/`:

- raw, summary, speedup, equivalence, stability, and parallel-scaling tables;
- Figure 6 V2 in PDF and PNG;
- supplementary strong-scaling figure in PDF and PNG;
- figure-source CSVs, randomized schedule, input manifest, and environment log.

The original V1 scripts, tables, figures, and cross-language artifacts are not
modified by this protocol.

