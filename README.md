# env-diff

Compare `.env` files to find missing, extra, and differing variables across environments.

## Quick Start

```bash
./scripts/run.sh .env.example .env.local
```

## Prerequisites

- Bash 4+
- Standard Unix tools (grep, sed, sort, cut)

## Usage

```bash
# Compare two files
./scripts/run.sh .env.example .env.production

# Compare with JSON output
./scripts/run.sh --format json .env.example .env.local

# Ignore specific keys
./scripts/run.sh --ignore "DEBUG,APP_SECRET" .env.example .env.production

# Compare multiple files against a baseline
./scripts/run.sh .env.example .env.local .env.production
```

## Individual Scripts

Each script in `scripts/` works independently:

```bash
# Parse and normalize an env file
./scripts/parse.sh .env.example

# Find missing/extra keys
./scripts/diff-keys.sh .env.example .env.local

# Find value differences
./scripts/diff-values.sh .env.example .env.local

# Format output
./scripts/diff-values.sh .env.example .env.local | ./scripts/format.sh --format json
```

## Run Tests

```bash
./scripts/test.sh
```
