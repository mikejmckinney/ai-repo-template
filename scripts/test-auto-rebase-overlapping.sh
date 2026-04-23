#!/usr/bin/env bash
# Unit tests for scripts/auto-rebase-overlapping.sh (issue #116).
#
# Why this test exists
# --------------------
# The auto-rebase workflow's correctness comes from the small library
# in scripts/auto-rebase-overlapping.sh. The workflow YAML is thin
# glue. If `should_rebase_pr` silently regresses (skips the wrong PRs,
# misses a label gate, mis-classifies hard vs soft), the workflow
# would force-push to PRs it shouldn't OR fail to act on PRs it
# should. This test hard-fails so regressions trip CI rather than
# appearing in production rebase decisions.
#
# Run: bash scripts/test-auto-rebase-overlapping.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP_DIRS=()
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

# ── Set up fixture dir and point the lib at it ──

FIXTURE_DIR=$(mktemp -d); TMP_DIRS+=("$FIXTURE_DIR")
export AUTO_REBASE_TEST_MODE=1
export FIXTURE_DIR

# Helper to write a fixture PR.
make_pr() {
  local n="$1" labels="$2" is_fork="$3" is_draft="$4" files="$5" unresolved="${6:-0}"
  printf '%s\n' "$labels" > "$FIXTURE_DIR/$n.labels"
  printf '%s' "$is_fork" > "$FIXTURE_DIR/$n.is_fork"
  printf '%s' "$is_draft" > "$FIXTURE_DIR/$n.is_draft"
  printf '%s\n' "$files" > "$FIXTURE_DIR/$n.files"
  printf '%s' "$unresolved" > "$FIXTURE_DIR/$n.unresolved"
}

# Source the lib AFTER FIXTURE_DIR is exported.
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/auto-rebase-overlapping.sh"

# ── Tests: should_rebase_pr ──
#
# Naming: in each pair, PR 200 is the merged one. The function under
# test is called with the *other* PR as the first argument.

echo "should_rebase_pr"

# Merged PR fixture used for overlap comparison in many tests.
make_pr 200 "" "false" "false" "docs/decisions/adr-010.md" "0"

# 1. Self-PR.
make_pr 199 "auto-rebase" "false" "false" "docs/foo.md" "0"
assert_eq "self-PR is skipped (same-pr)" "skip:same-pr" "$(should_rebase_pr 200 200)"

# 2. Fork.
make_pr 201 "auto-rebase" "true" "false" "docs/decisions/adr-099.md" "0"
assert_eq "fork PR is skipped" "skip:fork" "$(should_rebase_pr 201 200)"

# 3. Draft.
make_pr 202 "auto-rebase" "false" "true" "docs/decisions/adr-099.md" "0"
assert_eq "draft PR is skipped" "skip:draft" "$(should_rebase_pr 202 200)"

# 4. Opted out.
make_pr 203 $'auto-rebase\ndo-not-rebase' "false" "false" "docs/decisions/adr-099.md" "0"
assert_eq "do-not-rebase wins over auto-rebase (opted-out)" "skip:opted-out" "$(should_rebase_pr 203 200)"

# 5. Not opted in.
make_pr 204 "" "false" "false" "docs/decisions/adr-099.md" "0"
assert_eq "no auto-rebase label = skip:not-opted-in" "skip:not-opted-in" "$(should_rebase_pr 204 200)"

# 5b. Opt-in label is exact-match (a `auto-rebase-foo` label does NOT count).
make_pr 205 "auto-rebase-please" "false" "false" "docs/decisions/adr-099.md" "0"
assert_eq "auto-rebase label is exact-match (not prefix)" "skip:not-opted-in" "$(should_rebase_pr 205 200)"

# 6. Unresolved threads.
make_pr 206 "auto-rebase" "false" "false" "docs/decisions/adr-099.md" "3"
assert_eq "unresolved threads block rebase" "skip:unresolved-threads" "$(should_rebase_pr 206 200)"

