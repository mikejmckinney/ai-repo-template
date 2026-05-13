#!/usr/bin/env bats
#
# scripts/tests/verify-pr.bats
#
# Inlined from scripts/test-verify-pr.sh by issue #280 (un-wrap legacy delegate).
# The legacy script's body lives as the shell function `_legacy_body`
# inside this file; the @test block invokes it via bats `run` so bats'
# subshell wrapping preserves set -e + EXIT-trap semantics. No external
# scripts/test-*.sh delegate file remains.

# Per-test timeout (seconds). Must be set at file-load time, before any
# test runs (codex/cursor P2 review feedback on PR #274).
export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
}

_legacy_body() {
  set -euo pipefail
  cd "$REPO_ROOT"
  # ===== inlined body of scripts/test-verify-pr.sh (issue #280) =====
# scripts/test-verify-pr.sh — fixture tests for scripts/verify-pr.sh
# (issue #227 — pre-merge verification gate).
#
# Each fixture builds a temp dir with a tiny .github/workflows/ tree and
# pipes a hand-crafted path list to verify-pr.sh via --paths-from -.
# We exercise the four declared classes plus the detection-only path
# and the conservative file-removed branch.
#
# Run: bats --tap scripts/tests/verify-pr.bats


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

# A pull_request_target workflow — default-branch-only despite the
# "pull_request" prefix, because GitHub loads it from the base branch.
cat >"$fixture_dir/.github/workflows/agent-fork-handler.yml" <<'YAML'
name: agent-fork-handler
on:
  pull_request_target:
    types: [opened, synchronize]
jobs:
  noop:
    runs-on: ubuntu-latest
    steps: [{ run: "echo" }]
YAML

# Inline-scalar form: `on: push`. Default-branch-only.
cat >"$fixture_dir/.github/workflows/inline-scalar-push.yml" <<'YAML'
name: inline-scalar-push
on: push
jobs:
  noop:
    runs-on: ubuntu-latest
    steps: [{ run: "echo" }]
YAML

# Inline flow-sequence form: `on: [push, pull_request]`. Default-branch-only
# because `push` is in the list (most-restrictive bucket wins).
cat >"$fixture_dir/.github/workflows/inline-flow-list.yml" <<'YAML'
name: inline-flow-list
on: [push, pull_request]
jobs:
  noop:
    runs-on: ubuntu-latest
    steps: [{ run: "echo" }]
YAML

# Inline flow-sequence with the default-only trigger at the END of the
# list (`on: [pull_request, push]`). Regression guard for the GEM-G
# bug where the trailing-`]` delimiter wasn't matchable inside an ERE
# bracket expression.
cat >"$fixture_dir/.github/workflows/inline-flow-trailing.yml" <<'YAML'
name: inline-flow-trailing
on: [pull_request, push]
jobs:
  noop:
    runs-on: ubuntu-latest
    steps: [{ run: "echo" }]
YAML

# Block-form list-bullet: `- push`. Default-branch-only.
cat >"$fixture_dir/.github/workflows/block-list-push.yml" <<'YAML'
name: block-list-push
on:
  - push
  - workflow_dispatch
jobs:
  noop:
    runs-on: ubuntu-latest
    steps: [{ run: "echo" }]
YAML

# False-positive guard: a workflow that only triggers on `pull_request`
# but mentions the word "push" in a job name and a step `run:` body.
# Must NOT be classified as default-branch-only.
cat >"$fixture_dir/.github/workflows/false-positive-push-name.yml" <<'YAML'
name: false-positive-push-name
on:
  pull_request:
    branches: [main]
jobs:
  push-image:
    runs-on: ubuntu-latest
    steps:
      - run: echo "this job pushes a container — but the trigger is pull_request"
      # on: push  ← this is a comment and must not trigger detection
YAML

# False-positive guard #2 (GEM-M): a workflow whose mapping key
# `push-image:` would lexically match the regex if the on-block scan
# were stateless. The awk state machine should still classify this
# as `pull_request-triggered workflow`.
cat >"$fixture_dir/.github/workflows/false-positive-job-key.yml" <<'YAML'
name: false-positive-job-key
on:
  pull_request:
    branches: [main]
env:
  push: "value that should not trigger detection"
jobs:
  push-image:
    runs-on: ubuntu-latest
    steps:
      - name: push  # step name "push" — must not register
        run: echo "noop"
YAML

# A repository_dispatch workflow — like push/schedule, this is loaded
# from the default branch, so PR-branch changes are unverifiable.
cat >"$fixture_dir/.github/workflows/repository-dispatch.yml" <<'YAML'
name: repository-dispatch
on:
  repository_dispatch:
    types: [custom-event]
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

# ── CASE-10: pull_request_target is default-branch-only (Round-1 fix) ────────
echo ""
echo "CASE-10: pull_request_target workflow → default-branch-only (exit 0 when matched)"
result=$(run_case "default-branch-only workflow" \
  ".github/workflows/agent-fork-handler.yml")
assert_eq "CASE-10 exit code" "0" "${result%%:*}"

# ── CASE-11: pull_request_target misclassified as PR-triggered (mismatch) ────
echo ""
echo "CASE-11: pull_request_target declared as pull_request-triggered → exit 1"
result=$(run_case "pull_request-triggered workflow" \
  ".github/workflows/agent-fork-handler.yml")
assert_eq "CASE-11 exit code" "1" "${result%%:*}"
assert_contains "CASE-11 detects default-branch-only" \
  "default-branch-only workflow" "${result#*:}"

# ── CASE-12: over-declared `mixed` for single-bucket diff is a mismatch ──────
echo ""
echo "CASE-12: declared mixed for code-only diff (single bucket) → exit 1"
result=$(run_case "mixed" "README.md
src/foo.py")
assert_eq "CASE-12 exit code" "1" "${result%%:*}"
assert_contains "CASE-12 detects code-or-docs" "code-or-docs" "${result#*:}"

# ── CASE-13: inline scalar `on: push` is default-branch-only ─────────────────
echo ""
echo "CASE-13: inline scalar \`on: push\` → default-branch-only (exit 0 when matched)"
result=$(run_case "default-branch-only workflow" \
  ".github/workflows/inline-scalar-push.yml")
assert_eq "CASE-13 exit code" "0" "${result%%:*}"

# ── CASE-14: inline flow-sequence `on: [push, ...]` is default-branch-only ───
echo ""
echo "CASE-14: inline flow \`on: [push, pull_request]\` → default-branch-only"
result=$(run_case "default-branch-only workflow" \
  ".github/workflows/inline-flow-list.yml")
assert_eq "CASE-14 exit code" "0" "${result%%:*}"

# ── CASE-15: block-form list-bullet `- push` is default-branch-only ──────────
echo ""
echo "CASE-15: block-list \`- push\` → default-branch-only"
result=$(run_case "default-branch-only workflow" \
  ".github/workflows/block-list-push.yml")
assert_eq "CASE-15 exit code" "0" "${result%%:*}"

# ── CASE-16: false-positive guard — `push` only in job/step bodies and a comment ─
echo ""
echo "CASE-16: workflow with push only in job/step text → pull_request-triggered (no false positive)"
result=$(run_case "pull_request-triggered workflow" \
  ".github/workflows/false-positive-push-name.yml")
assert_eq "CASE-16 exit code" "0" "${result%%:*}"
assert_contains 'CASE-16 reports match (no false positive on push in body)' \
  "matches detection" "${result#*:}"

# ── CASE-17: repository_dispatch is default-branch-only ──────────────────────
echo ""
echo "CASE-17: repository_dispatch workflow → default-branch-only (exit 0 when matched)"
result=$(run_case "default-branch-only workflow" \
  ".github/workflows/repository-dispatch.yml")
assert_eq "CASE-17 exit code" "0" "${result%%:*}"

# ── CASE-18: mixed advice when no default-branch-only present points to PR branch ─
echo ""
echo "CASE-18: mixed (code + pull_request-only) declared as code-or-docs → mismatch advises PR branch, NOT sandbox"
result=$(run_case "code-or-docs" "README.md
.github/workflows/lint-and-format.yml")
assert_eq "CASE-18 exit code" "1" "${result%%:*}"
assert_contains "CASE-18 advises PR branch (no default-branch-only present)" \
  "Verification target: PR branch" "${result#*:}"
# Should NOT recommend sandbox here.
case18_body="${result#*:}"
if printf '%s' "$case18_body" | grep -qF 'sandbox-verification.md'; then
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("CASE-18 should NOT recommend sandbox for mixed-without-default-only")
  printf '  ❌ CASE-18 should NOT recommend sandbox for mixed-without-default-only\n'
else
  PASS=$((PASS + 1))
  printf '  ✅ CASE-18 omits sandbox recommendation when no default-branch-only present\n'
fi

# ── CASE-19: regression guard for GEM-G — trigger at the END of an inline list ─
echo ""
echo "CASE-19: inline flow \`on: [pull_request, push]\` (push at end) → default-branch-only"
result=$(run_case "default-branch-only workflow" \
  ".github/workflows/inline-flow-trailing.yml")
assert_eq "CASE-19 exit code" "0" "${result%%:*}"

# ── CASE-20: regression guard for GEM-M — job/env named like a trigger ───────
echo ""
echo "CASE-20: env.push + jobs.push-image + steps[].name 'push' must NOT register (state-aware on-block scan)"
result=$(run_case "pull_request-triggered workflow" \
  ".github/workflows/false-positive-job-key.yml")
assert_eq "CASE-20 exit code" "0" "${result%%:*}"
assert_contains "CASE-20 reports match (no false positive on env/job/step named push)" \
  "matches detection" "${result#*:}"

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
  # ===== end inlined body =====
}

@test "verify-pr: inlined test-verify-pr.sh body passes" {
  run _legacy_body
  # Emit captured output as TAP `# ...` comments so the
  # per-assertion ✅/PASS [...] markers from the inlined
  # legacy body remain visible (and grep-able by
  # run_bats_check) even on the success path. (#280 round 3)
  printf '%s
' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 0 ]
}
