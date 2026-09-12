#!/usr/bin/env bash
set -euo pipefail

if ! command -v gnuplot >/dev/null 2>&1; then
  echo "Error: gnuplot is required to generate the publication figures." >&2
  exit 1
fi

scope="${RCS_RUN_SCOPE:-local}"
if [[ -n "${RCS_OUTPUT_ROOT:-}" ]]; then
  root="${RCS_OUTPUT_ROOT}"
else
  case "${scope}" in
    local) root="outputs/local" ;;
    smoke) root="outputs/smoke" ;;
    publication)
      if [[ "${RCS_ALLOW_PUBLICATION_WRITE:-FALSE}" != "TRUE" ]]; then
        echo "Error: publication output is protected. Set RCS_ALLOW_PUBLICATION_WRITE=TRUE only for the deliberate final publication run." >&2
        exit 1
      fi
      root="results/publication"
      ;;
    *)
      echo "Error: RCS_RUN_SCOPE must be local, smoke, or publication." >&2
      exit 1
      ;;
  esac
fi

tables_dir="${root}/tables"
figures_dir="${root}/figures"

required_tables=(
  "${tables_dir}/Table_Synthetic_Validation_Grade_Distribution.csv"
  "${tables_dir}/Table_Combinatorial_Grade_Distribution.csv"
  "${tables_dir}/Table_Threshold_Transition_Detail.csv"
  "${tables_dir}/Table_Benchmark_Runtime_Summary.csv"
  "${tables_dir}/Table_Benchmark_Within_Language_Speedup_Summary.csv"
  "${tables_dir}/Table_Benchmark_CUDA_Speedup_Summary.csv"
)

for table in "${required_tables[@]}"; do
  if [[ ! -f "$table" ]]; then
    echo "Error: missing figure input: $table" >&2
    exit 1
  fi
done

mkdir -p "${figures_dir}"
rm -f "${figures_dir}/Figure_1.pdf" "${figures_dir}/Figure_1.png"

read -r -a output_modes <<< "${OUTPUT_MODES:-pdf png}"
for mode in "${output_modes[@]}"; do
  if [[ "$mode" != "pdf" && "$mode" != "png" ]]; then
    echo "Error: unsupported OUTPUT_MODES entry: $mode" >&2
    exit 1
  fi
  for figure in 2 3 4 5 6 7; do
    echo "Generating Figure_${figure}.${mode}"
    gnuplot -e "OUTPUT_MODE='${mode}';TABLES_DIR='${tables_dir}';OUTPUT_DIR='${figures_dir}'" "scripts/gnuplot/Figure_${figure}.gp"
  done
done

echo "Figures 2 through 7 generated from ${tables_dir}."
