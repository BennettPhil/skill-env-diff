#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN="$SCRIPT_DIR/main.py"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

PASS=0
FAIL=0
TOTAL=0

run_test() {
    local test_name="$1"
    shift
    TOTAL=$((TOTAL + 1))
    echo "--- TEST: $test_name"
    if "$@"; then
        PASS=$((PASS + 1))
        echo "  PASS"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL"
    fi
}

# ------------------------------------------------------------------
# Test 1: Two identical files -> exit 0, "in sync"
# ------------------------------------------------------------------
test_identical_files() {
    cat > "$TMPDIR_TEST/a.env" << 'EOF'
DB_HOST=localhost
DB_PORT=5432
SECRET=abc123
EOF
    cp "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/b.env"

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/b.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "  Expected exit 0, got $rc"
        echo "  Output: $output"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "in sync"; then
        echo "  Expected 'in sync' in output"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "Two identical files -> exit 0, in sync" test_identical_files

# ------------------------------------------------------------------
# Test 2: File with missing key -> exit 1, shows missing key
# ------------------------------------------------------------------
test_missing_key() {
    cat > "$TMPDIR_TEST/base.env" << 'EOF'
DB_HOST=localhost
DB_PORT=5432
SECRET=abc123
EOF
    cat > "$TMPDIR_TEST/local.env" << 'EOF'
DB_HOST=localhost
DB_PORT=5432
EOF

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/base.env" "$TMPDIR_TEST/local.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 1 ]; then
        echo "  Expected exit 1, got $rc"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "SECRET"; then
        echo "  Expected 'SECRET' in output"
        echo "  Output: $output"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "missing"; then
        echo "  Expected 'missing' in output"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "File with missing key -> exit 1, shows missing key" test_missing_key

# ------------------------------------------------------------------
# Test 3: File with extra key -> exit 1, shows extra key
# ------------------------------------------------------------------
test_extra_key() {
    cat > "$TMPDIR_TEST/base.env" << 'EOF'
DB_HOST=localhost
EOF
    cat > "$TMPDIR_TEST/local.env" << 'EOF'
DB_HOST=localhost
EXTRA_VAR=something
EOF

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/base.env" "$TMPDIR_TEST/local.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 1 ]; then
        echo "  Expected exit 1, got $rc"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "EXTRA_VAR"; then
        echo "  Expected 'EXTRA_VAR' in output"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "File with extra key -> exit 1, shows extra key" test_extra_key

# ------------------------------------------------------------------
# Test 4: Different values for same key
# ------------------------------------------------------------------
test_different_values() {
    cat > "$TMPDIR_TEST/a.env" << 'EOF'
DB_HOST=localhost
DB_PORT=5432
EOF
    cat > "$TMPDIR_TEST/b.env" << 'EOF'
DB_HOST=remotehost
DB_PORT=5432
EOF

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/b.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 1 ]; then
        echo "  Expected exit 1, got $rc"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "DIFFERENT VALUES"; then
        echo "  Expected 'DIFFERENT VALUES' in output"
        echo "  Output: $output"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "DB_HOST"; then
        echo "  Expected 'DB_HOST' in output"
        echo "  Output: $output"
        return 1
    fi
    # Values should be masked by default
    if echo "$output" | grep -qF -- "localhost"; then
        echo "  Values should be masked by default"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "Different values for same key -> shows difference (masked)" test_different_values

# ------------------------------------------------------------------
# Test 5: --values flag shows actual values
# ------------------------------------------------------------------
test_values_flag() {
    cat > "$TMPDIR_TEST/a.env" << 'EOF'
DB_HOST=localhost
EOF
    cat > "$TMPDIR_TEST/b.env" << 'EOF'
DB_HOST=remotehost
EOF

    local output rc
    output="$(python3 "$MAIN" --values "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/b.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 1 ]; then
        echo "  Expected exit 1, got $rc"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "localhost"; then
        echo "  Expected 'localhost' in output with --values"
        echo "  Output: $output"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "remotehost"; then
        echo "  Expected 'remotehost' in output with --values"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "--values flag shows actual values" test_values_flag

# ------------------------------------------------------------------
# Test 6: --base flag works
# ------------------------------------------------------------------
test_base_flag() {
    cat > "$TMPDIR_TEST/example.env" << 'EOF'
DB_HOST=localhost
DB_PORT=5432
SECRET=changeme
EOF
    cat > "$TMPDIR_TEST/local.env" << 'EOF'
DB_HOST=localhost
DB_PORT=5432
EXTRA=bonus
EOF

    local output rc
    output="$(python3 "$MAIN" --base="$TMPDIR_TEST/example.env" "$TMPDIR_TEST/example.env" "$TMPDIR_TEST/local.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 1 ]; then
        echo "  Expected exit 1, got $rc"
        return 1
    fi
    # SECRET should show as missing from local
    if ! echo "$output" | grep -qF -- "SECRET"; then
        echo "  Expected 'SECRET' in missing output"
        echo "  Output: $output"
        return 1
    fi
    # EXTRA should show as extra in local
    if ! echo "$output" | grep -qF -- "EXTRA"; then
        echo "  Expected 'EXTRA' in extra output"
        echo "  Output: $output"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "EXTRA KEYS"; then
        echo "  Expected 'EXTRA KEYS' section"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "--base flag works" test_base_flag

# ------------------------------------------------------------------
# Test 7: Comments and empty lines are ignored
# ------------------------------------------------------------------
test_comments_and_blanks() {
    cat > "$TMPDIR_TEST/a.env" << 'EOF'
# This is a comment
DB_HOST=localhost

  # Indented comment
DB_PORT=5432
EOF
    cat > "$TMPDIR_TEST/b.env" << 'EOF'
DB_HOST=localhost
DB_PORT=5432
EOF

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/b.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "  Expected exit 0 (comments/blanks ignored), got $rc"
        echo "  Output: $output"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "in sync"; then
        echo "  Expected 'in sync' in output"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "Comments and empty lines are ignored" test_comments_and_blanks

# ------------------------------------------------------------------
# Test 8: Quoted values are handled
# ------------------------------------------------------------------
test_quoted_values() {
    cat > "$TMPDIR_TEST/a.env" << 'EOF'
MSG="hello world"
SINGLE='foo bar'
PLAIN=noquotes
EOF
    cat > "$TMPDIR_TEST/b.env" << 'EOF'
MSG=hello world
SINGLE=foo bar
PLAIN=noquotes
EOF

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/b.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "  Expected exit 0 (quotes stripped), got $rc"
        echo "  Output: $output"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "in sync"; then
        echo "  Expected 'in sync' in output"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "Quoted values are handled" test_quoted_values

# ------------------------------------------------------------------
# Test 9: Non-existent file -> exit 2
# ------------------------------------------------------------------
test_nonexistent_file() {
    cat > "$TMPDIR_TEST/a.env" << 'EOF'
DB_HOST=localhost
EOF

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/nonexistent.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 2 ]; then
        echo "  Expected exit 2, got $rc"
        echo "  Output: $output"
        return 1
    fi
    if ! echo "$output" | grep -qF -- "not found"; then
        echo "  Expected 'not found' in error output"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "Non-existent file -> exit 2" test_nonexistent_file

# ------------------------------------------------------------------
# Test 10: JSON output format
# ------------------------------------------------------------------
test_json_output() {
    cat > "$TMPDIR_TEST/a.env" << 'EOF'
DB_HOST=localhost
SECRET=abc
EOF
    cat > "$TMPDIR_TEST/b.env" << 'EOF'
DB_HOST=localhost
EOF

    local output rc
    output="$(python3 "$MAIN" --format=json "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/b.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 1 ]; then
        echo "  Expected exit 1, got $rc"
        return 1
    fi
    # Validate it's JSON by checking for expected keys
    if ! echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['in_sync'] == False" 2>/dev/null; then
        echo "  Expected valid JSON with in_sync=false"
        echo "  Output: $output"
        return 1
    fi
    if ! echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert any(m['key']=='SECRET' for m in d['missing'])" 2>/dev/null; then
        echo "  Expected SECRET in missing keys in JSON"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "JSON output format" test_json_output

# ------------------------------------------------------------------
# Test 11: Three files compared
# ------------------------------------------------------------------
test_three_files() {
    cat > "$TMPDIR_TEST/a.env" << 'EOF'
DB_HOST=localhost
DB_PORT=5432
SECRET=abc
EOF
    cat > "$TMPDIR_TEST/b.env" << 'EOF'
DB_HOST=localhost
DB_PORT=3306
SECRET=abc
EOF
    cat > "$TMPDIR_TEST/c.env" << 'EOF'
DB_HOST=localhost
DB_PORT=5432
EXTRA=bonus
EOF

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/b.env" "$TMPDIR_TEST/c.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 1 ]; then
        echo "  Expected exit 1, got $rc"
        return 1
    fi
    # SECRET is missing from c
    if ! echo "$output" | grep -qF -- "SECRET"; then
        echo "  Expected 'SECRET' in output (missing from c)"
        echo "  Output: $output"
        return 1
    fi
    # EXTRA is missing from a and b
    if ! echo "$output" | grep -qF -- "EXTRA"; then
        echo "  Expected 'EXTRA' in output (missing from a and b)"
        echo "  Output: $output"
        return 1
    fi
    # DB_PORT differs between a/c and b
    if ! echo "$output" | grep -qF -- "DB_PORT"; then
        echo "  Expected 'DB_PORT' in different values"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "Three files compared" test_three_files

# ------------------------------------------------------------------
# Test 12: Empty values handled
# ------------------------------------------------------------------
test_empty_values() {
    cat > "$TMPDIR_TEST/a.env" << 'EOF'
EMPTY_VAR=
ANOTHER=hello
EOF
    cat > "$TMPDIR_TEST/b.env" << 'EOF'
EMPTY_VAR=
ANOTHER=hello
EOF

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/b.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "  Expected exit 0 (empty values match), got $rc"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "Empty values handled" test_empty_values

# ------------------------------------------------------------------
# Test 13: Lines without = are skipped
# ------------------------------------------------------------------
test_lines_without_equals() {
    cat > "$TMPDIR_TEST/a.env" << 'EOF'
DB_HOST=localhost
this line has no equals sign
DB_PORT=5432
EOF
    cat > "$TMPDIR_TEST/b.env" << 'EOF'
DB_HOST=localhost
another invalid line
DB_PORT=5432
EOF

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/b.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "  Expected exit 0 (invalid lines skipped), got $rc"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "Lines without = are skipped" test_lines_without_equals

# ------------------------------------------------------------------
# Test 14: Trailing whitespace handled
# ------------------------------------------------------------------
test_trailing_whitespace() {
    # Use printf to ensure trailing spaces are preserved
    printf 'DB_HOST=localhost   \nDB_PORT=5432\n' > "$TMPDIR_TEST/a.env"
    printf 'DB_HOST=localhost\nDB_PORT=5432\n' > "$TMPDIR_TEST/b.env"

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/a.env" "$TMPDIR_TEST/b.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "  Expected exit 0 (trailing whitespace trimmed), got $rc"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "Trailing whitespace handled" test_trailing_whitespace

# ------------------------------------------------------------------
# Test 15: BOM handled
# ------------------------------------------------------------------
test_bom() {
    # Write a file with BOM
    printf '\xEF\xBB\xBFDB_HOST=localhost\nDB_PORT=5432\n' > "$TMPDIR_TEST/bom.env"
    printf 'DB_HOST=localhost\nDB_PORT=5432\n' > "$TMPDIR_TEST/nobom.env"

    local output rc
    output="$(python3 "$MAIN" "$TMPDIR_TEST/bom.env" "$TMPDIR_TEST/nobom.env" 2>&1)" && rc=$? || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "  Expected exit 0 (BOM handled), got $rc"
        echo "  Output: $output"
        return 1
    fi
    return 0
}
run_test "BOM handled" test_bom

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo ""
echo "================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
