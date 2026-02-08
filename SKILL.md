---
name: env-diff
description: Compare .env files and show missing, extra, and different variables across environments
version: 0.1.0
license: Apache-2.0
tags:
  - env
  - diff
  - devops
  - configuration
---

# env-diff

Compare two or more `.env` files side-by-side. Quickly spot which variables are missing, extra, or have different values across your environments.

## Usage

```bash
# Compare two files
env-diff .env.example .env.local

# Compare against a base reference
env-diff --base=.env.example .env.local .env.production

# Show actual values (masked by default)
env-diff --values .env.example .env.local

# JSON output
env-diff --format=json .env.example .env.local
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0    | All files have the same keys |
| 1    | Differences found (missing, extra, or different values) |
| 2    | Error (file not found, parse error, etc.) |

## Features

- Parses standard `.env` format (KEY=VALUE)
- Skips comments (`#`) and empty lines
- Handles quoted values (single and double quotes)
- Handles empty values (`KEY=`)
- Handles BOM and trailing whitespace
- Masks values by default for security
- Supports text and JSON output formats
- Compares 2 or more files at once
