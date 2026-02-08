#!/usr/bin/env bash
set -euo pipefail

# parse.sh — Extract KEY=VALUE pairs from an env file.
# Strips comments, blank lines, and normalizes whitespace around '='.
# Usage: ./parse.sh <file>  OR  cat file | ./parse.sh

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: parse.sh [FILE]"
  echo "Extract KEY=VALUE pairs from a .env file."
  echo "Reads from FILE or stdin. Outputs sorted KEY=VALUE lines."
  exit 0
fi

input="${1:--}"

if [[ "$input" != "-" && ! -f "$input" ]]; then
  echo "Error: file not found: $input" >&2
  exit 2
fi

if [[ "$input" == "-" ]]; then
  cat
else
  cat "$input"
fi | \
  sed 's/#.*$//' | \
  sed '/^[[:space:]]*$/d' | \
  sed 's/^[[:space:]]*//' | \
  sed 's/[[:space:]]*$//' | \
  sed 's/[[:space:]]*=[[:space:]]*/=/' | \
  (grep -E '^[A-Za-z_][A-Za-z0-9_]*=' || true) | \
  sort
