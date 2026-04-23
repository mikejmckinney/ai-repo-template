#!/usr/bin/env bash
# Unit tests for scripts/multi-dispatch-safety.sh (issue #114).
#
# Why this test exists
# --------------------
# The dispatcher's correctness comes from four small functions in
# scripts/multi-dispatch-safety.sh: extract_scope, extract_depends_on,
# classify_overlap, and select_dispatchable. The workflow that calls
# them is thin glue. If the library silently regresses (cycle detection
# misses a self-edge, an awk pipeline drops a marker, the role-glob
# fallback misclassifies a label), the workflow still "succeeds" and
# we'd assign Copilot to conflicting issues. This test hard-fails so
# regressions trip CI rather than appearing in production dispatch.
#
# Run: bash scripts/test-multi-dispatch-safety.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cleanup any tmp dirs we mktemp below.
TMP_DIRS=()
# shellcheck disable=SC2317  # invoked via `trap cleanup EXIT` below
cleanup() {
  if [[ ${#TMP_DIRS[@]} -gt 0 ]]; then
    rm -rf "${TMP_DIRS[@]}"
  fi
}
trap cleanup EXIT

PASS=0
FAIL=0
FAILED_NAMES=()

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s\n' "$name"
    printf '       expected: %q\n' "$expected"
    printf '       actual:   %q\n' "$actual"
  fi
}

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s (missing: %q)\n' "$name" "$needle"
    printf '       haystack: %q\n' "$haystack"
  fi
}

# shellcheck disable=SC2317  # reserved test helper, retained for symmetry with assert_contains
assert_not_contains() {
  local name="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s (should NOT contain: %q)\n' "$name" "$needle"
  else
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  fi
}

# ── Set up fixture dir and point the lib at it ──

FIXTURE_DIR=$(mktemp -d); TMP_DIRS+=("$FIXTURE_DIR")
export MULTI_DISPATCH_TEST_MODE=1
export FIXTURE_DIR

# Helper to write a fixture issue.
make_issue() {
  local n="$1" body="$2" labels="$3" comments="${4:-}" state="${5:-open}"
  printf '%s' "$body" > "$FIXTURE_DIR/$n.body"
  printf '%s\n' "$labels" > "$FIXTURE_DIR/$n.labels"
  printf '%s' "$comments" > "$FIXTURE_DIR/$n.comments"
  printf '%s' "$state" > "$FIXTURE_DIR/$n.state"
}

# Source the lib AFTER FIXTURE_DIR is exported.
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/multi-dispatch-safety.sh"

# ── Tests: extract_depends_on ──

echo "extract_depends_on"

make_issue 100 $'Title body\n\nDepends-on: #50\nSome other text\nDepends-on: #51\n' "" "" "open"
out=$(extract_depends_on 100)
assert_eq "two Depends-on lines parsed in numeric order" $'50\n51' "$out"

make_issue 101 $'Depends-on: #50\nDepends-on: #50\nDepends-on:#50\n' "" "" "open"
out=$(extract_depends_on 101)
# `Depends-on:#50` (no space) is mixed in but the valid lines also
# resolve to 50 — this only proves de-dup, not that the missing-space
# form is rejected. The dedicated assertion against issue 105 below
# is the real test.
assert_eq "duplicates collapsed" "50" "$out"

make_issue 105 $'Depends-on:#52\n' "" "" "open"
out=$(extract_depends_on 105)
assert_eq "missing-space form rejected when it is the only line" "" "$out"

make_issue 106 $'Depends-on: #77 (backend bookkeeping)\n' "" "" "open"
out=$(extract_depends_on 106)
assert_eq "trailing context after #N tolerated (gemini #8)" "77" "$out"

make_issue 102 $'No deps here. Closes #99 (not a depends).\n' "" "" "open"
out=$(extract_depends_on 102)
assert_eq "no Depends-on lines → empty" "" "$out"

make_issue 103 $'  depends-on: #42  \n' "" "" "open"
out=$(extract_depends_on 103)
assert_eq "case-insensitive + trailing whitespace tolerated" "42" "$out"

echo ""

# ── Tests: extract_scope ──

echo "extract_scope"

# 1. Architect marker in a comment — file list wins over labels.
ARCHITECT_COMMENT=$'===COMMENT===\nSome other comment.\n===COMMENT===\nHere is the plan.\n\n<!-- architect-plan-files -->\n```\nsrc/api/users.py\nsrc/api/auth.py\n```\nThanks.\n'
make_issue 200 "title body" $'role:frontend' "$ARCHITECT_COMMENT" "open"
mode=$(extract_scope 200 2>&1 >/dev/null)
files=$(extract_scope 200 2>/dev/null)
assert_contains "architect mode reported" "MODE: architect" "$mode"
assert_eq "architect file list extracted" $'src/api/users.py\nsrc/api/auth.py' "$files"

# 2. Role-label fallback when no marker.
make_issue 201 "title body" $'enhancement\nrole:backend\ncopilot:ready' "" "open"
mode=$(extract_scope 201 2>&1 >/dev/null)
files=$(extract_scope 201 2>/dev/null)
assert_contains "role-glob mode reported" "MODE: role-glob (role:backend)" "$mode"
assert_contains "backend role glob includes src/backend" "src/backend" "$files"

# 3. Unknown role label → none + WARN.
make_issue 202 "title" $'role:wizard' "" "open"
mode=$(extract_scope 202 2>&1 >/dev/null)
files=$(extract_scope 202 2>/dev/null)
assert_contains "unknown role → MODE: none" "MODE: none" "$mode"
assert_contains "unknown role → WARN emitted" "WARN: no scope detected" "$mode"
assert_eq "unknown role → empty file list" "" "$files"

# 4. No labels, no marker → none + WARN.
make_issue 203 "title body" "" "" "open"
mode=$(extract_scope 203 2>&1 >/dev/null)
assert_contains "no signals → MODE: none" "MODE: none" "$mode"

# 5. Marker without a fenced block → falls through to label.
NO_FENCE_COMMENT=$'===COMMENT===\nHere is the plan.\n\n<!-- architect-plan-files -->\nNo code fence below.\n'
make_issue 204 "title" $'role:backend' "$NO_FENCE_COMMENT" "open"
mode=$(extract_scope 204 2>&1 >/dev/null)
files=$(extract_scope 204 2>/dev/null)
assert_contains "marker without fence → role-glob fallback" "MODE: role-glob" "$mode"
assert_contains "fallback returns backend prefixes" "src/backend" "$files"

echo ""

# ── Tests: classify_overlap ──

echo "classify_overlap"

# All `mk_list` outputs land inside a single FIXTURE-adjacent dir so
# the EXIT trap rm-rfs that one dir, never `dirname $(mktemp)` which
# would be /tmp on most systems (caught in PR review).
LIST_DIR=$(mktemp -d); TMP_DIRS+=("$LIST_DIR")
mk_list() {
  local f
  f=$(mktemp -p "$LIST_DIR" list.XXXXXX)
  printf '%s\n' "$@" > "$f"
  printf '%s' "$f"
}

A=$(mk_list "src/api/users.py" "src/api/auth.py")
B=$(mk_list "src/api/users.py" "src/api/billing.py")
out=$(classify_overlap "$A" "$B")
assert_eq "shared exact path → hard" "hard" "$out"

C=$(mk_list "src/backend/x.py")
D=$(mk_list "src/backend/y.py")
out=$(classify_overlap "$C" "$D")
assert_eq "different files under same role prefix → soft" "soft" "$out"

E=$(mk_list "src/frontend/x.tsx")
F=$(mk_list "src/backend/y.py")
out=$(classify_overlap "$E" "$F")
assert_eq "disjoint role prefixes → none" "none" "$out"

EMPTY=$(mk_list)
NONEMPTY=$(mk_list "src/anything")
out=$(classify_overlap "$EMPTY" "$NONEMPTY")
assert_eq "empty fileset → none (no scope, no overlap claim)" "none" "$out"

echo ""

# ── Tests: select_dispatchable ──

echo "select_dispatchable"

# Scenario A: two non-overlapping issues with role labels.
make_issue 300 "frontend work" "role:frontend" "" "open"
make_issue 301 "backend work" "role:backend" "" "open"
out=$(select_dispatchable 300 301)
assert_contains "non-overlap: 300 dispatched" $'300\tdispatch' "$out"
assert_contains "non-overlap: 301 dispatched" $'301\tdispatch' "$out"

# Scenario B: two issues with hard overlap (both name same architect file).
ARCH1=$'===COMMENT===\n<!-- architect-plan-files -->\n```\nsrc/api/users.py\n```\n'
make_issue 310 "first" "" "$ARCH1" "open"
make_issue 311 "second, same file" "" "$ARCH1" "open"
out=$(select_dispatchable 310 311)
assert_contains "hard overlap: 310 dispatched first" $'310\tdispatch' "$out"
assert_contains "hard overlap: 311 refused" $'311\trefuse\thard overlap with already-dispatched #310' "$out"

# Scenario C: input order = priority (reverse the inputs).
out=$(select_dispatchable 311 310)
assert_contains "priority swap: 311 now dispatched first" $'311\tdispatch' "$out"
assert_contains "priority swap: 310 refused" $'310\trefuse\thard overlap with already-dispatched #311' "$out"

# Scenario D: depends-on within the input set, in the right order.
make_issue 320 "feature head" "role:backend" "" "open"
make_issue 321 $'feature follow-up\n\nDepends-on: #320\n' "role:frontend" "" "open"
out=$(select_dispatchable 320 321)
assert_contains "dep within set, correct order: 320 dispatched" $'320\tdispatch' "$out"
assert_contains "dep within set, correct order: 321 dispatched" $'321\tdispatch' "$out"

# Scenario E: depends-on within the input set but reversed → refuse 321.
out=$(select_dispatchable 321 320)
assert_contains "dep within set, wrong order: 321 refused" $'321\trefuse' "$out"
assert_contains "dep refusal mentions move earlier" "move #320 earlier" "$out"

# Scenario F: depends-on points outside the set, target is closed → OK.
make_issue 330 $'depends on closed thing\n\nDepends-on: #999\n' "role:backend" "" "open"
make_issue 999 "closed dep" "" "" "closed"
out=$(select_dispatchable 330)
assert_contains "dep on closed external: dispatched" $'330\tdispatch' "$out"

# Scenario G: depends-on points outside the set, target open → refuse.
make_issue 998 "still open" "" "" "open"
make_issue 331 $'depends on open external\n\nDepends-on: #998\n' "role:backend" "" "open"
out=$(select_dispatchable 331)
assert_contains "dep on open external: refused" $'331\trefuse' "$out"
assert_contains "dep refusal mentions not closed" "not closed" "$out"

# Scenario H: depends-on cycle within the input set → all members refused.
make_issue 340 $'cycle a\n\nDepends-on: #341\n' "role:backend" "" "open"
make_issue 341 $'cycle b\n\nDepends-on: #340\n' "role:frontend" "" "open"
out=$(select_dispatchable 340 341)
assert_contains "cycle: 340 refused" $'340\trefuse\tDepends-on cycle' "$out"
assert_contains "cycle: 341 refused" $'341\trefuse\tDepends-on cycle' "$out"

# Scenario I: soft overlap (both backend, different files) → both dispatched.
make_issue 350 "backend a" "role:backend" "" "open"
make_issue 351 "backend b" "role:backend" "" "open"
out=$(select_dispatchable 350 351)
# Same role-label scope expands to the same prefix list, so this is
# actually a HARD overlap (identical scope rows). Document the behavior.
assert_contains "same role label = identical scope → hard overlap" $'351\trefuse\thard overlap' "$out"

# Scenario J: architect-distinct files within same role → both dispatched.
ARCH_A=$'===COMMENT===\n<!-- architect-plan-files -->\n```\nsrc/backend/users.py\n```\n'
ARCH_B=$'===COMMENT===\n<!-- architect-plan-files -->\n```\nsrc/backend/billing.py\n```\n'
make_issue 360 "users" "" "$ARCH_A" "open"
make_issue 361 "billing" "" "$ARCH_B" "open"
out=$(select_dispatchable 360 361)
assert_contains "architect-distinct files in same role: 360 dispatched" $'360\tdispatch' "$out"
assert_contains "architect-distinct files in same role: 361 dispatched" $'361\tdispatch' "$out"

echo ""

# ── Summary ──

echo "─────────────────────────────────────"
echo "Passed: $PASS"
echo "Failed: $FAIL"
if (( FAIL > 0 )); then
  echo ""
  echo "Failed tests:"
  for n in "${FAILED_NAMES[@]}"; do echo "  - $n"; done
  exit 1
fi
exit 0
