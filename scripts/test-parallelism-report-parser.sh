#!/usr/bin/env bash
# Unit tests for the awk + comm pipelines used by the
# `agent-parallelism-report.yml` workflow to:
#   1. Parse owned-path globs out of .context/rules/agent_ownership.md
#   2. Classify cross-PR file overlap as hard / soft / none
#
# Why this test exists
# --------------------
# The workflow parses the canonical "Ownership Table" markdown table
# in agent_ownership.md to drive soft-overlap classification. If a
# future PR restructures the table (column order, role names,
# code-fence style), the parser silently produces zero prefixes and
# soft classification disappears. ADR-009 picks fail-soft for the
# workflow itself, but this test hard-fails so format-changing PRs
# trip CI at the change rather than later.
#
# The parser itself lives in scripts/parse-ownership-table.sh (single
# source of truth, also called by the workflow). This test calls the
# same script so the workflow and the test can never drift.
#
# Run: bash scripts/test-parallelism-report-parser.sh

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

assert_not_contains() {
  local name="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s (unexpected match: %q)\n' "$name" "$needle"
  else
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  fi
}

# ── Parser: shell out to the shared script (single source of truth). ──
# Reading from stdin keeps the call sites identical to the inline
# function this replaced (`printf ... | parse_ownership`).
parse_ownership() {
  ./scripts/parse-ownership-table.sh
}

# ── Classification helpers (mirror the workflow's comm + awk logic) ──
classify_overlap() {
  # Args: file_a (one path per line), file_b (one path per line),
  #       prefixes (role<TAB>prefix lines)
  local me="$1" other="$2" prefixes="$3"
  local hard
  hard=$(comm -12 <(sort -u "$me") <(sort -u "$other"))
  if [[ -n "$hard" ]]; then
    echo "hard"
    return
  fi
  if [[ -n "$prefixes" ]]; then
    while IFS=$'\t' read -r role prefix; do
      [[ -z "$prefix" ]] && continue
      if awk -v p="$prefix" 'index($0, p"/")==1 || $0==p {found=1; exit} END{exit !found}' "$me" \
         && awk -v p="$prefix" 'index($0, p"/")==1 || $0==p {found=1; exit} END{exit !found}' "$other"; then
        echo "soft"
        return
      fi
    done <<< "$prefixes"
  fi
  echo "none"
}

# ── Fixtures ──