# 7. Soft overlap → attempt-rebase.
# 200 touches docs/decisions/adr-010.md; 207 touches a different file
# under docs/decisions/. Same Architect prefix, different path = soft.
make_pr 207 "auto-rebase" "false" "false" "docs/decisions/adr-099.md" "0"
assert_eq "soft overlap (same prefix, diff file) → attempt-rebase" "attempt-rebase" "$(should_rebase_pr 207 200)"

# 8. Hard overlap → comment-only.
# 208 touches the *same* file as 200.
make_pr 208 "auto-rebase" "false" "false" "docs/decisions/adr-010.md" "0"
assert_eq "hard overlap (identical file) → comment-only" "comment-only" "$(should_rebase_pr 208 200)"

# 9. None overlap → skip.
# 209 touches a path under a different role's prefix.
make_pr 209 "auto-rebase" "false" "false" "src/backend/server.py" "0"
assert_eq "no overlap → skip:none-overlap" "skip:none-overlap" "$(should_rebase_pr 209 200)"

# 10. Skip-order precedence: fork > draft > opted-out > not-opted-in
#     > unresolved > overlap. Verify draft beats unresolved beats overlap.
make_pr 210 "auto-rebase" "false" "true" "src/backend/server.py" "5"
assert_eq "draft check fires before overlap check" "skip:draft" "$(should_rebase_pr 210 200)"

# 11. Opted-in + soft overlap + 0 unresolved threads, on a Docs prefix.
make_pr 211 "auto-rebase" "false" "false" "docs/guides/foo.md" "0"
make_pr 212 "" "false" "false" "docs/guides/bar.md" "0"
assert_eq "soft overlap on docs/ prefix → attempt-rebase" "attempt-rebase" "$(should_rebase_pr 211 212)"

# 12. Opted-in + hard overlap on .github/workflows/.
make_pr 213 "auto-rebase" "false" "false" ".github/workflows/foo.yml" "0"
make_pr 214 "" "false" "false" ".github/workflows/foo.yml" "0"
assert_eq "hard overlap on workflows/ → comment-only" "comment-only" "$(should_rebase_pr 213 214)"

# 13. Multiple labels including auto-rebase but no do-not-rebase.
make_pr 215 $'role:docs\nauto-rebase\nready' "false" "false" "docs/decisions/adr-099.md" "0"
assert_eq "auto-rebase among other labels still opts in" "attempt-rebase" "$(should_rebase_pr 215 200)"

# ── Tests: attempt_rebase ──

echo ""
echo "attempt_rebase"

# 14. Non-git work_dir.
not_git=$(mktemp -d); TMP_DIRS+=("$not_git")
assert_eq "not-a-git-repo path returns conflict:not-a-git-repo" \
  "conflict:not-a-git-repo" \
  "$(attempt_rebase featurebr deadbeef "$not_git")"

# Helper: build a tiny git repo with main + a feature branch we can rebase.
build_repo() {
  local repo="$1"
  (
    cd "$repo"
    git init -q -b main
    git config user.email "test@example.com"
    git config user.name "Test"
    echo "line1" > shared.txt
    git add shared.txt
    git commit -qm "main: initial"
    # Pretend `origin/main` is the same as local main, then advance origin/main.
    git checkout -q -b featurebr
    echo "feature add" >> shared.txt
    git commit -qam "feature: add line"
    # Move back to main and add a non-conflicting commit.
    git checkout -q main
    echo "main extra" > main-only.txt
    git add main-only.txt
    git commit -qm "main: add main-only file"
    # Set up an "origin/main" ref pointing at current main.
    git update-ref refs/remotes/origin/main main
  )
}

# 15. Clean rebase.
clean_repo=$(mktemp -d); TMP_DIRS+=("$clean_repo")
build_repo "$clean_repo"
result=$(attempt_rebase featurebr deadbeef "$clean_repo")
assert_eq "clean rebase reports 'clean'" "clean" "$result"

