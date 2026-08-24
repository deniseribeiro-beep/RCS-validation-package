#!/usr/bin/env python3
"""NumPy and persistent-process implementations for RCS benchmark V2."""

import argparse
import struct
import time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np


def read_profiles(path):
    with open(path, "rb") as stream:
        if stream.read(8) != b"RCSBIN1\x00":
            raise ValueError(f"Invalid RCS input header: {path}")
        n = int(struct.unpack("<d", stream.read(8))[0])
        matrix_code = np.frombuffer(stream.read(n), dtype=np.uint8).copy()
        governance = np.frombuffer(stream.read(n), dtype=np.uint8).copy()
        severity = np.empty((n, 10), dtype=np.float64)
        for column in range(10):
            values = np.frombuffer(stream.read(n * 8), dtype="<f8")
            if values.size != n:
                raise ValueError(f"Truncated RCS input: {path}")
            severity[:, column] = values
    return matrix_code, governance, severity


def score_arrays(data):
    matrix_code, governance, severity = data
    fluid_w = np.array([30.0, 15.0, 10.0, 20.0, 25.0])
    solid_w = np.array([25.0, 25.0, 15.0, 20.0, 15.0])
    fluid = matrix_code == 0
    p_bio = np.empty(matrix_code.size, dtype=np.float64)
    p_bio[fluid] = severity[fluid, :5] @ fluid_w
    p_bio[~fluid] = severity[~fluid, 5:] @ solid_w
    score = 100.0 - p_bio
    grade = np.select([score >= 90, score >= 80, score >= 65, score >= 50], [0, 1, 2, 3], default=4).astype(np.uint8)
    route = np.where(governance == 0, 2, np.where(score < 50, 1, 0)).astype(np.uint8)
    grade[governance == 0] = 4
    return p_bio, score, grade, route


def combine(parts):
    return tuple(np.concatenate([part[i] for part in parts]) for i in range(4))


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


def calibrate(function, minimum_seconds, maximum_loops):
    start = time.perf_counter_ns()
    function()
    pilot = (time.perf_counter_ns() - start) / 1e9
    if pilot <= 0:
        return maximum_loops
    return max(1, min(maximum_loops, int(np.ceil(minimum_seconds / pilot))))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--implementation", choices=("python_numpy", "python_process"), required=True)
    parser.add_argument("--workers", type=int, default=1)
    parser.add_argument("--warmups", type=int, default=2)
    parser.add_argument("--min-sec", type=float, default=0.25)
    parser.add_argument("--max-loops", type=int, default=1000000)
    parser.add_argument("--mode", choices=("compute", "e2e"), required=True)
    args = parser.parse_args()
    data = read_profiles(args.input)
    pool = None
    if args.implementation == "python_process":
        pool = ProcessPoolExecutor(max_workers=args.workers)
        indices = np.array_split(np.arange(data[0].size), args.workers)
        chunks = [(data[0][idx], data[1][idx], data[2][idx, :]) for idx in indices]

        def score_once():
            return combine(list(pool.map(score_arrays, chunks)))
    else:
        score_once = lambda: score_arrays(data)

    try:
        if args.mode == "e2e":
            result = score_once()
            write_results(result, args.output)
            print(f"V2RESULT,{args.implementation},{data[0].size},{args.workers},1,NA")
            return
        for _ in range(args.warmups):
            score_once()
        inner_loops = calibrate(score_once, args.min_sec, args.max_loops)
        start = time.perf_counter_ns()
        for _ in range(inner_loops):
            result = score_once()
        elapsed = (time.perf_counter_ns() - start) / 1e9 / inner_loops
        write_results(result, args.output)
        print(f"V2RESULT,{args.implementation},{data[0].size},{args.workers},{inner_loops},{elapsed:.12g}")
    finally:
        if pool is not None:
            pool.shutdown(wait=True)


if __name__ == "__main__":
    main()

