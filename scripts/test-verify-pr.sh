#!/usr/bin/env bash
# scripts/test-verify-pr.sh — fixture tests for scripts/verify-pr.sh
# (issue #227 — pre-merge verification gate).
#
# Each fixture builds a temp dir with a tiny .github/workflows/ tree and
# pipes a hand-crafted path list to verify-pr.sh via --paths-from -.
# We exercise the four declared classes plus the detection-only path
# and the conservative file-removed branch.
#
# Run: bash scripts/test-verify-pr.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERIFY_PR="$REPO_ROOT/scripts/verify-pr.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s\n' "$name"
    printf '       expected: %s\n' "$expected"
    printf '       actual:   %s\n' "$actual"
  fi
}

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s\n' "$name"
    printf '       expected to contain: %s\n' "$needle"
  fi
}

TMP_BASE=$(mktemp -d)
# shellcheck disable=SC2317  # invoked via trap
cleanup() { rm -rf "$TMP_BASE"; }
trap cleanup EXIT

# Build a minimal fixture workspace with a representative workflow set.
fixture_dir="$TMP_BASE/fixture"
mkdir -p "$fixture_dir/.github/workflows"

# A workflow that pins to default-branch via pull_request_review.
cat >"$fixture_dir/.github/workflows/agent-fix-reviews.yml" <<'YAML'
name: agent-fix-reviews
on:
  pull_request_review:
    types: [submitted]
jobs:
  noop:
    runs-on: ubuntu-latest
    steps: [{ run: "echo" }]
YAML

# A workflow triggered by issue_comment (also default-branch-only).
cat >"$fixture_dir/.github/workflows/agent-relay-reviews.yml" <<'YAML'
name: agent-relay-reviews
on:
  issue_comment:
    types: [created]
jobs:
  noop:
    runs-on: ubuntu-latest
    steps: [{ run: "echo" }]
YAML

# A pull_request-only workflow (PR-branch verifiable).
cat >"$fixture_dir/.github/workflows/lint-and-format.yml" <<'YAML'
name: lint-and-format
on:
  pull_request:
    branches: [main]
  workflow_dispatch:
jobs:
  noop:
    runs-on: ubuntu-latest
    steps: [{ run: "echo" }]
YAML

run_case() {
  # run_case <declared> <paths-newline-separated>
  # Echoes "<exit>:<stdout+stderr>"
  local declared="$1" paths="$2"
  local out exit_code
  set +e
  out=$(cd "$fixture_dir" && printf '%s\n' "$paths" \
    | "$VERIFY_PR" --declared "$declared" --paths-from - --quiet 2>&1)
  exit_code=$?
  set -e
  printf '%s:%s' "$exit_code" "$out"
}

run_detect() {
  # run_detect <paths>
  local paths="$1"
  local out exit_code
  set +e
  out=$(cd "$fixture_dir" && printf '%s\n' "$paths" \
    | "$VERIFY_PR" --paths-from - 2>&1)
  exit_code=$?
  set -e
  printf '%s:%s' "$exit_code" "$out"
}

echo "========================================"
echo "verify-pr.sh fixture tests (issue #227)"
echo "========================================"

