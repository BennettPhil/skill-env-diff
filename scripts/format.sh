#!/usr/bin/env bash
set -euo pipefail

# format.sh — Format diff output as text table, JSON, or plain list.
# Reads pipe-delimited lines from stdin.
# Usage: <diff-output> | ./format.sh [--format text|json|list]

FORMAT="${ENV_DIFF_FORMAT:-text}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="$2"; shift 2 ;;
    --help)
      echo "Usage: <input> | format.sh [--format text|json|list]"
      echo "Formats pipe-delimited diff output."
      echo "Formats: text (default), json, list"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

lines=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  lines+=("$line")
done

if [[ ${#lines[@]} -eq 0 ]]; then
  exit 0
fi

case "$FORMAT" in
  json)
    echo "["
    for i in "${!lines[@]}"; do
      IFS='|' read -r col1 col2 col3 <<< "${lines[$i]}"
      comma=","
      [[ $i -eq $((${#lines[@]} - 1)) ]] && comma=""
      if [[ -n "${col3:-}" ]]; then
        echo "  {\"key\": \"$col1\", \"value1\": \"$col2\", \"value2\": \"$col3\"}$comma"
      elif [[ -n "${col2:-}" ]]; then
        echo "  {\"key\": \"$col1\", \"value\": \"$col2\"}$comma"
      else
        echo "  {\"entry\": \"$col1\"}$comma"
      fi
    done
    echo "]"
    ;;
  list)
    for line in "${lines[@]}"; do
      echo "$line" | tr '|' '\t'
    done
    ;;
  text)
    # Determine columns from first line
    IFS='|' read -r _ c2 c3 <<< "${lines[0]}"
    if [[ -n "${c3:-}" ]]; then
      printf "%-30s %-30s %-30s\n" "KEY" "FILE1" "FILE2"
      printf "%-30s %-30s %-30s\n" "---" "-----" "-----"
      for line in "${lines[@]}"; do
        IFS='|' read -r col1 col2 col3 <<< "$line"
        printf "%-30s %-30s %-30s\n" "$col1" "$col2" "$col3"
      done
    else
      for line in "${lines[@]}"; do
        echo "$line"
      done
    fi
    ;;
  *)
    echo "Error: unknown format: $FORMAT" >&2
    exit 2
    ;;
esac
