# env-diff Examples

## Basic comparison of two files

```bash
$ cat .env.example
DATABASE_URL=postgres://localhost/myapp
REDIS_URL=redis://localhost:6379
SECRET_KEY=changeme
DEBUG=true

$ cat .env.local
DATABASE_URL=postgres://localhost/myapp_dev
REDIS_URL=redis://localhost:6379
API_KEY=sk-abc123

$ env-diff .env.example .env.local
Comparing: .env.example, .env.local

MISSING KEYS:
  SECRET_KEY
    present in: .env.example
    missing from: .env.local
  DEBUG
    present in: .env.example
    missing from: .env.local
  API_KEY
    present in: .env.local
    missing from: .env.example

DIFFERENT VALUES:
  DATABASE_URL
    .env.example: p***e
    .env.local: p***v

OK: 1 variable(s) in sync across all files.
```

## Using --base to compare against a reference

```bash
$ env-diff --base=.env.example .env.example .env.local .env.production
Comparing: .env.example, .env.local, .env.production

MISSING KEYS:
  SECRET_KEY
    present in: .env.example
    missing from: .env.local

EXTRA KEYS:
  API_KEY
    extra in: .env.local
    not in base: .env.example

DIFFERENT VALUES:
  DATABASE_URL
    .env.example: p***e
    .env.local: p***v
    .env.production: p***n

OK: 2 variable(s) in sync across all files.
```

## Showing actual values

```bash
$ env-diff --values .env.example .env.local
Comparing: .env.example, .env.local

DIFFERENT VALUES:
  DATABASE_URL
    .env.example: postgres://localhost/myapp
    .env.local: postgres://localhost/myapp_dev
```

## JSON output

```bash
$ env-diff --format=json .env.example .env.local
{
  "in_sync": false,
  "files": [".env.example", ".env.local"],
  "missing": [
    {
      "key": "SECRET_KEY",
      "present_in": [".env.example"],
      "missing_from": [".env.local"]
    }
  ],
  "extra": [],
  "different": [
    {
      "key": "DATABASE_URL",
      "files": {
        ".env.example": "p***e",
        ".env.local": "p***v"
      }
    }
  ],
  "ok": ["REDIS_URL"]
}
```

## Identical files

```bash
$ env-diff .env .env.backup
Comparing: .env, .env.backup

All files are in sync.
3 variable(s) present in all files with matching values.
```

## Edge cases handled

```env
# Comments are ignored
  # Indented comments too

# Empty values
EMPTY_VAR=

# Quoted values (quotes are stripped)
QUOTED="hello world"
SINGLE_QUOTED='hello world'

# Lines without = are skipped
this is not a variable

# Trailing whitespace is trimmed
PADDED=value   
```
