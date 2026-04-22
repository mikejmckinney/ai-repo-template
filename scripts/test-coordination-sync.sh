#!/usr/bin/env bash
# Unit tests for the awk pipelines used by agent-coordination-sync.yml.
#
# Why this test exists
# --------------------
# The workflow inspects .context/state/coordination.md with a few awk
# blocks to (a) extract stale lock blocks matching a closed PR, and
# (b) parse Active Locks into task/session/claimed-at tuples for the
# daily reconciliation job. If a future PR restructures the lock template
# in .context/state/README.md, these awk pipelines silently produce
# nothing and the workflow becomes a no-op. This test hard-fails so
# format-changing PRs trip CI at the change rather than later.
#
# The test re-implements the awk logic inline (rather than shelling out
# to a separate script) because the workflow itself inlines them. If the
# awk grows beyond ~30 lines, factor into scripts/coordination-sync-*.sh
# and update both the workflow and this test in lockstep.
#
# Run: bash scripts/test-coordination-sync.sh

set -euo pipefail

# Cleanup any tmp files we mktemp below.
TMP_FILES=()
cleanup() {
  if [[ ${#TMP_FILES[@]} -gt 0 ]]; then
    rm -f "${TMP_FILES[@]}"
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
  fi
}

assert_empty() {
  local name="$1" actual="$2"
  if [[ -z "$actual" ]]; then
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s (expected empty, got: %q)\n' "$name" "$actual"
  fi
}

# ── Awk replicas (mirror the workflow inline awk; keep in sync) ──

# Mirror of on-close-stale awk: emit lock blocks under "## Active Locks"
# matching the PR's branch (literal compare on the parsed Session value
# — NOT a regex, so branch names with metacharacters like `.`, `(`, `[`
# are safe) or carrying a managed-for-pr:NNN marker.
extract_stale_blocks() {
  local file="$1" branch="$2" pr="$3"
  awk -v branch="$branch" -v pr="$pr" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    /^## Active Locks/ { in_section=1; next }
    /^## / && !/^## Active Locks/ && !/^## Lock:/ {
      if (in_block && matched) print block
      in_section=0; in_block=0; block=""; matched=0; next
    }
    !in_section { next }
    /^## Lock:/ {
      if (in_block && matched) print block
      in_block=1; block=$0"\n"; matched=0; next
    }
    in_block {
      block = block $0 "\n"
      if (index($0, "**Session**:") == 1) {
        sess = trim(substr($0, length("**Session**:") + 1))
        if (sess == branch) matched=1
      }
      if ($0 ~ ("<!-- managed-for-pr:" pr " -->")) matched=1
    }
    END { if (in_block && matched) print block }
  ' "$file"
}

# Mirror of daily-reconciliation awk: emit task<TAB>session<TAB>claimed
# for each lock under "## Active Locks". Trims trailing whitespace on
# each value so a markdown line ending in stray spaces doesn't make a
# session compare-unequal to its corresponding open-PR head branch.
parse_active_locks() {
  local file="$1"
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    /^## Active Locks/ { in_section=1; next }
    /^## / && !/^## Active Locks/ && !/^## Lock:/ { in_section=0 }
    in_section && /^## Lock:/ {
      if (task != "") print task "\t" session "\t" claimed
      task=trim(substr($0, length("## Lock:") + 1))
      session=""; claimed=""; next
    }
    in_section && index($0, "**Session**:") == 1 {
      session=trim(substr($0, length("**Session**:") + 1)); next
    }
    in_section && index($0, "**Claimed At**:") == 1 {
      claimed=trim(substr($0, length("**Claimed At**:") + 1)); next
    }
    END { if (task != "") print task "\t" session "\t" claimed }
  ' "$file"
}

# ── Fixtures ──

