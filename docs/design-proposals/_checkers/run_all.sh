#!/usr/bin/env bash
# Runs every checker the Design 6 audit cites, from the design-proposals directory.
# Exit status is the number of checkers that reported a defect.
set -u
cd "$(dirname "$0")/.."
fail=0
for c in refcheck dupcheck closurecheck semcheck; do
  echo "=== $c ==="
  python3 "_checkers/$c.py" || fail=$((fail + 1))
done
echo "=== pipecheck ==="
total=0
for f in *.md; do
  n=$(python3 "_checkers/pipecheck.py" "$f" | tail -1 | tr -dc '0-9')
  total=$((total + n))
done
echo "broken table cells across $(ls *.md | wc -l) files: $total"
[ "$total" -eq 0 ] || fail=$((fail + 1))
echo
echo "checkers reporting a defect: $fail"
exit "$fail"
