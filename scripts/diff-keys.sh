#!/usr/bin/env bash
set -euo pipefail

# diff-keys.sh — Compare keys between two env files.
# Reports keys present in FILE1 but missing from FILE2 and vice versa.
# Usage: ./diff-keys.sh <file1> <file2>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: diff-keys.sh FILE1 FILE2"
  echo "Compare keys between two .env files."
  echo "Output: lines prefixed with '- ' (missing from FILE2) or '+ ' (extra in FILE2)."
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

keys1=$("$SCRIPT_DIR/parse.sh" "$file1" | cut -d= -f1)
keys2=$("$SCRIPT_DIR/parse.sh" "$file2" | cut -d= -f1)

found_diff=0

# Keys in file1 but not in file2 (missing from file2)
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  if [[ -n "$IGNORE_KEYS" ]] && echo ",$IGNORE_KEYS," | grep -qF ",$key,"; then
    continue
  fi
  if ! echo "$keys2" | grep -qxF "$key"; then
    echo "- $key"
    found_diff=1
  fi
done <<< "$keys1"

# Keys in file2 but not in file1 (extra in file2)
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  if [[ -n "$IGNORE_KEYS" ]] && echo ",$IGNORE_KEYS," | grep -qF ",$key,"; then
    continue
  fi
  if ! echo "$keys1" | grep -qxF "$key"; then
    echo "+ $key"
    found_diff=1
  fi
done <<< "$keys2"

exit "$found_diff"
