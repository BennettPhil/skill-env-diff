#!/usr/bin/env bash
set -euo pipefail

# run.sh — Main entry point for env-diff.
# Compare two or more .env files and report differences.
# Usage: ./run.sh [OPTIONS] FILE1 FILE2 [FILE3 ...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORMAT="${ENV_DIFF_FORMAT:-text}"
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="$2"; shift 2 ;;
    --ignore) export ENV_DIFF_IGNORE="$2"; shift 2 ;;
    --help)
      echo "Usage: run.sh [OPTIONS] FILE1 FILE2 [FILE3 ...]"
      echo ""
      echo "Compare .env files and show differences."
      echo ""
      echo "Options:"
      echo "  --format text|json|list   Output format (default: text)"
      echo "  --ignore KEY1,KEY2        Comma-separated keys to ignore"
      echo "  --help                    Show this help"
      exit 0
      ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

if [[ ${#FILES[@]} -lt 2 ]]; then
  echo "Error: at least two .env files required" >&2
  echo "Usage: run.sh FILE1 FILE2 [FILE3 ...]" >&2
  exit 2
fi

for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "Error: file not found: $f" >&2
    exit 2
  fi
done

export ENV_DIFF_FORMAT="$FORMAT"
has_diff=0

# Compare each pair: first file is the baseline
baseline="${FILES[0]}"

for ((i = 1; i < ${#FILES[@]}; i++)); do
  target="${FILES[$i]}"
  base_name=$(basename "$baseline")
  target_name=$(basename "$target")

  echo "=== Comparing $base_name <-> $target_name ==="
  echo ""

  # Key differences
  key_diff=$("$SCRIPT_DIR/diff-keys.sh" "$baseline" "$target" 2>&1) && key_rc=0 || key_rc=$?
  if [[ $key_rc -eq 1 ]]; then
    has_diff=1
    missing=$(echo "$key_diff" | grep '^- ' || true)
    extra=$(echo "$key_diff" | grep '^+ ' || true)

    if [[ -n "$missing" ]]; then
      echo "Missing from $target_name (present in $base_name):"
      echo "$missing" | sed 's/^- /  /'
      echo ""
    fi
    if [[ -n "$extra" ]]; then
      echo "Extra in $target_name (not in $base_name):"
      echo "$extra" | sed 's/^+ /  /'
      echo ""
    fi
  elif [[ $key_rc -ge 2 ]]; then
    echo "Error comparing keys: $key_diff" >&2
    exit 2
  fi

  # Value differences
  val_diff=$("$SCRIPT_DIR/diff-values.sh" "$baseline" "$target" 2>&1) && val_rc=0 || val_rc=$?
  if [[ $val_rc -eq 1 ]]; then
    has_diff=1
    echo "Value differences:"
    echo "$val_diff" | "$SCRIPT_DIR/format.sh" --format "$FORMAT"
    echo ""
  elif [[ $val_rc -ge 2 ]]; then
    echo "Error comparing values: $val_diff" >&2
    exit 2
  fi

  if [[ $key_rc -eq 0 && $val_rc -eq 0 ]]; then
    echo "No differences found."
    echo ""
  fi
done

exit "$has_diff"
