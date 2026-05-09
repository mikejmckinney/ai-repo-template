#!/usr/bin/env bats
#
# scripts/tests/active-md-multitask.bats
#
# Inlined from scripts/test-active-md-multitask.sh by issue #280 (un-wrap legacy delegate).
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
  SCRIPT_DIR="$REPO_ROOT/scripts"
  # ===== inlined body of scripts/test-active-md-multitask.sh (issue #280) =====
#
# scripts/test-active-md-multitask.sh
#
# ADR-018 smoke test for the multi-task `_active.md` schema.
#
# Two scenarios are covered:
#
#   Scenario 1 — Updates to distinct existing sections commute cleanly.
#     This is the realistic ongoing case for the parallel-execution model:
#     each branch has its own `## Task: <branch>` section claimed before
#     the parallel work fans out, and each branch only edits its own
#     section. Three-way merge auto-resolves with no conflict markers.
#     This is the failure mode ADR-018 was designed to fix (the old
#     single-task schema produced hard conflicts here).
#
#   Scenario 2 — New-section additions from an empty base produce a
#     conflict, but the resolution is lossless.
#     Two brand-new sections appended to an empty body target the same
#     end-of-file line, so git's auto-merge cannot resolve them. ADR-018
#     does NOT eliminate this conflict (no schema with freeform section
#     lists can without a fixed sentinel structure that itself becomes
#     a conflict point). The improvement vs. the old schema is that the
#     manual resolution is *obvious and lossless*: concatenate both
#     `## Task:` blocks. Under the old single-task schema, the resolver
#     had to pick a "winner" and silently lose the loser branch's state.
#     This scenario asserts that simulating that lossless concatenation
#     produces a valid file containing both sections.
#
# Asserts:
#   - Scenario 1: merge exits 0 with no conflict markers; both updated
#     sections present with their new content.
#   - Scenario 2: merge may conflict (expected); after manual lossless
#     concatenation, file is conflict-marker-free and contains both
#     branches' `## Task:` headers.
#
# Usage: ./scripts/test-active-md-multitask.sh
# Exit:  0 on success; non-zero with diagnostic on first failure.


