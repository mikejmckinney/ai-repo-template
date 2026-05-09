#!/usr/bin/env bash
# scripts/test-closeout.sh — fixture tests for scripts/closeout.sh.
#
# Drives the close-out script against tmp git worktrees that simulate
# the canonical refusal and happy-path scenarios.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLOSEOUT="$REPO_ROOT/scripts/closeout.sh"

PASS=0
FAIL=0
FAILED=()

pass() {
  PASS=$((PASS + 1))
  printf '  ✅ %s\n' "$1"
}
fail() {
  FAIL=$((FAIL + 1))
  FAILED+=("$1")
  printf '  ❌ %s\n' "$1"
}

if [[ ! -x "$CLOSEOUT" ]]; then
  printf '✗ %s missing or not executable\n' "$CLOSEOUT" >&2
  exit 1
fi

# Per-fixture vars are populated as each test creates its tmp dir.
# Initialize them up front so the single EXIT trap below is safe even
# if the script aborts between fixture creations.
fixture1="" fixture2="" fixture3="" fixture4="" fixture5=""
cleanup() {
  rm -rf "${fixture1:-}" "${fixture2:-}" "${fixture3:-}" "${fixture4:-}" "${fixture5:-}"
}
trap cleanup EXIT

# scaffold_fixture <dir> — write the minimum directory tree the script reads.
scaffold_fixture() {
  local dir="$1"
  mkdir -p "$dir/.context/sessions" "$dir/.context/state" "$dir/.git"
  : >"$dir/.context/sessions/latest_summary.md"
  : >"$dir/.context/state/_active.md"
  : >"$dir/.context/state/coordination.md"
}

# write_happy_path <dir> <branch>
write_happy_path() {
  local dir="$1" branch="$2"
  cat >"$dir/.context/sessions/latest_summary.md" <<EOF
# Session: 2026-05-09 — $branch — devops

**Status**: done
**Issue/PR**: #262 / #999
**Started**: 2026-05-09T00:00:00Z

## What Was Accomplished
- everything

## What Shipped
- the thing

## Harder Than Expected
nothing notable

## Generalizable Lessons
none

## Files Modified
- a
- b

## Open Items / Next
none — task complete
EOF
  cat >"$dir/.context/state/_active.md" <<'EOF'
# Active Tasks
EOF
  cat >"$dir/.context/state/coordination.md" <<'EOF'
## Active Locks

## Recent History
EOF
}

# Test 1 — refusal: lock still in Active Locks
fixture1=$(mktemp -d "${TMPDIR:-/tmp}/closeout-test-XXXXXX")
scaffold_fixture "$fixture1"
write_happy_path "$fixture1" "feature/test-262-refuse"
# Inject the branch into Active Locks to trigger check 2 refusal.
cat >"$fixture1/.context/state/coordination.md" <<'EOF'
## Active Locks

## Lock: pr-test-262
**Session**: feature/test-262-refuse
**State**: peer_review

## Recent History
EOF
# Touch a state file so check 1 passes (so check 2 is the one that fires).
echo "x" >>"$fixture1/.context/state/_active.md"
# Make script see "changes" without a real git repo — git diff will exit 128
# inside our fake .git/, but the script tolerates that and treats output as empty.
# To pass check 1 we need the diff helper to find the files. We work around
# this by initializing a real git repo in the fixture.
(cd "$fixture1" && rm -rf .git && git init -q \
  && git config user.email 'test@example.com' && git config user.name 'closeout-test' \
  && git add -A && git commit -qm init \
  && git checkout -q -b feature/test-262-refuse \
  && echo "modified" >>.context/sessions/latest_summary.md \
  && echo "modified" >>.context/state/_active.md)

if out=$(CLOSEOUT_REPO_ROOT="$fixture1" CLOSEOUT_BRANCH="feature/test-262-refuse" \
  bash "$CLOSEOUT" 2>&1); then
  fail "test 1 (refusal): expected non-zero exit, got 0. Output:\n$out"
else
  rc=$?
  if [[ "$rc" -ne 1 ]]; then
    fail "test 1 (refusal): expected exit 1, got $rc"
  elif printf '%s\n' "$out" | grep -q "check 2: lock for branch 'feature/test-262-refuse' is still in '## Active Locks'"; then
    pass "test 1: refusal on 'lock not moved' fires check 2 with the right message"
  else
    fail "test 1 (refusal): exit was 1 but check 2 message not found. Output:\n$out"
  fi
fi

# Test 2 — happy path: all checks pass
fixture2=$(mktemp -d "${TMPDIR:-/tmp}/closeout-test-XXXXXX")
scaffold_fixture "$fixture2"
write_happy_path "$fixture2" "feature/test-262-happy"
(cd "$fixture2" && rm -rf .git && git init -q \
  && git config user.email 'test@example.com' && git config user.name 'closeout-test' \
  && git add -A && git commit -qm init \
  && git checkout -q -b feature/test-262-happy \
  && echo "modified" >>.context/sessions/latest_summary.md \
  && echo "modified" >>.context/state/_active.md)