# ── CASE-01: code-only diff matches code-or-docs ─────────────────────────────
echo ""
echo "CASE-01: code-only diff → code-or-docs (exit 0, match)"
result=$(run_case "code-or-docs" "README.md
src/foo.py")
assert_eq "CASE-01 exit code" "0" "${result%%:*}"
assert_contains "CASE-01 reports match" "matches detection" "${result#*:}"

# ── CASE-02: pull_request-only workflow matches its declared class ───────────
echo ""
echo "CASE-02: pull_request-only workflow → declared pull_request-triggered (exit 0)"
result=$(run_case "pull_request-triggered workflow" \
  ".github/workflows/lint-and-format.yml")
assert_eq "CASE-02 exit code" "0" "${result%%:*}"
assert_contains "CASE-02 reports match" "matches detection" "${result#*:}"

# ── CASE-03: default-branch-only matches its declared class ──────────────────
echo ""
echo "CASE-03: pull_request_review workflow → declared default-branch-only (exit 0)"
result=$(run_case "default-branch-only workflow" \
  ".github/workflows/agent-fix-reviews.yml")
assert_eq "CASE-03 exit code" "0" "${result%%:*}"

# ── CASE-04: misclassified default-branch-only as code-or-docs (the PR #225 bug) ──
echo ""
echo "CASE-04: default-branch-only declared as code-or-docs (exit 1, mismatch)"
result=$(run_case "code-or-docs" \
  ".github/workflows/agent-relay-reviews.yml")
assert_eq "CASE-04 exit code" "1" "${result%%:*}"
assert_contains "CASE-04 names sandbox playbook" \
  "sandbox-verification.md" "${result#*:}"
assert_contains "CASE-04 names detected class" \
  "default-branch-only workflow" "${result#*:}"

# ── CASE-05: mixed diff (code + default-branch-only) ─────────────────────────
echo ""
echo "CASE-05: code + default-branch-only declared as mixed (exit 0)"
result=$(run_case "mixed" "README.md
.github/workflows/agent-fix-reviews.yml")
assert_eq "CASE-05 exit code" "0" "${result%%:*}"
assert_contains "CASE-05 reports match (mixed == mixed equality branch)" \
  "matches detection" "${result#*:}"

# ── CASE-06: mixed diff declared as code-or-docs (still a mismatch) ──────────
echo ""
echo "CASE-06: mixed diff declared as code-or-docs (exit 1)"
result=$(run_case "code-or-docs" "README.md
.github/workflows/agent-fix-reviews.yml")
assert_eq "CASE-06 exit code" "1" "${result%%:*}"

# ── CASE-07: detection-only mode (no --declared) — exit 0 with detected line ─
echo ""
echo "CASE-07: detection-only run (no --declared) exits 0 with detected class"
result=$(run_detect ".github/workflows/agent-fix-reviews.yml
README.md")
assert_eq "CASE-07 exit code" "0" "${result%%:*}"
assert_contains "CASE-07 prints detected class" \
  "Detected change class: mixed" "${result#*:}"

# ── CASE-08: deleted-workflow path is conservative (default-branch-only) ─────
echo ""
echo "CASE-08: deleted workflow file is conservatively default-branch-only"
# Drop --quiet so the per-path trace (which carries the conservative-branch
# annotation) is captured.
set +e
case8_out=$(cd "$fixture_dir" && printf '%s\n' ".github/workflows/zzz-removed.yml" \
  | "$VERIFY_PR" --declared "code-or-docs" --paths-from - 2>&1)
case8_ec=$?
set -e
assert_eq "CASE-08 exit code" "1" "$case8_ec"
assert_contains "CASE-08 names file-removed conservative branch" \
  "file removed; conservative" "$case8_out"

# ── CASE-09: usage error (no paths anywhere) ─────────────────────────────────
echo ""
echo "CASE-09: empty path list exits 2 (usage error)"
set +e
out=$(cd "$fixture_dir" && printf '' | "$VERIFY_PR" --paths-from - --quiet 2>&1)
ec=$?
set -e
assert_eq "CASE-09 exit code" "2" "$ec"
assert_contains "CASE-09 mentions PR_FILES escape hatch" "PR_FILES" "$out"

# ── summary ──────────────────────────────────────────────────────────────────

echo ""
echo "========================================"
echo "Results"
echo "========================================"
printf 'Passed: %d\n' "$PASS"
printf 'Failed: %d\n' "$FAIL"
if [[ "${#FAILED_NAMES[@]}" -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for n in "${FAILED_NAMES[@]}"; do
    printf '  - %s\n' "$n"
  done
fi
echo ""
[[ "$FAIL" -gt 0 ]] && exit 1
exit 0
