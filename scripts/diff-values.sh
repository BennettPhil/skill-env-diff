#!/usr/bin/env bash
set -euo pipefail

# diff-values.sh — Compare values for shared keys between two env files.
# Usage: ./diff-values.sh <file1> <file2>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: diff-values.sh FILE1 FILE2"
  echo "Compare values for keys present in both files."
  echo "Output: KEY | VALUE1 | VALUE2  (only for differing values)."
  exit 0
fi

if [[ $# -lt 2 ]]; then
  echo "Error: two file arguments required" >&2
  exit 2
fi

file1="$1"
file2="$2"

for f in "$file1" "$file2"; do
  if [[ ! -f "$f" ]]; then
    echo "Error: file not found: $f" >&2
    exit 2
  fi
done

IGNORE_KEYS="${ENV_DIFF_IGNORE:-}"

parsed1=$("$SCRIPT_DIR/parse.sh" "$file1")
parsed2=$("$SCRIPT_DIR/parse.sh" "$file2")

found_diff=0

while IFS='=' read -r key val1; do
  [[ -z "$key" ]] && continue
  if [[ -n "$IGNORE_KEYS" ]] && echo ",$IGNORE_KEYS," | grep -qF ",$key,"; then
    continue
  fi
  val2_line=$(echo "$parsed2" | grep -m1 "^${key}=" || true)
  if [[ -n "$val2_line" ]]; then
    val2="${val2_line#*=}"
    if [[ "$val1" != "$val2" ]]; then
      echo "$key|$val1|$val2"
      found_diff=1
    fi
  fi
done <<< "$parsed1"

exit "$found_diff"
