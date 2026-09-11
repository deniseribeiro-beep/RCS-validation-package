#!/usr/bin/env bash
set -euo pipefail

if ! command -v gnuplot >/dev/null 2>&1; then
  echo "Error: gnuplot is required to generate the publication figures." >&2
  exit 1
fi

required_tables=(
  "outputs/tables/Table_Synthetic_Validation_Grade_Distribution.csv"
  "outputs/tables/Table_Combinatorial_Grade_Distribution.csv"
  "outputs/tables/Table_Threshold_Transition_Detail.csv"
  "outputs/tables/Table_Benchmark_Runtime_Summary.csv"
  "outputs/tables/Table_Benchmark_Within_Language_Speedup_Summary.csv"
  "outputs/tables/Table_Benchmark_CUDA_Speedup_Summary.csv"
)

for table in "${required_tables[@]}"; do
  if [[ ! -f "$table" ]]; then
    echo "Error: missing canonical figure input: $table" >&2
    exit 1
  fi
done

mkdir -p outputs/figures

read -r -a output_modes <<< "${OUTPUT_MODES:-pdf png}"
for mode in "${output_modes[@]}"; do
  if [[ "$mode" != "pdf" && "$mode" != "png" ]]; then
    echo "Error: unsupported OUTPUT_MODES entry: $mode" >&2
    exit 1
  fi
  for figure in 1 2 3 4 5 6 7; do
    echo "Generating Figure_${figure}.${mode}"
    gnuplot -e "OUTPUT_MODE='${mode}'" "scripts/gnuplot/Figure_${figure}.gp"
  done
done

echo "All requested publication figures generated from canonical sources."
