#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

required_files=(
  README.md
  ARTIFACT_EVALUATION.md
  IEEE_SUBMISSION_CHECKLIST.md
  BENCHMARK_PROTOCOL.md
  VALIDATION_PROTOCOL.md
  SCIENTIFIC_SPECIFICATION.md
  CITATION.cff
  .zenodo.json
  requirements-python.txt
  requirements-r.txt
  SHA256SUMS
  results/publication/tables/Table_Benchmark_Quality_Gates.csv
  results/publication/tables/Table_Benchmark_Equivalence_Check.csv
)

for path in "${required_files[@]}"; do
  test -s "$path" || { echo "Missing or empty required artifact: $path" >&2; exit 1; }
done

grep -Fq 'version: "1.0.0"' CITATION.cff
grep -Fq 'A Governance-Aware Rule-Based Computational Method' README.md
grep -Fq 'A Governance-Aware Rule-Based Computational Method' ARTIFACT_EVALUATION.md

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum --check SHA256SUMS
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 --check SHA256SUMS
else
  echo "No SHA-256 checksum utility found. Install sha256sum or use the macOS shasum utility." >&2
  exit 1
fi

python3 - <<'PY'
import csv
import json
from pathlib import Path

metadata = json.loads(Path(".zenodo.json").read_text(encoding="utf-8"))
assert metadata["version"] == "1.0.0"
assert metadata["upload_type"] == "software"
assert metadata["access_right"] == "open"
assert metadata["license"] == "MIT"
assert metadata["language"] == "eng"
assert "doi" not in metadata
assert len(metadata["creators"]) == 4
expected_creators = [
    ("Ribeiro, Denise", "0000-0001-9365-4924"),
    ("Andrijauskas, Fábio", "0000-0002-1254-8570"),
    ("de Carvalho, Lucas Miguel", "0000-0002-8766-0452"),
    ("Becerra Sablón, Vicente Idalberto", "0000-0003-3127-1906"),
]
assert [
    (creator["name"], creator["orcid"]) for creator in metadata["creators"]
] == expected_creators

with Path("results/publication/tables/Table_Benchmark_Quality_Gates.csv").open(
    newline="", encoding="utf-8"
) as stream:
    rows = list(csv.DictReader(stream))
assert len(rows) == 1
row = rows[0]
assert row["computational_reference"] == "C reference"
assert row["equivalence_gate_passed"] == "TRUE"
assert row["calibrated_compute_measurements"] == "4200"
assert row["calibrated_compute_measurements_passing"] == "4200"
assert row["stable_compute_conditions"] == "139"
assert row["compute_timing_conditions"] == "140"
assert row["all_quality_gates_passed"] == "TRUE"

with Path("results/publication/tables/Table_Benchmark_Equivalence_Check.csv").open(
    newline="", encoding="utf-8"
) as stream:
    equivalence = list(csv.DictReader(stream))
assert equivalence
assert all(row["reference_implementation"] == "C reference" for row in equivalence)
assert all(row["all_equivalence_checks_passed"] == "TRUE" for row in equivalence)
assert all(float(row["max_abs_pbio_diff"]) <= 1e-9 for row in equivalence)
assert all(float(row["max_abs_rcs_diff"]) <= 1e-9 for row in equivalence)

print("Release metadata and retained quality gates passed.")
PY

if command -v pdfinfo >/dev/null 2>&1 && command -v pdffonts >/dev/null 2>&1; then
  for number in 2 3 4 5 6 7; do
    pdf="results/publication/figures/Figure_${number}.pdf"
    test -s "$pdf"
    pages="$(pdfinfo "$pdf" | awk '/^Pages:/ {print $2}')"
    test "$pages" = "1" || { echo "$pdf must contain exactly one page." >&2; exit 1; }
    if pdffonts "$pdf" | awk 'NR > 2 && $(NF-4) != "yes" {exit 1}'; then
      :
    else
      echo "$pdf contains a font that is not embedded." >&2
      exit 1
    fi
  done
else
  echo "Warning: pdfinfo/pdffonts unavailable; PDF structural checks skipped." >&2
fi

echo "Release artifact verification passed."
