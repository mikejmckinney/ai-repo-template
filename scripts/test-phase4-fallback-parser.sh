#!/usr/bin/env bash
# Unit tests for the awk pipelines used by the `phase4-fallback` job in
# .github/workflows/agent-relay-reviews.yml.
#
# Why this test exists
# --------------------
# The fallback job parses the canonical Phase 4 table out of a Copilot
# Resolution Report comment using two awk pipelines (extractor + ISS
# lookup). When Copilot wraps Thread IDs in backticks, a missing backtick
# strip in the lookup pipeline produced `(ISS-?)` audit replies on V7
# (issue #108). This test pins the column index, the equality semantics,
# and the backtick handling so the same regression can't happen silently
# again.
#
# The awk pipelines are duplicated inline below — the source of truth
# remains the workflow file. If you change the workflow's parser, also
# change this test.
#
# Run: bash scripts/test-phase4-fallback-parser.sh

set -euo pipefail

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

# ── Awk pipeline 1: extract Thread IDs from rows where Action == ⚠️ Errored ──
extract_errored_ids() {
  awk -F'|' '
    /^\|/ && !/^\|[[:space:]]*-+/ && !/^\|[[:space:]]*Thread[[:space:]]*\|/ {
      if (NF >= 7) {
        action=$6
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", action)
        if (action ~ /Errored/) {
          tid=$3
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", tid)
          gsub(/`/, "", tid)
          if (tid ~ /^PRRT_/) print tid
        }
      }
    }'
}

# ── Awk pipeline 2: look up ISS for a given Thread ID. Must strip back-
# ticks from $3 the same way pipeline 1 does, or equality fails (#108). ──
lookup_iss() {
  local target="$1"
  awk -F'|' -v target="$target" '
    /^\|/ && !/^\|[[:space:]]*-+/ {
      if (NF >= 7) {
        cur=$3
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cur)
        gsub(/`/, "", cur)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cur)
        if (cur == target) {
          out=$4; gsub(/^[[:space:]]+|[[:space:]]+$/, "", out)
          print out; exit
        }
      }
    }'
}

# ── Fixtures ──
# Canonical column order: Thread | Thread ID | ISS | Author | Action | Notes

# shellcheck disable=SC2016  # backticks in markdown table fixtures are literal
FIXTURE_BACKTICKED='| Thread | Thread ID | ISS | Author | Action | Notes |
|--------|-----------|-----|--------|--------|-------|
| [link](#) | `PRRT_kwDOQ1tpTM58q-s1` | ISS-01 | gemini-code-assist | ⚠️ Errored | FORBIDDEN |
| [link](#) | `PRRT_kwDOQ1tpTM58q-s9` | ISS-03 | gemini-code-assist | ⚠️ Errored | FORBIDDEN |
| [link](#) | `PRRT_kwDOQ1tpTM58q-tA` | ISS-02 | gemini-code-assist | ⚠️ Errored | FORBIDDEN |'

FIXTURE_PLAIN='| Thread | Thread ID | ISS | Author | Action | Notes |
|--------|-----------|-----|--------|--------|-------|
| [link](#) | PRRT_plain01 | ISS-04 | copilot-pull-request-reviewer | ⚠️ Errored | FORBIDDEN |'

# shellcheck disable=SC2016  # backticks in markdown fixture are literal
FIXTURE_MIXED='| Thread | Thread ID | ISS | Author | Action | Notes |
|--------|-----------|-----|--------|--------|-------|
| [link](#) | `PRRT_mix1` | ISS-05 | gemini-code-assist | ✅ Resolved | Fixed in abc1234 |
| [link](#) | `PRRT_mix2` | ISS-06 | copilot-pull-request-reviewer | ⚠️ Errored | FORBIDDEN |
| [link](#) | `PRRT_mix3` | ISS-07 | mikejmckinney | ⏭️ Skipped | Human-authored |'

# shellcheck disable=SC2016  # backticks in markdown fixture are literal
FIXTURE_ALL_RESOLVED='| Thread | Thread ID | ISS | Author | Action | Notes |
|--------|-----------|-----|--------|--------|-------|
| [link](#) | `PRRT_ok1` | ISS-08 | gemini-code-assist | ✅ Resolved | Fixed |'

# ── Tests ──
echo "Test group: extractor (awk pipeline 1)"

actual=$(printf '%s\n' "$FIXTURE_BACKTICKED" | extract_errored_ids | tr '\n' ',' | sed 's/,$//')
assert_eq "extractor: 3 backticked errored rows → 3 stripped IDs" \
  "PRRT_kwDOQ1tpTM58q-s1,PRRT_kwDOQ1tpTM58q-s9,PRRT_kwDOQ1tpTM58q-tA" "$actual"

actual=$(printf '%s\n' "$FIXTURE_PLAIN" | extract_errored_ids | tr '\n' ',' | sed 's/,$//')
assert_eq "extractor: plain (no backticks) errored row → 1 ID" \
  "PRRT_plain01" "$actual"

actual=$(printf '%s\n' "$FIXTURE_MIXED" | extract_errored_ids | tr '\n' ',' | sed 's/,$//')
assert_eq "extractor: mixed table → only the errored row" \
  "PRRT_mix2" "$actual"

actual=$(printf '%s\n' "$FIXTURE_ALL_RESOLVED" | extract_errored_ids | tr '\n' ',' | sed 's/,$//')
assert_eq "extractor: no errored rows → empty output" \
  "" "$actual"

echo ""
echo "Test group: ISS lookup (awk pipeline 2) — issue #108 regression coverage"

# These are the V7 failure cases — the extractor strips backticks so the
# extracted IDs have none; the lookup must match the same way.
actual=$(printf '%s\n' "$FIXTURE_BACKTICKED" | lookup_iss "PRRT_kwDOQ1tpTM58q-s1")
assert_eq "lookup: backticked table, stripped target → ISS-01 (was 'ISS-?' before #108 fix)" \
  "ISS-01" "$actual"

actual=$(printf '%s\n' "$FIXTURE_BACKTICKED" | lookup_iss "PRRT_kwDOQ1tpTM58q-s9")
assert_eq "lookup: backticked table, second row → ISS-03" \
  "ISS-03" "$actual"

actual=$(printf '%s\n' "$FIXTURE_BACKTICKED" | lookup_iss "PRRT_kwDOQ1tpTM58q-tA")
assert_eq "lookup: backticked table, third row → ISS-02" \
  "ISS-02" "$actual"

actual=$(printf '%s\n' "$FIXTURE_PLAIN" | lookup_iss "PRRT_plain01")
assert_eq "lookup: plain table → ISS-04" \
  "ISS-04" "$actual"

actual=$(printf '%s\n' "$FIXTURE_MIXED" | lookup_iss "PRRT_mix2")
assert_eq "lookup: mixed table, errored row → ISS-06" \
  "ISS-06" "$actual"

actual=$(printf '%s\n' "$FIXTURE_BACKTICKED" | lookup_iss "PRRT_does_not_exist")
assert_eq "lookup: missing target → empty (caller falls back to 'ISS-?')" \
  "" "$actual"

echo ""
echo "── Summary ──"
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'Failed tests:\n'
  printf '  - %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
exit 0
