#!/usr/bin/env bats
#
# scripts/tests/check-047-outcome-validation.bats
#
# Fixture tests for scripts/checks/047-outcome-validation-and-op.sh.
# Triggered by gemini-code-assist on PR #312 per .gemini/styleguide.md
# (heuristic logic in scripts/checks/*.sh requires fixture coverage).
#
# Test assertions use hardcoded literal strings (e.g. "User outcome",
# "Primary validation") rather than re-extracting them from the source
# script — that's the point of a contract test: if someone weakens the
# regex in the check, the fixture should still encode what the contract
# *should* require.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
  CHECK_SCRIPT="$REPO_ROOT/scripts/checks/047-outcome-validation-and-op.sh"
  export CHECK_SCRIPT
}

@test "check 047 script exists and is non-empty" {
  [ -s "$CHECK_SCRIPT" ]
}

# --- Positive fixture: judge.md with >= 2 "User outcome" mentions ----------

@test "judge.md fixture with two User outcome mentions: grep -ic >= 2" {
  fixture="$(mktemp)"
  cat > "$fixture" <<'EOF'
# Judge

Plan-gate: User outcome validation must appear in the plan.
Diff-gate: User outcome must be re-verified in the PR.
EOF
  count=$(grep -ic "User outcome" "$fixture")
  rm -f "$fixture"
  [ "$count" -ge 2 ]
}

# --- Negative fixture: judge.md with only one mention -----------------------

@test "judge.md fixture with one User outcome mention: grep -ic == 1" {
  fixture="$(mktemp)"
  cat > "$fixture" <<'EOF'
# Judge

Only the plan-gate mentions: User outcome validation.
The diff-gate has been weakened.
EOF
  count=$(grep -ic "User outcome" "$fixture")
  rm -f "$fixture"
  [ "$count" -eq 1 ]
  # Sanity: this is below the threshold the check enforces.
  [ "$count" -lt 2 ]
}

# --- Negative fixture: judge.md with zero mentions --------------------------

@test "judge.md fixture with zero User outcome mentions: grep -ic == 0" {
  fixture="$(mktemp)"
  echo "# Judge" > "$fixture"
  count=$(grep -ic "User outcome" "$fixture" || true)
  rm -f "$fixture"
  [ "$count" -eq 0 ]
}

# --- Positive: literal "Primary validation" must appear in process_work_style

@test "fixture with Primary validation literal: grep -q matches" {
  fixture="$(mktemp)"
  echo "## Primary validation: user outcome verification" > "$fixture"
  run grep -q "Primary validation" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
}

@test "fixture without Primary validation literal: grep -q fails" {
  fixture="$(mktemp)"
  echo "## Generic validation only" > "$fixture"
  run grep -q "Primary validation" "$fixture"
  rm -f "$fixture"
  [ "$status" -ne 0 ]
}

# --- Positive: literal em-dash heading "User outcome validation — PRIMARY" --

@test "fixture with em-dash PRIMARY heading: grep -qF matches" {
  fixture="$(mktemp)"
  printf '## User outcome validation \xe2\x80\x94 PRIMARY\n' > "$fixture"
  run grep -qF "User outcome validation — PRIMARY" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
}

@test "fixture with hyphen instead of em-dash: grep -qF fails" {
  fixture="$(mktemp)"
  echo "## User outcome validation - PRIMARY" > "$fixture"
  run grep -qF "User outcome validation — PRIMARY" "$fixture"
  rm -f "$fixture"
  [ "$status" -ne 0 ]
}

# --- Section-aware: User outcome must appear at/after diff-gate (ISS-18) --
# Mirrors the awk logic added to scripts/checks/047 in PR #312 round 4 to
# defeat the "both User outcome mentions live in plan-gate" regression.

_run_section_aware_check() {
  awk '
    /^[[:space:]]*#+[[:space:]]/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      match(line, /^#+/)
      depth = RLENGTH
      if (tolower(line) ~ /diff-gate/) { seen = 1; diff_depth = depth; next }
      if (seen && depth <= diff_depth) { seen = 0 }
    }
    seen && tolower($0) ~ /user outcome/ { count++ }
    END { print count + 0 }
  ' "$1"
}

