---
name: env-diff
description: Compare .env files to find missing, extra, and differing variables across environments.
version: 0.1.0
license: Apache-2.0
---

# env-diff

A composable set of shell scripts that compare `.env` files across environments. Find missing variables, detect value differences, and keep your environment configurations in sync.

## Purpose

Managing multiple `.env` files (`.env.example`, `.env.local`, `.env.production`, `.env.staging`) is error-prone. Variables get added to one file but forgotten in others. This skill parses and diffs env files so you can see exactly what is missing, extra, or different between any two (or more) env files.

## Scripts Overview

| Script | Description |
|--------|-------------|
| `scripts/run.sh` | Main entry point — compare two or more env files |
| `scripts/parse.sh` | Extract KEY=VALUE pairs from an env file, normalizing comments and whitespace |
| `scripts/diff-keys.sh` | Compare keys between two env files, report missing and extra |
| `scripts/diff-values.sh` | Compare values for shared keys between two env files |
| `scripts/format.sh` | Format diff output as text table, JSON, or plain list |

## Pipeline Examples

Compare two files with default text output:

```bash
./scripts/run.sh .env.example .env.local
```

Parse a single env file to see its normalized keys:

```bash
./scripts/parse.sh .env.example
```

Find keys missing from production that exist in example:

```bash
./scripts/diff-keys.sh .env.example .env.production
```

Compare values for shared keys and output as JSON:

```bash
./scripts/diff-values.sh .env.example .env.local | ./scripts/format.sh --format json
```

## Inputs and Outputs

All scripts read from file path arguments or stdin. All scripts write to stdout. Exit code 0 means no differences found; exit code 1 means differences exist; exit code 2 means invalid input.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV_DIFF_FORMAT` | `text` | Output format: `text`, `json`, or `list` |
| `ENV_DIFF_IGNORE` | (empty) | Comma-separated keys to ignore in comparisons |
