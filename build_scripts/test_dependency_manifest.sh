#!/bin/bash
# Regression tests for safe dependency-manifest synchronization.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync_dependency_manifest.sh"
UPSTREAM_SOURCE="$REPO_ROOT/aria2-next/packaging/dependencies.env"
LOCAL_SOURCE="$SCRIPT_DIR/versions.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

reset_fixture() {
    cp "$UPSTREAM_SOURCE" "$WORK/dependencies.env"
    cp "$LOCAL_SOURCE" "$WORK/versions.sh"
}

# The current reviewed baseline must be a no-op.
reset_fixture
cp "$WORK/versions.sh" "$WORK/versions.before"
bash "$SYNC_SCRIPT" "$WORK/dependencies.env" "$WORK/versions.sh" >/dev/null
cmp -s "$WORK/versions.before" "$WORK/versions.sh" || \
    fail "current dependency baseline was unexpectedly rewritten"

# A vendored version is descriptive metadata and follows the pinned source.
reset_fixture
sed -i 's/^CURL_VERSION=.*/CURL_VERSION=9.99.0/' "$WORK/dependencies.env"
bash "$SYNC_SCRIPT" "$WORK/dependencies.env" "$WORK/versions.sh" >/dev/null
grep -qx 'CURL_VERSION="9.99.0"' "$WORK/versions.sh" || \
    fail "vendored dependency label was not synchronized"

# A downloaded version cannot change without reviewed download metadata.
reset_fixture
sed -i 's/^ZLIB_VERSION=.*/ZLIB_VERSION=9.99.0/' "$WORK/dependencies.env"
if bash "$SYNC_SCRIPT" "$WORK/dependencies.env" "$WORK/versions.sh" \
    >"$WORK/downloaded.log" 2>&1; then
    fail "downloaded dependency change was accepted"
fi
grep -q 'Downloaded dependency version changed: ZLIB_VERSION' \
    "$WORK/downloaded.log" || fail "downloaded dependency failure was unclear"

# Added and removed dependencies require an explicit build-graph review.
reset_fixture
printf '\nNEW_LIBRARY_VERSION=1.0.0\n' >> "$WORK/dependencies.env"
if bash "$SYNC_SCRIPT" "$WORK/dependencies.env" "$WORK/versions.sh" \
    >"$WORK/added.log" 2>&1; then
    fail "unclassified dependency was accepted"
fi
grep -q 'Unclassified upstream dependency: NEW_LIBRARY_VERSION' \
    "$WORK/added.log" || fail "unclassified dependency failure was unclear"

reset_fixture
sed -i '/^OPENSSL_VERSION=/d' "$WORK/dependencies.env"
if bash "$SYNC_SCRIPT" "$WORK/dependencies.env" "$WORK/versions.sh" \
    >"$WORK/removed.log" 2>&1; then
    fail "removed managed dependency was accepted"
fi
grep -q 'Classified dependency removed upstream: OPENSSL_VERSION' \
    "$WORK/removed.log" || fail "removed dependency failure was unclear"

# Local download metadata must remain a complete, internally consistent tuple.
reset_fixture
sed -i '/^OPENSSL_SHA256=/d' "$WORK/versions.sh"
if bash "$SYNC_SCRIPT" "$WORK/dependencies.env" "$WORK/versions.sh" \
    >"$WORK/missing-metadata.log" 2>&1; then
    fail "incomplete downloaded dependency metadata was accepted"
fi
grep -q 'Missing downloaded dependency metadata: OPENSSL_SHA256' \
    "$WORK/missing-metadata.log" || fail "missing metadata failure was unclear"

reset_fixture
sed -i 's/^OPENSSL_VERSION=.*/OPENSSL_VERSION="9.99.0"/' "$WORK/versions.sh"
if bash "$SYNC_SCRIPT" "$WORK/dependencies.env" "$WORK/versions.sh" \
    >"$WORK/inconsistent-metadata.log" 2>&1; then
    fail "inconsistent downloaded dependency metadata was accepted"
fi
grep -q 'OPENSSL_ARCHIVE does not identify OPENSSL_VERSION=9.99.0' \
    "$WORK/inconsistent-metadata.log" || fail "inconsistent metadata failure was unclear"

reset_fixture
sed -i '/^ANDROID_NDK_VERSION=/d' "$WORK/dependencies.env"
if bash "$SYNC_SCRIPT" "$WORK/dependencies.env" "$WORK/versions.sh" \
    >"$WORK/removed-ignored.log" 2>&1; then
    fail "removed upstream-only dependency field was accepted"
fi
grep -q 'Classified dependency removed upstream: ANDROID_NDK_VERSION' \
    "$WORK/removed-ignored.log" || fail "removed classified field failure was unclear"

# Shell-looking upstream input must be rejected as data and never executed.
reset_fixture
marker="$WORK/executed"
printf '\nMALICIOUS_VERSION=$(touch %s)\n' "$marker" >> "$WORK/dependencies.env"
if bash "$SYNC_SCRIPT" "$WORK/dependencies.env" "$WORK/versions.sh" \
    >"$WORK/malicious.log" 2>&1; then
    fail "malicious version assignment was accepted"
fi
[ ! -e "$marker" ] || fail "upstream dependency file was executed"

echo "All dependency manifest regression tests passed."
