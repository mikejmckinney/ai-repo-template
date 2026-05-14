#!/usr/bin/env bats
#
# scripts/tests/check-155-op-workflow-evidence.bats
#
# Fixture coverage for scripts/checks/155-op-workflow-evidence.sh.
# Mirrors check-047-outcome-validation.bats: each test fabricates a
# minimal markdown fixture and exercises the literal grep/awk patterns
# the check uses, so weakening the source check still leaves the
# contract assertions intact.
#
# Scope note (issue #313): check 155 is STATIC — it runs against the
# repo, not against PR/issue runtime state. Network-skipping cases
# (no-gh, no-auth, timeout) listed in the original plan v2 dispatch
# do not apply: every other module in scripts/checks/ is also static
# (only 040-file-content.sh greps for `gh api graphql` *strings* in
# workflow files; no module makes network calls). Runtime PR evidence
# inspection is a separate CI workflow concern.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
  CHECK_SCRIPT="$REPO_ROOT/scripts/checks/155-op-workflow-evidence.sh"
  export CHECK_SCRIPT
  PLAYBOOK="$REPO_ROOT/.github/prompts/op-issue-workflow.md"
  export PLAYBOOK
}

# --- Sanity: check script and playbook both exist on disk -------------------

@test "check 155 script exists and is non-empty" {
  [ -s "$CHECK_SCRIPT" ]
}

@test "OP playbook exists at canonical path" {
  [ -s "$PLAYBOOK" ]
}

# --- Phase enumeration: positive (all 8 phases present) ---------------------

@test "fixture with all 8 phase headings: count == 8" {
  fixture="$(mktemp "${TMPDIR:-/tmp}/check-155.XXXXXX")"
  cat > "$fixture" <<'EOF'
## Phase 0: Bootstrap
## Phase 1: Issue intake
## Phase 2: Pre-flight
## Phase 3: Plan
## Phase 4: Implement
## Phase 5: Review
## Phase 6: PR
## Phase 7: Merge
EOF
  count=0
  for n in 0 1 2 3 4 5 6 7; do
    grep -qE "^#+[[:space:]]*Phase[[:space:]]+${n}\b" "$fixture" && count=$((count+1))
  done
  rm -f "$fixture"
  [ "$count" -eq 8 ]
}

# --- Phase enumeration: negative (Phase 4 missing) --------------------------

@test "fixture missing Phase 4: count == 7" {
  fixture="$(mktemp "${TMPDIR:-/tmp}/check-155.XXXXXX")"
  cat > "$fixture" <<'EOF'
## Phase 0
## Phase 1
## Phase 2
## Phase 3
## Phase 5
## Phase 6
## Phase 7
EOF
  count=0
  for n in 0 1 2 3 4 5 6 7; do
    grep -qE "^#+[[:space:]]*Phase[[:space:]]+${n}\b" "$fixture" && count=$((count+1))
  done
  rm -f "$fixture"
  [ "$count" -eq 7 ]
}

# --- "current handshake / AGENTS_MD_VERSION" wording: positive --------------

@test "fixture using 'current handshake' wording: grep matches" {
  fixture="$(mktemp "${TMPDIR:-/tmp}/check-155.XXXXXX")"
  echo "Record the current handshake token and current AGENTS_MD_VERSION at plan time." > "$fixture"
  run grep -qE "current[[:space:]]+(handshake|AGENTS_MD_VERSION)" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
}

# --- Hardcoded vN literal OUTSIDE Anti-patterns: negative (canary drift) ----

@test "fixture with 'Session handshake v18' in normative section: detected" {
  fixture="$(mktemp "${TMPDIR:-/tmp}/check-155.XXXXXX")"
  cat > "$fixture" <<'EOF'
## Phase 3: Plan-as-comment
The plan must include `Session handshake v18` in plan_compliance.

## Anti-patterns
- Don't paste `Session handshake v17` or any literal vN.
EOF
  count=$(awk '
    BEGIN { skip = 0; depth = 0 }
    /^#+[[:space:]]/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      match(line, /^#+/)
      d = RLENGTH
      if (tolower(line) ~ /anti.?pattern/) { skip = 1; depth = d; next }
      if (skip && d <= depth) { skip = 0 }
    }
    !skip && /[Ss]ession[[:space:]]+handshake[[:space:]]+v[0-9]+/ { c++ }
    END { print c + 0 }
  ' "$fixture")
  rm -f "$fixture"
  [ "$count" -ge 1 ]
}

