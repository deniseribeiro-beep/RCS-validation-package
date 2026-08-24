#!/usr/bin/env python3
"""Python/Cython sequential and OpenMP-threaded RCS benchmark engine."""
import argparse
import struct
import sys
import time
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cython_kernel

def read_profiles(path):
    with open(path, "rb") as stream:
        if stream.read(8) != b"RCSBIN1\x00": raise ValueError(f"Invalid RCS input header: {path}")
        n = int(struct.unpack("<d", stream.read(8))[0])
        matrix_code = np.frombuffer(stream.read(n), dtype=np.uint8).copy()
        governance = np.frombuffer(stream.read(n), dtype=np.uint8).copy()
        severity = np.empty((n, 10), dtype=np.float64, order="C")
        for column in range(10):
            values = np.frombuffer(stream.read(n * 8), dtype="<f8")
            if values.size != n: raise ValueError(f"Truncated RCS input: {path}")
            severity[:, column] = values
    return matrix_code, governance, severity

def write_results(result, path):
    p_bio, score, grade, route = result
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as stream:
        stream.write(b"RCSOUT1\x00")
        stream.write(struct.pack("<d", float(p_bio.size)))
        stream.write(np.asarray(p_bio, dtype="<f8").tobytes())
        stream.write(np.asarray(score, dtype="<f8").tobytes())
        stream.write(np.asarray(grade, dtype=np.uint8).tobytes())
        stream.write(np.asarray(route, dtype=np.uint8).tobytes())

def measured(function):
    start = time.perf_counter_ns(); value = function()
    return value, (time.perf_counter_ns() - start) / 1e9

def calibrate(function, minimum_seconds, maximum_loops):
    _, pilot = measured(function)
    return maximum_loops if pilot <= 0 else max(1, min(maximum_loops, int(np.ceil(minimum_seconds / pilot))))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True); parser.add_argument("--output", required=True)
    parser.add_argument("--implementation", choices=("cython_sequential", "cython_openmp"), required=True)
    parser.add_argument("--workers", "--threads", dest="workers", type=int, default=1)
    parser.add_argument("--warmups", type=int, default=2); parser.add_argument("--min-sec", type=float, default=0.25)
    parser.add_argument("--max-loops", type=int, default=1000000)
    parser.add_argument("--mode", choices=("compute", "e2e"), required=True)
    args = parser.parse_args()
    data, read_sec = measured(lambda: read_profiles(args.input))
    threads = 1 if args.implementation == "cython_sequential" else args.workers
    start_init = time.perf_counter_ns()
    score_once = lambda: cython_kernel.score(*data, threads=threads)
    init_sec = (time.perf_counter_ns() - start_init) / 1e9
    if args.mode == "e2e":
        result, compute_sec = measured(score_once)
        _, write_sec = measured(lambda: write_results(result, args.output))
        internal = read_sec + init_sec + compute_sec + write_sec
        print(f"V2PHASES,{read_sec:.12g},{init_sec:.12g},{compute_sec:.12g},{write_sec:.12g},{internal:.12g}")
        print(f"V2RESULT,{args.implementation},{data[0].size},{threads},1,NA")
        return
    for _ in range(args.warmups): score_once()
    inner_loops = calibrate(score_once, args.min_sec, args.max_loops)
    start = time.perf_counter_ns()
    for _ in range(inner_loops): result = score_once()
    elapsed = (time.perf_counter_ns() - start) / 1e9 / inner_loops
    write_results(result, args.output)
    print(f"V2RESULT,{args.implementation},{data[0].size},{threads},{inner_loops},{elapsed:.12g}")

if __name__ == "__main__": main()