if out=$(CLOSEOUT_REPO_ROOT="$fixture2" CLOSEOUT_BRANCH="feature/test-262-happy" \
  bash "$CLOSEOUT" 2>&1); then
  if printf '%s\n' "$out" | grep -q "All checks passed."; then
    pass "test 2: happy path exits 0 and prints 'All checks passed'"
  else
    fail "test 2 (happy path): exit 0 but 'All checks passed' not in output. Output:\n$out"
  fi
  if printf '%s\n' "$out" | grep -q 'chore(closeout): feature/test-262-happy'; then
    pass "test 2: happy path prints templated commit message with branch name"
  else
    fail "test 2 (happy path): templated commit message missing or branch name absent. Output:\n$out"
  fi
else
  rc=$?
  fail "test 2 (happy path): expected exit 0, got $rc. Output:\n$out"
fi

# Test 3 — refusal: state files not touched (check 1)
fixture3=$(mktemp -d "${TMPDIR:-/tmp}/closeout-test-XXXXXX")
scaffold_fixture "$fixture3"
write_happy_path "$fixture3" "feature/test-262-no-touch"
(cd "$fixture3" && rm -rf .git && git init -q \
  && git config user.email 'test@example.com' && git config user.name 'closeout-test' \
  && git add -A && git commit -qm init \
  && git checkout -q -b feature/test-262-no-touch)
# No further modifications -> check 1 must refuse.
if out=$(CLOSEOUT_REPO_ROOT="$fixture3" CLOSEOUT_BRANCH="feature/test-262-no-touch" \
  bash "$CLOSEOUT" 2>&1); then
  fail "test 3 (no-touch): expected non-zero exit, got 0. Output:\n$out"
else
  if printf '%s\n' "$out" | grep -q 'check 1a: close-out commit must touch'; then
    pass "test 3: refusal on 'state files not touched' fires check 1"
  else
    fail "test 3 (no-touch): refused but check 1 message missing. Output:\n$out"
  fi
fi

# Test 4 — prefix-overlap regression (R1 review feedback):
# Branch `feature/test-262-foo` must not be considered "still locked"
# just because `feature/test-262-foo-2` appears in Active Locks, and
# its session header must be matched on exact field equality, not
# substring containment.
fixture4=$(mktemp -d "${TMPDIR:-/tmp}/closeout-test-XXXXXX")
scaffold_fixture "$fixture4"
write_happy_path "$fixture4" "feature/test-262-foo"
# Inject a *different* lock whose Session field happens to start with our branch name.
cat >"$fixture4/.context/state/coordination.md" <<'EOF'
## Active Locks

## Lock: pr-test-262-foo-2
**Session**: feature/test-262-foo-2
**State**: in_progress

## Recent History
EOF
# Also inject a session header for the prefix-overlap branch to verify
# check 4's exact-field match.
cat >>"$fixture4/.context/sessions/latest_summary.md" <<'EOF'

# Session: 2026-05-08 — feature/test-262-foo-2 — devops
**Status**: in_progress
EOF
(cd "$fixture4" && rm -rf .git && git init -q \
  && git config user.email 'test@example.com' && git config user.name 'closeout-test' \
  && git add -A && git commit -qm init \
  && git checkout -q -b feature/test-262-foo \
  && echo "modified" >>.context/sessions/latest_summary.md \
  && echo "modified" >>.context/state/_active.md)

if out=$(CLOSEOUT_REPO_ROOT="$fixture4" CLOSEOUT_BRANCH="feature/test-262-foo" \
  bash "$CLOSEOUT" 2>&1); then
  if printf '%s\n' "$out" | grep -q "check 2: no Active Locks reference branch 'feature/test-262-foo'"; then
    pass "test 4: prefix-overlap branch name does not false-positive check 2"
  else
    fail "test 4 (prefix-overlap): exited 0 but check 2 didn't pass cleanly. Output:\n$out"
  fi
else
  rc=$?
  fail "test 4 (prefix-overlap): expected exit 0, got $rc — anchored Session match regressed. Output:\n$out"
fi

# Test 5 — malformed coordination.md with no '## Active Locks' heading
# (R5 review feedback): the check must refuse rather than silently pass
# when the file structure contract is broken.
fixture5=$(mktemp -d "${TMPDIR:-/tmp}/closeout-test-XXXXXX")
scaffold_fixture "$fixture5"
write_happy_path "$fixture5" "feature/test-262-no-heading"
# Overwrite coordination.md so it lacks the '## Active Locks' heading.
cat >"$fixture5/.context/state/coordination.md" <<'EOF'
# Coordination Board

(no Active Locks heading — malformed file)
EOF
(cd "$fixture5" && rm -rf .git && git init -q \
  && git config user.email 'test@example.com' && git config user.name 'closeout-test' \
  && git add -A && git commit -qm init \
  && git checkout -q -b feature/test-262-no-heading \
  && echo "modified" >>.context/sessions/latest_summary.md \
  && echo "modified" >>.context/state/_active.md)

if out=$(CLOSEOUT_REPO_ROOT="$fixture5" CLOSEOUT_BRANCH="feature/test-262-no-heading" \
  bash "$CLOSEOUT" 2>&1); then
  fail "test 5 (no Active Locks heading): expected non-zero exit, got 0. Output:\n$out"
else
  if printf '%s\n' "$out" | grep -q "missing the '## Active Locks' heading"; then
    pass "test 5: refusal on malformed coordination.md (no Active Locks heading)"
  else
    fail "test 5 (no Active Locks heading): refused but check 2 message missing. Output:\n$out"
  fi
fi

printf '\n'
printf 'closeout fixtures: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'Failed: %s\n' "${FAILED[*]}"
  exit 1
fi
exit 0
