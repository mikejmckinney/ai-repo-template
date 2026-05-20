#!/usr/bin/env bash
# scripts/checks/120-phase4-invariants.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Phase 4 invariants (issue #229 Phase 4 / ADR-017) ---
echo "Checking Phase 4 components (issue #229 Phase 4 / ADR-017)..."

ADR017_PATH="docs/decisions/adr-017-template-repo-pre-commit-default.md"
if [[ -f "$ADR017_PATH" ]] \
  && grep -qE '^Accepted$' "$ADR017_PATH" 2>/dev/null; then
  pass "ADR-017 exists with Status: Accepted"
else
  fail "ADR-017 missing or Status line is not 'Accepted' ($ADR017_PATH)"
fi

# ADR-013 must NOT carry a supersession marker — ADR-017 is additive, not
# superseding. This guard catches an accidental supersession edit.
if grep -qiE 'superseded (in part )?by' docs/decisions/adr-013-pre-commit-on-main-default.md 2>/dev/null; then
  fail "ADR-013 carries a supersession marker; ADR-017 is additive (non-reversal)"
else
  pass "ADR-013 unchanged (no supersession marker — ADR-017 is additive)"
fi

if grep -q 'ADR-017' docs/decisions/README.md 2>/dev/null; then
  pass "docs/decisions/README.md indexes ADR-017"
else
  fail "docs/decisions/README.md missing ADR-017 row"
fi

# .pre-commit-config.yaml installed at root with shellcheck + actionlint.
if [[ -f ".pre-commit-config.yaml" ]]; then
  pass ".pre-commit-config.yaml exists at repo root (ADR-017)"
  if grep -q 'shellcheck-precommit' .pre-commit-config.yaml 2>/dev/null; then
    pass ".pre-commit-config.yaml configures shellcheck hook"
  else
    fail ".pre-commit-config.yaml missing shellcheck hook (ADR-017 V1)"
  fi
  if grep -q 'rhysd/actionlint' .pre-commit-config.yaml 2>/dev/null; then
    pass ".pre-commit-config.yaml configures actionlint hook"
  else
    fail ".pre-commit-config.yaml missing actionlint hook (ADR-017 V1)"
  fi
else
  fail ".pre-commit-config.yaml missing at repo root (ADR-017 V1)"
fi

# Heavyweight template scaffold preserved + cross-links ADR-017.
if grep -q 'ADR-017' .pre-commit-config.yaml.template 2>/dev/null; then
  pass ".pre-commit-config.yaml.template cross-links ADR-017 (ADR-017 V2)"
else
  fail ".pre-commit-config.yaml.template missing ADR-017 cross-link (ADR-017 V2)"
fi

# Cap-override justification rule lives in pr-resolve-all.md.
if grep -q 'Override justification' .github/prompts/pr-resolve-all.md 2>/dev/null; then
  pass "pr-resolve-all.md documents the cap-override justification rule"
else
  fail "pr-resolve-all.md missing cap-override justification rule (issue #229 Phase 4)"
fi

# External reviewer mirrors stay aligned with the canonical Judge gate.
for reviewer_file in ".cursor/BUGBOT.md" ".gemini/styleguide.md"; do
  if grep -q 'Cap-override justification gate' "$reviewer_file" 2>/dev/null; then
    pass "$reviewer_file mirrors the cap-override gate (issue #229 Phase 4)"
  else
    fail "$reviewer_file missing cap-override gate mirror (issue #229 Phase 4)"
  fi
done

echo ""