# --- Hardcoded vN literal ONLY inside Anti-patterns: positive (allowed) -----

@test "fixture with vN literal only inside Anti-patterns: count == 0 outside" {
  fixture="$(mktemp "${TMPDIR:-/tmp}/check-155.XXXXXX")"
  cat > "$fixture" <<'EOF'
## Phase 3: Plan-as-comment
Use the current handshake token from AGENTS.md.

## Anti-patterns
- Don't paste `Session handshake v17` (canary drift example).
- Don't paste `Session handshake v18` either.
EOF
  count=$(awk '
    BEGIN { skip = 0; depth = 0 }
    /^#+[[:space:]]/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      match(line, /^#+/)
      d = RLENGTH
      if (tolower(line) ~ /anti.?pattern/) { skip = 1; depth = d; next }
      if (skip && d <= depth) { skip = 0 }
    }
    !skip && /[Ss]ession[[:space:]]+handshake[[:space:]]+v[0-9]+/ { c++ }
    END { print c + 0 }
  ' "$fixture")
  rm -f "$fixture"
  [ "$count" -eq 0 ]
}

# --- Anti-patterns section presence -----------------------------------------

@test "fixture with Anti-patterns heading: grep matches" {
  fixture="$(mktemp "${TMPDIR:-/tmp}/check-155.XXXXXX")"
  echo "## Anti-patterns" > "$fixture"
  run grep -qiE "^#+[[:space:]]*Anti.?patterns" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
}

@test "fixture without Anti-patterns heading: grep fails" {
  fixture="$(mktemp "${TMPDIR:-/tmp}/check-155.XXXXXX")"
  echo "## Some Other Section" > "$fixture"
  run grep -qiE "^#+[[:space:]]*Anti.?patterns" "$fixture"
  rm -f "$fixture"
  [ "$status" -ne 0 ]
}

# --- Cross-link presence: positive ------------------------------------------

@test "fixture containing op-issue-workflow.md reference: grep matches" {
  fixture="$(mktemp "${TMPDIR:-/tmp}/check-155.XXXXXX")"
  echo "See [the playbook](.github/prompts/op-issue-workflow.md) for details." > "$fixture"
  run grep -qF "op-issue-workflow.md" "$fixture"
  rm -f "$fixture"
  [ "$status" -eq 0 ]
}

# --- Cross-link presence: negative ------------------------------------------

@test "fixture missing op-issue-workflow.md reference: grep fails" {
  fixture="$(mktemp "${TMPDIR:-/tmp}/check-155.XXXXXX")"
  echo "See some other doc." > "$fixture"
  run grep -qF "op-issue-workflow.md" "$fixture"
  rm -f "$fixture"
  [ "$status" -ne 0 ]
}

# --- Live verification against the actual repo playbook --------------------
# Catches accidental regressions in the canonical file itself, not just in
# fabricated fixtures. If the playbook in the repo loses Phase 4 or has a
# vN literal outside Anti-patterns, this test will fail loudly.

@test "live: real playbook contains all 8 phase headings" {
  count=0
  for n in 0 1 2 3 4 5 6 7; do
    grep -qE "^#+[[:space:]]*Phase[[:space:]]+${n}\b" "$PLAYBOOK" && count=$((count+1))
  done
  [ "$count" -eq 8 ]
}

@test "live: real playbook has zero hardcoded vN outside Anti-patterns" {
  count=$(awk '
    BEGIN { skip = 0; depth = 0 }
    /^#+[[:space:]]/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      match(line, /^#+/)
      d = RLENGTH
      if (tolower(line) ~ /anti.?pattern/) { skip = 1; depth = d; next }
      if (skip && d <= depth) { skip = 0 }
    }
    !skip && /[Ss]ession[[:space:]]+handshake[[:space:]]+v[0-9]+/ { c++ }
    END { print c + 0 }
  ' "$PLAYBOOK")
  [ "$count" -eq 0 ]
}
