#!/usr/bin/env bash
set -euo pipefail

if ! command -v gnuplot >/dev/null 2>&1; then
  echo "Error: gnuplot is required for figure generation." >&2
  exit 1
fi

version="$(gnuplot --version 2>/dev/null || true)"
if [[ -z "$version" ]]; then
  echo "Error: gnuplot was found but its version could not be read." >&2
  exit 1
fi

printf 'Figure-generation requirements\n'
printf 'gnuplot: %s\n' "$version"
printf 'Figure-generation requirements passed.\n'