WORK=$(mktemp -d -t active-md-multitask.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"

git init -q -b main
git config user.email "smoke@test.local"
git config user.name "Smoke Test"

# ===== Scenario 1 — distinct-section updates commute =====

mkdir -p .context/state
cat >.context/state/_active.md <<'EOF'
<!-- Schema (multi-task; see ADR-018): one `## Task: <branch>` section per in-flight branch. -->

# Active Tasks

## Task: feature/a
**Issue/PR**: #1
**Role**: frontend
**Blockers**: None
**Next 1–3 actions**:
1. (initial)

## Task: feature/b
**Issue/PR**: #2
**Role**: backend
**Blockers**: None
**Next 1–3 actions**:
1. (initial)
EOF
git add . && git commit -q -m "scenario1 base (both sections pre-claimed)"

# Branch A edits ONLY its own section.
git checkout -q -b s1/feature-a
awk '
  /^## Task: feature\/a/ { in_a = 1; print; next }
  in_a && /^## Task:/    { in_a = 0 }
  in_a && /^1\. \(initial\)/ { print "1. A updated"; next }
  { print }
' .context/state/_active.md >.context/state/_active.md.new
mv .context/state/_active.md.new .context/state/_active.md
git commit -qa -m "A updates own section"

# Branch B edits ONLY its own section, from base.
git checkout -q main
git checkout -q -b s1/feature-b
awk '
  /^## Task: feature\/b/ { in_b = 1; print; next }
  in_b && /^## Task:/    { in_b = 0 }
  in_b && /^1\. \(initial\)/ { print "1. B updated"; next }
  { print }
' .context/state/_active.md >.context/state/_active.md.new
mv .context/state/_active.md.new .context/state/_active.md
git commit -qa -m "B updates own section"

git checkout -q main
git merge --no-ff -q -m "merge A" s1/feature-a
if ! git merge --no-ff -q -m "merge B" s1/feature-b; then
  echo "FAIL [scenario 1]: distinct-section updates produced a conflict (ADR-018 regression)" >&2
  cat .context/state/_active.md >&2 || true
  exit 1
fi

if grep -F -e '<<<<<<<' -e '=======' -e '>>>>>>>' .context/state/_active.md >/dev/null; then
  echo "FAIL [scenario 1]: conflict markers present after merge" >&2
  cat .context/state/_active.md >&2
  exit 1
fi
if ! grep -q '^1\. A updated' .context/state/_active.md; then
  echo "FAIL [scenario 1]: A's update missing from merged file" >&2
  exit 1
fi
if ! grep -q '^1\. B updated' .context/state/_active.md; then
  echo "FAIL [scenario 1]: B's update missing from merged file" >&2
  exit 1
fi
echo "PASS [scenario 1]: distinct-section updates commute cleanly under three-way merge"

# ===== Scenario 2 — new-section additions: conflict expected, resolution is lossless =====

cd "$WORK"
rm -rf .git .context
git init -q -b main
git config user.email "smoke@test.local"
git config user.name "Smoke Test"
mkdir -p .context/state
cat >.context/state/_active.md <<'EOF'
<!-- Schema (multi-task; see ADR-018): one `## Task: <branch>` section per in-flight branch. -->

# Active Tasks
EOF
git add . && git commit -q -m "scenario2 base (empty body)"

git checkout -q -b s2/feature-a
cat >>.context/state/_active.md <<'EOF'

## Task: feature/a
**Issue/PR**: #1
**Role**: frontend
**Blockers**: None
**Next 1–3 actions**:
1. Stub component
EOF
git commit -qa -m "A claims new section"

git checkout -q main
git checkout -q -b s2/feature-b
cat >>.context/state/_active.md <<'EOF'

## Task: feature/b
**Issue/PR**: #2
**Role**: backend
**Blockers**: None
**Next 1–3 actions**:
1. Define API contract
EOF
git commit -qa -m "B claims new section"

git checkout -q main
git merge --no-ff -q -m "merge A" s2/feature-a

# This merge IS expected to conflict — no schema with freeform appends to
# end-of-file can avoid it. The improvement vs. the old single-task
# schema is the resolution semantic: lossless concatenation, not pick-one.
set +e
git merge --no-ff -q -m "merge B" s2/feature-b 2>/dev/null
merge_rc=$?
set -e

if [[ "$merge_rc" -ne 0 ]]; then
  # Resolve by concatenating both blocks (the documented manual fix).
  awk '
    /^<<<<<<< / { in_ours = 1; next }
    /^=======$/ { in_ours = 0; in_theirs = 1; next }
    /^>>>>>>> / { in_theirs = 0; next }
    in_ours   { ours = ours $0 ORS; next }
    in_theirs { theirs = theirs $0 ORS; next }
    { print }
    END { printf "%s%s", ours, theirs }
  ' .context/state/_active.md >.context/state/_active.md.new
  mv .context/state/_active.md.new .context/state/_active.md
  git add .context/state/_active.md
  git -c core.editor=true commit -q -m "resolve: concatenate both sections (lossless)"
fi

if grep -F -e '<<<<<<<' -e '=======' -e '>>>>>>>' .context/state/_active.md >/dev/null; then
  echo "FAIL [scenario 2]: conflict markers remain after lossless-concat resolution" >&2
  cat .context/state/_active.md >&2
  exit 1
fi
# shellcheck disable=SC2126  # grep -c forbidden in set -e scripts (RULE-01)
# Wrap grep with || true: under set -euo pipefail, a 0-match grep would abort
# the script before the FAIL message below could print (Cursor Bugbot ISS-09).
section_count=$({ grep '^## Task:' .context/state/_active.md || true; } | wc -l | tr -d ' ')
if [[ "$section_count" -ne 2 ]]; then
  echo "FAIL [scenario 2]: expected 2 '## Task:' sections after lossless concat, got $section_count" >&2
  cat .context/state/_active.md >&2
  exit 1
fi
if ! grep -q '^## Task: feature/a' .context/state/_active.md \
  || ! grep -q '^## Task: feature/b' .context/state/_active.md; then
  echo "FAIL [scenario 2]: a section is missing after lossless concat" >&2
  cat .context/state/_active.md >&2
  exit 1
fi
echo "PASS [scenario 2]: new-section adds resolve losslessly to a 2-section file"

echo "PASS: ADR-018 multi-task _active.md smoke test (both scenarios)"
  # ===== end inlined body =====
}

@test "active-md-multitask: inlined test-active-md-multitask.sh body passes" {
  run _legacy_body
  # Emit captured output as TAP `# ...` comments so the
  # per-assertion ✅/PASS [...] markers from the inlined
  # legacy body remain visible (and grep-able by
  # run_bats_check) even on the success path. (#280 round 3)
  printf '%s
' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 0 ]
}
