#!/usr/bin/env bash
set -euo pipefail

lexical_absolute_path() {
  local path="$1"
  local part
  local last_index
  local -a input_parts=()
  local -a output_parts=()

  if [[ "$path" != /* ]]; then
    path="${PWD}/${path}"
  fi

  IFS='/' read -r -a input_parts <<< "$path"
  for part in "${input_parts[@]}"; do
    case "$part" in
      ""|.) ;;
      ..)
        if ((${#output_parts[@]} > 0)); then
          last_index=$((${#output_parts[@]} - 1))
          unset "output_parts[$last_index]"
        fi
        ;;
      *) output_parts+=("$part") ;;
    esac
  done

  if ((${#output_parts[@]} == 0)); then
    printf '/\n'
    return
  fi

  printf '/%s' "${output_parts[0]}"
  for ((i = 1; i < ${#output_parts[@]}; ++i)); do
    printf '/%s' "${output_parts[$i]}"
  done
  printf '\n'
}

canonicalize_guard_path() {
  local lexical candidate base part
  local -a suffix=()

  lexical="$(lexical_absolute_path "$1")"
  candidate="$lexical"

  while [[ ! -e "$candidate" && "$candidate" != "/" ]]; do
    suffix=("$(basename "$candidate")" "${suffix[@]}")
    candidate="$(dirname "$candidate")"
  done

  if [[ -d "$candidate" ]]; then
    base="$(cd "$candidate" && pwd -P)"
  elif [[ -e "$candidate" ]]; then
    base="$(cd "$(dirname "$candidate")" && pwd -P)/$(basename "$candidate")"
  else
    base="$candidate"
  fi

  for part in "${suffix[@]}"; do
    base="${base%/}/${part}"
  done

  lexical_absolute_path "$base"
}

scope="${RCS_RUN_SCOPE:-local}"
case "$scope" in
  local|smoke|publication) ;;
  *)
    echo "Error: RCS_RUN_SCOPE must be local, smoke, or publication." >&2
    exit 1
    ;;
esac

allow_publication_write="${RCS_ALLOW_PUBLICATION_WRITE:-FALSE}"
if [[ "$scope" == "publication" && "$allow_publication_write" != "TRUE" ]]; then
  echo "Error: publication output is protected. Set RCS_ALLOW_PUBLICATION_WRITE=TRUE only for the deliberate final publication run." >&2
  exit 1
fi

if [[ -n "${RCS_OUTPUT_ROOT:-}" ]]; then
  root="${RCS_OUTPUT_ROOT}"
else
  case "$scope" in
    local) root="outputs/local" ;;
    smoke) root="outputs/smoke" ;;
    publication) root="results/publication" ;;
  esac
fi

protected_root="$(canonicalize_guard_path "results/publication")"
resolved_root="$(canonicalize_guard_path "$root")"
if [[ "$resolved_root" == "$protected_root" || "$resolved_root" == "$protected_root/"* ]]; then
  if [[ "$allow_publication_write" != "TRUE" ]]; then
    echo "Error: publication output is protected. RCS_OUTPUT_ROOT resolves inside results/publication; set RCS_ALLOW_PUBLICATION_WRITE=TRUE only for the deliberate final publication run." >&2
    exit 1
  fi
fi

bash scripts/check_figure_requirements.sh

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
