# RCS classification benchmark V2.2

This protocol evaluates sequential and parallel execution **within** three CPU
language families: R, Python/Cython, and C++. It does not use one language as
the performance reference for another and does not report cross-language
speedups. CUDA is retained as an optional accelerator of the C++ kernel and is
compared only with C++ sequential.

## Experimental matrix

| Family | Sequential baseline | Parallel implementation |
|---|---|---|
| R | native R scoring core | PSOCK processes |
| Python/Cython | compiled Cython loop, one thread | same Cython loop with OpenMP threads |
| C++ | C++17 loop | same C++ kernel with OpenMP threads |

When `V2_RUN_CUDA=TRUE`, the same classification rule is also executed by a
CUDA kernel. CUDA is not treated as a fourth language. Two acceleration
measures are reported: kernel-only and end-to-end speedup relative to C++
sequential.

Every condition emits `P_bio`, RCS score, final grade, and route; these outputs
must match the canonical expected binary before a timing is accepted.

Two timing regions are recorded:

- `compute`: warmed-up, calibrated classification time; input is already in RAM.
- `end_to_end`: a fresh process including startup, read/decode, initialization,
  classification, serialization, and write. Internal phases and residual
  process/runtime overhead are stored separately.

Consequently, compute-bound or I/O-bound behavior must be assessed from the
phase table and scaling curves, not inferred from a linear runtime regression.

## Dependencies

- R plus `ggplot2`, `patchwork`, and `scales`;
- Python 3 plus `numpy`, `cython`, and `setuptools`;
- `g++` with C++17 and OpenMP support.
- `nvcc` and an NVIDIA GPU when CUDA is enabled.

```bash
python3 -m pip install numpy cython setuptools
Rscript benchmark_v2/00_check_environment.R
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

V2_SMOKE=TRUE \
V2_RUN_PYTHON=TRUE \
V2_RUN_CUDA=FALSE \
V2_PROCESS_WORKERS=1,2 \
V2_OPENMP_THREADS=1,2 \
V2_PRIMARY_WORKERS=2 \
Rscript scripts/run_benchmark_v2.R 2>&1 | tee benchmark_v2_smoke.log
```

## Publication-oriented run

For the known GCP machine with 8 physical cores and 16 logical CPUs:

```bash
V2_SMOKE=FALSE \
V2_REPS=30 \
V2_BOOT_REPS=5000 \
V2_MIN_SAMPLE_SEC=0.50 \
V2_PROCESS_WORKERS=1,2,4,8,16 \
V2_OPENMP_THREADS=1,2,4,8,16 \
V2_PRIMARY_WORKERS=8 \
V2_RUN_PYTHON=TRUE \
V2_RUN_CUDA=TRUE \
Rscript scripts/run_benchmark_v2.R 2>&1 | tee benchmark_v2_full.log
```

Use `V2_RESUME=TRUE` only with results produced by the same protocol version,
commit, inputs, and configuration. The runner rejects incompatible raw tables.

## Main outputs

Files are written under `outputs/benchmark_v2/`:

- raw and summarized elapsed times;
- paired within-language sequential-to-parallel speedups and efficiencies;
- equivalence and measurement-stability tables;
- end-to-end phase decomposition;
- CUDA kernel, allocation, host-to-device, device-to-host, host-finalization,
  and disk-write phase tables when enabled;
- CUDA kernel-only and end-to-end speedup relative to C++ sequential;
- **Figure 6:** R sequential versus R/PSOCK only, with steady-state runtime,
  end-to-end runtime, and paired R-only speedup;
- **Figure S15:** Cython sequential versus Cython/OpenMP only, with the same
  three-panel structure and explicit thread-count legends;
- **Figure S16:** C++ sequential versus C++/OpenMP only, with the same
  three-panel structure and explicit thread-count legends;
- **Figure S17:** CUDA kernel-only and end-to-end acceleration relative only
  to C++ sequential;
- separate runtime and speedup source CSV files for every figure.

The dashed horizontal line in each speedup panel marks `1×` (no acceleration).
No diagonal “ideal scaling” line is drawn because the reported estimand is a
paired sequential-to-parallel ratio, not strong scaling of the parallel
implementation from one to `p` workers. Smoke-test figures are labelled as
layout/pipeline validation outputs and must not be used for inferential claims.

The V1 pipeline and its published artifacts are not modified.