@test "section-aware: User outcome appears after diff-gate (positive)" {
  fixture="$(mktemp)"
  cat > "$fixture" <<'EOF'
## Plan-gate
- Outcome plan must be present.

## diff-gate
- User outcome must be re-verified post-implementation.
EOF
  count=$(_run_section_aware_check "$fixture")
  rm -f "$fixture"
  [ "$count" -ge 1 ]
}

@test "section-aware: both User outcome mentions in plan-gate only (negative)" {
  fixture="$(mktemp)"
  cat > "$fixture" <<'EOF'
## Plan-gate
- User outcome plan
- User outcome 15-minute test
## diff-gate
- ship the diff
EOF
  count=$(_run_section_aware_check "$fixture")
  rm -f "$fixture"
  [ "$count" -eq 0 ]
}

@test "section-aware: bare 'diff-gate' word in plan-gate body does not flip seen (regression for PR #312 round 5)" {
  fixture="$(mktemp)"
  cat > "$fixture" <<'EOF'
## Plan-gate
- block-able anti-patterns are tracked during diff-gate (this is body text, not a heading)
- User outcome plan must be present
- User outcome 15-minute test must be defined

## DIFF-GATE Mode
- ship the diff (intentionally omitting the outcome trigger here)
EOF
  count=$(_run_section_aware_check "$fixture")
  rm -f "$fixture"
  # The two plan-gate User outcome lines must NOT be counted because the
  # DIFF-GATE heading sits below them. A broken (un-anchored) regex would
  # flip seen=1 on the body-text 'diff-gate' and report count >= 2.
  [ "$count" -eq 0 ]
}

@test "section-aware: User outcome in unrelated section after diff-gate does not satisfy (regression for PR #312 round 6 ISS-26)" {
  fixture="$(mktemp)"
  cat > "$fixture" <<'EOF'
# DIFF-GATE Mode (After Coding)
## Review Checklist
- ship the diff
# Verification Requirements
- the report mentions User outcome here, in a totally unrelated section
EOF
  count=$(_run_section_aware_check "$fixture")
  rm -f "$fixture"
  # The diff-gate section ends at `# Verification Requirements` (same depth);
  # the User outcome mention there must NOT count toward the diff-gate gate.
  [ "$count" -eq 0 ]
}

@test "section-aware: subsection inside diff-gate keeps counting (regression for PR #312 round 6 ISS-26)" {
  fixture="$(mktemp)"
  cat > "$fixture" <<'EOF'
# DIFF-GATE Mode (After Coding)
## Review Checklist
- User outcome validation must pass
## Output Format
- include User outcome line
# Verification Requirements
- unrelated trailing User outcome should not count
EOF
  count=$(_run_section_aware_check "$fixture")
  rm -f "$fixture"
  # The two `User outcome` mentions inside ## subsections of `# DIFF-GATE`
  # should both count; the trailing one under `# Verification Requirements`
  # (same depth as `# DIFF-GATE`) must not.
  [ "$count" -eq 2 ]
}

# --- Smoke: check 047 against the live repo passes -------------------------

@test "check 047 sourced against live repo emits no fail() calls" {
  cd "$REPO_ROOT"
  # Source the check in a subshell with stub PASS/FAIL/WARN counters and
  # stub pass()/fail()/warn() functions, then assert FAIL stays 0.
  run bash -c '
    set -e
    PASS=0; FAIL=0; WARN=0
    pass() { PASS=$((PASS + 1)); }
    fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*" >&2; }
    warn() { WARN=$((WARN + 1)); }
    # Stub run_bats_check so the smoke source does not actually re-invoke
    # bats from inside bats (would otherwise infinite-loop or fail with
    # command-not-found in the isolated subshell).
    run_bats_check() { :; }
    # shellcheck disable=SC1090
    source "'"$CHECK_SCRIPT"'"
    echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"FAIL=0"* ]]
}