FIXTURE_BASIC=$(cat <<'EOF'
# Coordination Board

## Active Locks

## Lock: feature-auth
**Role**: backend
**Session**: feat/auth-flow
**Claimed At**: 2026-04-15T10:00:00Z
**Expected Duration**: 2d
**Paths**:
- src/auth/**
**Depends On**: none
**Blocks**: none
**State**: in_progress

## Lock: pr-126
<!-- managed-for-pr:126 -->
**Role**: docs
**Session**: chore/125-agent-conventions
**Claimed At**: 2026-04-22T15:00:00Z
**Expected Duration**: 2h
**Paths**:
- AGENTS.md
**Depends On**: none
**Blocks**: none
**State**: in_progress

## Recent History

## Lock: old-task
**Role**: frontend
**Session**: feat/old
**Claimed At**: 2026-03-01T10:00:00Z

## Lock: pr-99
<!-- managed-for-pr:99 -->
**Role**: backend
**Session**: feat/recently-merged
**Claimed At**: 2026-03-15T08:00:00Z
EOF
)

FIXTURE_EMPTY=$(cat <<'EOF'
# Coordination Board

## Active Locks

<!-- No active locks. -->

## Recent History
EOF
)

FIXTURE_HUMAN_NOTE=$(cat <<'EOF'
# Coordination Board

## Active Locks

## Lock: hand-shaped
**Role**: pm
**Session**: chore/manual-edit
**Claimed At**: 2026-04-20T09:00:00Z
**Paths**:
- README.md
**State**: in_progress

PM note: this lock is held while we coordinate with the security team. Do
not auto-close.

## Recent History
EOF
)

# ── Tests: extract_stale_blocks ──

echo "extract_stale_blocks (on-close-stale logic)"

tmp=$(mktemp); TMP_FILES+=("$tmp"); printf '%s\n' "$FIXTURE_BASIC" > "$tmp"

# 1. Match by managed-for-pr marker.
out=$(extract_stale_blocks "$tmp" "some-other-branch" "126")
assert_contains "matches lock block by managed-for-pr:126 marker" "Lock: pr-126" "$out"

# 2. Match by branch in Session line.
out=$(extract_stale_blocks "$tmp" "feat/auth-flow" "999")
assert_contains "matches lock block by Session: feat/auth-flow" "Lock: feature-auth" "$out"

# 3. No match for unrelated branch and unrelated PR.
out=$(extract_stale_blocks "$tmp" "no-such-branch" "999")
assert_empty "no match for unrelated branch+pr" "$out"

# 4. Empty Active Locks → no match.
tmp2=$(mktemp); TMP_FILES+=("$tmp2"); printf '%s\n' "$FIXTURE_EMPTY" > "$tmp2"
out=$(extract_stale_blocks "$tmp2" "any-branch" "126")
assert_empty "empty Active Locks → no match" "$out"

# 5. Human-note inside a lock block doesn't break parsing (block ends at
#    next "## " non-Lock heading, which closes the section).
tmp3=$(mktemp); TMP_FILES+=("$tmp3"); printf '%s\n' "$FIXTURE_HUMAN_NOTE" > "$tmp3"
out=$(extract_stale_blocks "$tmp3" "chore/manual-edit" "999")
assert_contains "matches block even with trailing human note" "hand-shaped" "$out"
assert_contains "block includes the human note line" "PM note:" "$out"

# 6. Branch-name prefix collision: 'feat/auth' should NOT match
#    Session 'feat/auth-flow' (we compare the parsed Session value
#    as a literal string, not as a regex prefix).
out=$(extract_stale_blocks "$tmp" "feat/auth" "999")
assert_empty "branch-name prefix does not partial-match Session" "$out"

# 7. Regression: a lock under "## Recent History" with a matching
#    Session must NOT be returned as stale. The basic fixture has
#    `feat/recently-merged` in Recent History; querying with that
#    branch should yield nothing because the awk is section-scoped.
out=$(extract_stale_blocks "$tmp" "feat/recently-merged" "999")
assert_empty "Recent-History Session does not produce a stale match" "$out"

# 8. Regression: a managed-for-pr marker that lives under Recent
#    History (e.g. on a re-opened-then-closed PR) must not produce a
#    stale match either.
out=$(extract_stale_blocks "$tmp" "some-other-branch" "99")
assert_empty "Recent-History managed-for-pr marker does not match" "$out"

# 9. Regression: branch names with regex metacharacters (`.`, `(`,
#    `[`) must compare literally. A query for `feat.1` must NOT match
#    a Session of `feat-1` (which a naive regex would).
tmp_regex=$(mktemp); TMP_FILES+=("$tmp_regex")
printf '%s\n' \
  '# Coordination Board' \
  '' \
  '## Active Locks' \
  '' \
  '## Lock: regex-meta' \
  '**Role**: backend' \
  '**Session**: feat-1' \
  '**Claimed At**: 2026-04-22T10:00:00Z' \
  '**State**: in_progress' \
  '' \
  '## Recent History' > "$tmp_regex"
out=$(extract_stale_blocks "$tmp_regex" "feat.1" "999")
assert_empty "regex-metachar branch (feat.1) does not match feat-1" "$out"
out=$(extract_stale_blocks "$tmp_regex" "feat-1" "999")
assert_contains "literal branch (feat-1) does match feat-1" "regex-meta" "$out"

echo ""

# ── Tests: parse_active_locks ──

echo "parse_active_locks (daily-reconciliation logic)"

# 1. Basic fixture: two locks under Active Locks; the one under
#    Recent History is NOT included.
out=$(parse_active_locks "$tmp")
line_count=$(printf '%s\n' "$out" | grep -c . || true)
assert_eq "parses exactly 2 active locks (excludes Recent History)" "2" "$line_count"
assert_contains "row contains feature-auth task" "feature-auth	feat/auth-flow	2026-04-15T10:00:00Z" "$out"
assert_contains "row contains pr-126 task" "pr-126	chore/125-agent-conventions	2026-04-22T15:00:00Z" "$out"

# 2. Recent-History lock is excluded.
out=$(parse_active_locks "$tmp")
if printf '%s' "$out" | grep -q "old-task"; then
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("Recent History lock leaked into parse output")
  printf '  ❌ Recent History lock leaked into parse output\n'
else
  PASS=$((PASS + 1))
  printf '  ✅ Recent History lock excluded\n'
fi

# 3. Empty fixture → no rows.
out=$(parse_active_locks "$tmp2")
assert_empty "empty Active Locks → no rows" "$out"

# 4. Human-note fixture: lock parsed despite trailing prose.
out=$(parse_active_locks "$tmp3")
assert_contains "human-note fixture parses the lock" "hand-shaped	chore/manual-edit	2026-04-20T09:00:00Z" "$out"

# 5. Trailing-whitespace fixture: parsed values must be trimmed so a
#    downstream literal compare to an open-PR head branch succeeds.
tmp_ws=$(mktemp); TMP_FILES+=("$tmp_ws")
printf '%s\n' \
  '# Coordination Board' \
  '' \
  '## Active Locks' \
  '' \
  '## Lock: trailing-ws-lock   ' \
  '**Role**: backend' \
  '**Session**: feat/with-trailing-ws  ' \
  '**Claimed At**: 2026-04-22T10:00:00Z   ' \
  '**State**: in_progress' \
  '' \
  '## Recent History' > "$tmp_ws"
out=$(parse_active_locks "$tmp_ws")
assert_eq "trimmed task field" "trailing-ws-lock" "$(printf '%s' "$out" | cut -f1)"
assert_eq "trimmed session field" "feat/with-trailing-ws" "$(printf '%s' "$out" | cut -f2)"
assert_eq "trimmed claimed-at field" "2026-04-22T10:00:00Z" "$(printf '%s' "$out" | cut -f3)"

echo ""

# ── Live-format assertion ──
# Run against the real .context/state/coordination.md so a structural
# change to the lock template trips this test (same pattern used by
# scripts/test-parallelism-report-parser.sh against agent_ownership.md).
echo "Live-format check against .context/state/coordination.md"

REAL_COORD="$(cd "$(dirname "$0")/.." && pwd)/.context/state/coordination.md"
if [[ ! -f "$REAL_COORD" ]]; then
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("real coordination.md not found")
  printf '  ❌ %s not found\n' "$REAL_COORD"
else
  # Should not crash; output may be empty when there are no Active Locks.
  if parse_active_locks "$REAL_COORD" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf '  ✅ parse_active_locks runs against live file without error\n'
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("parse_active_locks crashed on live file")
    printf '  ❌ parse_active_locks crashed on live file\n'
  fi

  if extract_stale_blocks "$REAL_COORD" "no-such-branch" "0" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf '  ✅ extract_stale_blocks runs against live file without error\n'
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("extract_stale_blocks crashed on live file")
    printf '  ❌ extract_stale_blocks crashed on live file\n'
  fi
fi

echo ""
echo "── Summary ──"
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Failed assertions:"
  for n in "${FAILED_NAMES[@]}"; do
    printf '  - %s\n' "$n"
  done
  exit 1
fi
