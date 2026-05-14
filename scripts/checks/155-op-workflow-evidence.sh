#!/usr/bin/env bash
# scripts/checks/155-op-workflow-evidence.sh — issue #313
#
# Soft-warn evidence check for the OP issue→merge playbook
# (`.github/prompts/op-issue-workflow.md`). This is a STATIC repo-grep check
# (no network, no `gh api`) consistent with every other module sourced by
# `test.sh`. Per ADR-026, the repo can only validate the shape of declared
# evidence and the references between docs; runtime PR/issue inspection
# belongs to CI workflows, not to test.sh.
#
# What it verifies:
#   1. Playbook file exists at the canonical path.
#   2. Playbook enumerates Phases 0–7 (intake → merge).
#   3. Playbook records "current" handshake token / AGENTS_MD_VERSION at
#      plan time (NOT a hardcoded vN literal in normative content). The
#      sole permitted literal is the explicit Anti-pattern example
#      illustrating what NOT to do.
#   4. Playbook contains an Anti-patterns section (recurrence prevention).
#   5. CLAUDE.md, .github/copilot-instructions.md,
#      .github/prompts/repo-onboarding.md, and
#      .github/prompts/pr-resolve-all.md each cross-link to the playbook.
#
# All findings emit `pass` or `warn` only — never `fail`. Hardening to
# `fail`-on-recurrence is a separate, explicitly-gated PR per the
# capture → soft-warn → hard-block-on-recurrence three-stage rollout
# (issue #313 plan v2).

PLAYBOOK=".github/prompts/op-issue-workflow.md"

echo "Checking OP issue→merge playbook evidence (#313)..."

# 1. Playbook file presence.
if [[ -f "$PLAYBOOK" ]]; then
  pass "OP playbook present at $PLAYBOOK"
else
  warn "OP playbook missing: expected $PLAYBOOK (issue #313)"
  return 0 2>/dev/null || exit 0
fi

# 2. Phase 0–7 enumeration.
missing_phases=()
for n in 0 1 2 3 4 5 6 7; do
  if grep -qE "^#+[[:space:]]*Phase[[:space:]]+${n}\b" "$PLAYBOOK"; then
    :
  else
    missing_phases+=("$n")
  fi
done
if [[ ${#missing_phases[@]} -eq 0 ]]; then
  pass "OP playbook enumerates all 8 phases (Phase 0–7)"
else
  warn "OP playbook missing phase headings: ${missing_phases[*]} (#313)"
fi

# 3. "current" handshake / AGENTS_MD_VERSION wording present, and no
# hardcoded token outside the Anti-patterns illustrative example.
if grep -qE "current[[:space:]]+(handshake|AGENTS_MD_VERSION)\b" "$PLAYBOOK"; then
  pass "OP playbook uses 'current handshake / AGENTS_MD_VERSION' wording"
else
  warn "OP playbook should reference 'current' handshake/AGENTS_MD_VERSION rather than a hardcoded vN (canary drift risk; #313)"
fi

# Count vN literals OUTSIDE the Anti-patterns section. awk scans for the
# Anti-pattern heading; toggles a skip flag on; resets at next same-level
# heading. We tolerate vN inside that one section only.
vn_outside=$(awk '
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
if [[ "$vn_outside" -eq 0 ]]; then
  pass "OP playbook does not hardcode 'Session handshake vN' outside Anti-patterns"
else
  warn "OP playbook hardcodes 'Session handshake vN' $vn_outside time(s) outside Anti-patterns (canary drift; #313)"
fi

# 4. Anti-patterns section presence.
if grep -qiE "^#+[[:space:]]*Anti.?patterns" "$PLAYBOOK"; then
  pass "OP playbook contains Anti-patterns section"
else
  warn "OP playbook missing Anti-patterns section (recurrence prevention; #313)"
fi

# 5. Cross-link presence in each linkage file.
linkage_files=(
  "CLAUDE.md"
  ".github/copilot-instructions.md"
  ".github/prompts/repo-onboarding.md"
  ".github/prompts/pr-resolve-all.md"
)
for f in "${linkage_files[@]}"; do
  if [[ ! -f "$f" ]]; then
    warn "$f missing — cannot verify OP playbook cross-link"
    continue
  fi
  if grep -qF "op-issue-workflow.md" "$f"; then
    pass "$f cross-links OP playbook"
  else
    warn "$f does not cross-link $PLAYBOOK (Read-First / forward-link expected; #313)"
  fi
done

echo ""
