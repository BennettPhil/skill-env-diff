#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

pass() { ((PASS++)); echo "  PASS: $1"; }
fail() { ((FAIL++)); echo "  FAIL: $1 -- $2"; }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc" "expected '$expected', got '$actual'"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    pass "$desc"
  else
    fail "$desc" "output does not contain '$needle'"
  fi
}

assert_exit() {
  local desc="$1" expected="$2"
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  local actual=$?
  set -e
  if [[ "$expected" -eq "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc" "expected exit $expected, got $actual"
  fi
}

echo "Running tests for: env-diff"
echo "================================"

# --- Setup test env files ---
cat > "$TMPDIR/.env.example" << 'EOF'
# Database config
DB_HOST=localhost
DB_PORT=5432
DB_NAME=myapp

# App config
APP_SECRET=changeme
APP_PORT=3000
DEBUG=false
EOF

cat > "$TMPDIR/.env.local" << 'EOF'
DB_HOST=localhost
DB_PORT=5432
DB_NAME=myapp_dev
APP_SECRET=localsecret
APP_PORT=3000
DEBUG=true
EXTRA_LOCAL_VAR=hello
EOF

cat > "$TMPDIR/.env.production" << 'EOF'
DB_HOST=prod-db.example.com
DB_PORT=5432
DB_NAME=myapp_prod
APP_SECRET=supersecret
APP_PORT=8080
EOF

# --- parse.sh tests ---
echo ""
echo "parse.sh:"

result=$("$SCRIPT_DIR/parse.sh" "$TMPDIR/.env.example")
assert_contains "strips comments" "DB_HOST=localhost" "$result"
line_count=$(echo "$result" | wc -l | tr -d ' ')
assert_eq "parses all keys from example" "6" "$line_count"
assert_contains "includes APP_PORT" "APP_PORT=3000" "$result"

# --- diff-keys.sh tests ---
echo ""
echo "diff-keys.sh:"

result=$("$SCRIPT_DIR/diff-keys.sh" "$TMPDIR/.env.example" "$TMPDIR/.env.local" 2>&1) || true
assert_contains "finds extra key EXTRA_LOCAL_VAR" "+ EXTRA_LOCAL_VAR" "$result"

result2=$("$SCRIPT_DIR/diff-keys.sh" "$TMPDIR/.env.example" "$TMPDIR/.env.production" 2>&1) || true
assert_contains "finds missing DEBUG in prod" "- DEBUG" "$result2"

result3=$("$SCRIPT_DIR/diff-keys.sh" "$TMPDIR/.env.local" "$TMPDIR/.env.production" 2>&1) || true
assert_contains "finds missing EXTRA_LOCAL_VAR in prod" "- EXTRA_LOCAL_VAR" "$result3"

# --- diff-values.sh tests ---
echo ""
echo "diff-values.sh:"

result=$("$SCRIPT_DIR/diff-values.sh" "$TMPDIR/.env.example" "$TMPDIR/.env.local" 2>&1) || true
assert_contains "detects DB_NAME difference" "DB_NAME" "$result"
assert_contains "detects APP_SECRET difference" "APP_SECRET" "$result"

# --- run.sh tests ---
echo ""
echo "run.sh:"

result=$("$SCRIPT_DIR/run.sh" "$TMPDIR/.env.example" "$TMPDIR/.env.local" 2>&1) || true
assert_contains "run.sh shows extra keys" "Extra in" "$result"
assert_contains "run.sh shows value diffs" "Value differences" "$result"

result_prod=$("$SCRIPT_DIR/run.sh" "$TMPDIR/.env.example" "$TMPDIR/.env.production" 2>&1) || true
assert_contains "run.sh shows missing keys for prod" "Missing from" "$result_prod"

assert_exit "run.sh fails with no args" 2 "$SCRIPT_DIR/run.sh"
assert_exit "run.sh fails with one arg" 2 "$SCRIPT_DIR/run.sh" "$TMPDIR/.env.example"
assert_exit "run.sh fails with missing file" 2 "$SCRIPT_DIR/run.sh" "$TMPDIR/.env.example" "$TMPDIR/nonexistent"

# --- format.sh tests ---
echo ""
echo "format.sh:"

result=$(echo "DB_NAME|myapp|myapp_dev" | "$SCRIPT_DIR/format.sh" --format json)
assert_contains "json format has key" '"key": "DB_NAME"' "$result"
assert_contains "json format has value1" '"value1": "myapp"' "$result"

result=$(echo "DB_NAME|myapp|myapp_dev" | "$SCRIPT_DIR/format.sh" --format list)
assert_eq "list format uses tabs" "DB_NAME	myapp	myapp_dev" "$result"

# --- Edge cases ---
echo ""
echo "Edge cases:"

cat > "$TMPDIR/.env.empty" << 'EOF'
# Only comments here

EOF

result=$("$SCRIPT_DIR/parse.sh" "$TMPDIR/.env.empty")
assert_eq "empty file parses to empty" "" "$result"

cat > "$TMPDIR/.env.spaces" << 'EOF'
  KEY_WITH_SPACES  =  value with spaces
NORMAL=ok
EOF

result=$("$SCRIPT_DIR/parse.sh" "$TMPDIR/.env.spaces")
assert_contains "handles spaces around =" "KEY_WITH_SPACES=value with spaces" "$result"

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