# 15b. Clean rebase via `git worktree` (regression for Codex P1: in
#       worktrees, `.git` is a *file* not a directory; the workflow
#       always uses `git worktree add`).
worktree_parent=$(mktemp -d); TMP_DIRS+=("$worktree_parent")
build_repo "$worktree_parent"
worktree_path="$worktree_parent/wt-feature"
git -C "$worktree_parent" worktree add -B featurebr "$worktree_path" featurebr >/dev/null 2>&1
# Sanity: this is the codex bug surface — `.git` is a file in worktrees.
assert_eq "worktree's .git is a file (not dir) — guard regression surface" \
  "file" \
  "$(test -f "$worktree_path/.git" && echo file || echo dir)"
result=$(attempt_rebase featurebr deadbeef "$worktree_path")
assert_eq "clean rebase via git worktree reports 'clean' (Codex P1 fix)" "clean" "$result"

# 16. Conflict rebase.
conflict_repo=$(mktemp -d); TMP_DIRS+=("$conflict_repo")
(
  cd "$conflict_repo"
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "line1" > shared.txt
  git add shared.txt
  git commit -qm "main: initial"
  git checkout -q -b featurebr
  echo "feature edit" > shared.txt
  git commit -qam "feature: rewrite shared.txt"
  git checkout -q main
  echo "main edit" > shared.txt
  git commit -qam "main: rewrite shared.txt differently"
  git update-ref refs/remotes/origin/main main
)
result=$(attempt_rebase featurebr deadbeef "$conflict_repo")
assert_contains "conflict rebase reports 'conflict:'" "conflict:" "$result"
assert_contains "conflict rebase names shared.txt" "shared.txt" "$result"

# 16b. After a conflict, rebase is aborted: working tree should be clean
#       and HEAD on the original feature branch.
status_file=$(mktemp); TMP_DIRS+=("$status_file")
(
  cd "$conflict_repo"
  if git status --porcelain | grep -q .; then
    echo "DIRTY"
  else
    echo "CLEAN"
  fi
) > "$status_file"
assert_eq "conflict rebase aborts cleanly (no dirty worktree)" "CLEAN" "$(cat "$status_file")"

# ── Tests: comment formatters ──

echo ""
echo "format_success_comment"

success_body=$(format_success_comment 142 abc1234)
assert_contains "success comment carries upsert marker" "<!-- auto-rebase-success -->" "$success_body"
assert_contains "success comment names merged PR" "#142" "$success_body"
assert_contains "success comment shows new SHA" "abc1234" "$success_body"
assert_contains "success comment mentions opt-out" "do-not-rebase" "$success_body"

echo ""
echo "format_conflict_comment"

conflict_body=$(format_conflict_comment 142 "src/foo.py,src/bar.py")
assert_contains "conflict comment carries upsert marker" "<!-- auto-rebase-conflict -->" "$conflict_body"
assert_contains "conflict comment names merged PR" "#142" "$conflict_body"
assert_contains "conflict comment lists src/foo.py" "src/foo.py" "$conflict_body"
assert_contains "conflict comment lists src/bar.py" "src/bar.py" "$conflict_body"
assert_contains "conflict comment mentions rebase-conflict label" "rebase-conflict" "$conflict_body"
assert_contains "conflict comment instructs --force-with-lease" "force-with-lease" "$conflict_body"

echo ""
echo "format_overlap_warning_comment"

overlap_body=$(format_overlap_warning_comment 142 $'docs/decisions/adr-010.md\ndocs/decisions/adr-011.md')
assert_contains "overlap comment carries upsert marker" "<!-- auto-rebase-overlap -->" "$overlap_body"
assert_contains "overlap comment names merged PR" "#142" "$overlap_body"
assert_contains "overlap comment lists first overlapping path" "adr-010.md" "$overlap_body"
assert_contains "overlap comment lists second overlapping path" "adr-011.md" "$overlap_body"
assert_contains "overlap comment explains no auto-rebase attempted" "did **not**" "$overlap_body"
assert_contains "overlap comment mentions rebase-conflict label" "rebase-conflict" "$overlap_body"

# ── Summary ──

echo ""
echo "──────────────────────────────────────────"
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
if (( FAIL > 0 )); then
  printf "Failed:\n"
  for n in "${FAILED_NAMES[@]}"; do
    printf "  - %s\n" "$n"
  done
  exit 1
fi
echo "All assertions passed."