FIXTURE_NORMAL='| Role       | Owned path globs                                                     | May also edit (with PM claim) |
|------------|----------------------------------------------------------------------|-------------------------------|
| Analyst    | `docs/research/**`                                                   | nothing (research-only)       |
| Frontend   | `src/frontend/**`, `src/components/**`                               | UI tests                      |
| Backend    | `src/backend/**`, `src/api/**`                                       | API tests                     |
| Docs       | README.md, AI_REPO_GUIDE.md, docs/**                                 | nothing                       |
| Judge      | nothing (review-only)                                                | nothing                       |'

FIXTURE_MALFORMED='Some prose without a table.

| Role | Owned |
| --- | --- |
| NotAValidRole | `src/x/**` | extra |'

# Regression fixture for the qualifier-stripping bug (codex P1 on PR #113).
# Without the `gsub(/ *\([^)]*\)/, "", globs)` step, the comma inside
# the `(except ...)` clause splits the Docs row into 3 broken pieces
# (`docs/** (except docs/decisions`, `docs/research/**)`, etc.) and
# the soft-overlap classification disappears for the entire `docs/`
# subtree. With the fix, we expect a single clean `Docs<TAB>docs`
# entry and nothing else from the qualified part.
FIXTURE_QUALIFIERS='| Role       | Owned path globs                                                     | May also edit |
|------------|----------------------------------------------------------------------|---------------|
| Architect  | `.context/rules/**` (except `agent_ownership.md`)                    | nothing       |
| Docs       | README.md, AI_REPO_GUIDE.md, docs/** (except docs/decisions/**, docs/research/**)  | nothing |
| Judge      | nothing (review-only, `.github/agents/judge.agent.md`)               | nothing       |'

# ── Test group 1: parser ──

echo "── Parser unit tests ──"

prefixes=$(printf '%s\n' "$FIXTURE_NORMAL" | parse_ownership)

assert_contains "parser: Analyst -> docs/research"       "Analyst	docs/research"      "$prefixes"
assert_contains "parser: Frontend -> src/frontend"       "Frontend	src/frontend"      "$prefixes"
assert_contains "parser: Frontend -> src/components"     "Frontend	src/components"    "$prefixes"
assert_contains "parser: Backend -> src/api"             "Backend	src/api"           "$prefixes"
assert_contains "parser: Docs -> docs (top-level)"       "Docs	docs"                  "$prefixes"
assert_not_contains "parser: 'nothing' globs are dropped" "Judge	nothing"            "$prefixes"

malformed_prefixes=$(printf '%s\n' "$FIXTURE_MALFORMED" | parse_ownership)
assert_eq "parser: malformed table yields zero prefixes (fail-soft)" "" "$malformed_prefixes"

# Qualifier-stripping regression check (codex P1 on PR #113).
q_prefixes=$(printf '%s\n' "$FIXTURE_QUALIFIERS" | parse_ownership)
assert_contains "parser (qualifier): Docs -> docs (single clean prefix)"  "Docs	docs"            "$q_prefixes"
assert_contains "parser (qualifier): Architect -> .context/rules"         "Architect	.context/rules" "$q_prefixes"
assert_not_contains "parser (qualifier): no broken 'docs/research' fragment" "docs/research"      "$q_prefixes"
assert_not_contains "parser (qualifier): no broken 'except' fragment"        "except"             "$q_prefixes"
assert_not_contains "parser (qualifier): Judge 'nothing' globs still dropped" "Judge"             "$q_prefixes"

# ── Test group 2: classification ──

echo ""
echo "── Classification unit tests ──"

# Build temp file lists for two PRs.
ME=$(mktemp)
OTHER_HARD=$(mktemp); OTHER_SOFT=$(mktemp); OTHER_NONE=$(mktemp)

# PR-A: touches docs/foo.md
printf 'docs/foo.md\n'                          > "$ME"
# PR-B: touches docs/foo.md (same file) → hard
printf 'docs/foo.md\n'                          > "$OTHER_HARD"
# PR-C: touches docs/bar.md (same prefix, different file) → soft
printf 'docs/bar.md\n'                          > "$OTHER_SOFT"
# PR-D: touches src/api/login.ts → none
printf 'src/api/login.ts\n'                     > "$OTHER_NONE"

assert_eq "classify: hard overlap (same file)"  "hard" "$(classify_overlap "$ME" "$OTHER_HARD" "$prefixes")"
assert_eq "classify: soft overlap (same prefix, different file)" \
                                                "soft" "$(classify_overlap "$ME" "$OTHER_SOFT" "$prefixes")"
assert_eq "classify: no overlap"                "none" "$(classify_overlap "$ME" "$OTHER_NONE" "$prefixes")"

# Soft classification disappears when prefixes are empty (parser failed).
assert_eq "classify: soft -> none when prefixes are empty (fail-soft mode)" \
                                                "none" "$(classify_overlap "$ME" "$OTHER_SOFT" "")"

# Hard still detected even with empty prefixes.
assert_eq "classify: hard still detected when prefixes are empty" \
                                                "hard" "$(classify_overlap "$ME" "$OTHER_HARD" "")"

rm -f "$ME" "$OTHER_HARD" "$OTHER_SOFT" "$OTHER_NONE"

# ── Test group 3: live agent_ownership.md must parse cleanly ──
#
# Per ADR-009 §Implementation: format-changing PRs to agent_ownership.md
# must keep the table parser-friendly. This assertion catches drift at
# the change PR rather than at the next overlap report.

echo ""
echo "── Live ownership-map format guard ──"

LIVE_OWNERSHIP='.context/rules/agent_ownership.md'
if [[ -f "$LIVE_OWNERSHIP" ]]; then
  live_prefixes=$(parse_ownership < "$LIVE_OWNERSHIP")
  live_count=$(printf '%s\n' "$live_prefixes" | grep -c . || true)
  if [[ "$live_count" -ge 4 ]]; then
    PASS=$((PASS + 1))
    printf '  ✅ live agent_ownership.md parses to %d prefix(es) (>= 4)\n' "$live_count"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("live agent_ownership.md parse")
    printf '  ❌ live agent_ownership.md parses to only %d prefix(es); expected >= 4. Did the table format change? See ADR-009 §Implementation.\n' "$live_count"
  fi

  # Per-role anchor assertions: hard-fail if a known-stable row
  # disappears from the parsed output. Catches a class of malformed-
  # row drift (e.g. broken qualifier, role rename, column reorder)
  # that the count-only check above can miss — a few entries can
  # survive while specific roles silently lose their prefix. See
  # ADR-009 §Implementation and codex P2 on PR #113.
  for anchor in \
      "Analyst	docs/research" \
      "Architect	docs/decisions" \
      "Backend	src/api" \
      "DevOps	scripts" \
      "Docs	docs" \
      "PM	.context/state" \
      "QA	tests"; do
    if printf '%s\n' "$live_prefixes" | grep -qF "$anchor"; then
      PASS=$((PASS + 1))
      printf '  ✅ live anchor present: %s\n' "$anchor"
    else
      FAIL=$((FAIL + 1))
      FAILED_NAMES+=("live anchor missing: $anchor")
      printf '  ❌ live anchor missing: %s. The ownership table changed in a way that drops this prefix. See ADR-009 §Implementation.\n' "$anchor"
    fi
  done
else
  PASS=$((PASS + 1))
  printf '  ✅ skipped: %s not present (test fixture isolation)\n' "$LIVE_OWNERSHIP"
fi

# ── Summary ──

echo ""
echo "──────────────────────────────"
echo "Passed: $PASS"
echo "Failed: $FAIL"
if (( FAIL > 0 )); then
  echo ""
  echo "Failed tests:"
  for n in "${FAILED_NAMES[@]}"; do echo "  - $n"; done
  exit 1
fi
echo "All assertions passed."
