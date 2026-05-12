#!/usr/bin/env bash
# scripts/checks/045-preflight-gate.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Pre-flight gate extension (ADR-014) ---
# Four invariants ensure the broadened Pre-Flight gate stays wired up
# end-to-end. See ADR-014.
#
#   1. The outcome-validated opt-out label is declared in setup.sh so a
#      fresh `bash scripts/setup.sh` run creates it on the target repo.
#   2. ADR-014 exists with the expected Status line.
#   3. ADR-005's Status line marks partial supersession by ADR-014, so the
#      supersession trail is one grep away (per docs/decisions/README.md
#      "Supersession discipline").
#   4. AGENTS.md names the opt-out label literally inside the "Analyst
#      pre-flight gate" section, so the trigger condition is documented
#      where agents read it.
ADR014_PATH="docs/decisions/adr-014-extend-preflight-to-adhoc-deliverables.md"

# Note: setup.sh was modularized in PR #255 Phase 4c — the label/variable
# helper calls now live in scripts/setup/40-ensure-labels.sh and
# scripts/setup/50-ensure-variables.sh respectively. Greps below check those
# module files; scripts/setup.sh is now a thin orchestrator.
SETUP_LABELS_FILE="scripts/setup/40-ensure-labels.sh"
SETUP_VARS_FILE="scripts/setup/50-ensure-variables.sh"

label_declared() {
  local label="$1"
  awk -F '|' -v expected="$label" '
    /cat <<.*LABEL_SPECS/ { in_manifest = 1; next }
    in_manifest && /^LABEL_SPECS$/ { in_manifest = 0; next }
    in_manifest && $1 == expected { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$SETUP_LABELS_FILE"
}

if label_declared "outcome-validated"; then
  pass "$SETUP_LABELS_FILE declares the outcome-validated label (ADR-014)"
else
  fail "$SETUP_LABELS_FILE missing outcome-validated label declaration (ADR-014)"
fi

# Issue #220 Phase 1: new labels and variables wired up in setup modules and docs.
if label_declared "copilot:budget-paused"; then
  pass "$SETUP_LABELS_FILE declares the copilot:budget-paused label (issue #220)"
else
  fail "$SETUP_LABELS_FILE missing copilot:budget-paused label declaration (issue #220)"
fi

if label_declared "cap-override"; then
  pass "$SETUP_LABELS_FILE declares the cap-override label (issue #220)"
else
  fail "$SETUP_LABELS_FILE missing cap-override label declaration (issue #220)"
fi

if grep -q '_ensure_variable PR_RESOLVE_MAX_ROUNDS' "$SETUP_VARS_FILE" 2>/dev/null; then
  pass "$SETUP_VARS_FILE provisions PR_RESOLVE_MAX_ROUNDS variable (issue #220)"
else
  fail "$SETUP_VARS_FILE missing _ensure_variable PR_RESOLVE_MAX_ROUNDS (issue #220)"
fi

if grep -q 'PR_RESOLVE_MAX_ROUNDS' docs/guides/agent-pipeline.md 2>/dev/null; then
  pass "agent-pipeline.md documents PR_RESOLVE_MAX_ROUNDS knob (issue #220)"
else
  fail "agent-pipeline.md missing PR_RESOLVE_MAX_ROUNDS documentation (issue #220)"
fi

if [[ -f "$ADR014_PATH" ]] \
  && grep -qE '^Accepted$' "$ADR014_PATH" 2>/dev/null; then
  pass "ADR-014 exists with Status: Accepted"
else
  fail "ADR-014 missing or Status line is not 'Accepted' ($ADR014_PATH)"
fi

if grep -q 'superseded in part by ADR-014' docs/decisions/adr-005-analyst-preflight-gate.md 2>/dev/null; then
  pass "ADR-005 Status line marks partial supersession by ADR-014"
else
  fail "ADR-005 Status line missing 'superseded in part by ADR-014' (supersession discipline)"
fi

# Extract the "Analyst pre-flight gate" subsection (now in process_gates.md per ADR-021)
# and confirm it mentions the opt-out label literally.
gate_section=$(awk '/^## Analyst pre-flight gate/,/^## Plan-as-comment requirement/' .context/rules/process_gates.md 2>/dev/null)
if printf '%s' "$gate_section" | grep -q 'outcome-validated'; then
  pass "process_gates.md \"Analyst pre-flight gate\" section names outcome-validated (ADR-014)"
else
  fail "process_gates.md \"Analyst pre-flight gate\" section does not mention outcome-validated (ADR-014)"
fi

# Check context 00_INDEX.md has truth hierarchy
if grep -q "priority" .context/00_INDEX.md 2>/dev/null; then
  pass ".context/00_INDEX.md has priority information"
else
  warn ".context/00_INDEX.md missing priority information"
fi

# Validate backlog.yaml against its schema (requires check-jsonschema)
if command -v check-jsonschema &>/dev/null; then
  if check-jsonschema --schemafile .context/backlog.schema.json .context/backlog.yaml 2>/dev/null; then
    pass "backlog.yaml validates against backlog.schema.json"
  else
    fail "backlog.yaml failed schema validation against backlog.schema.json"
  fi
else
  warn "check-jsonschema not installed; skipping backlog.yaml schema validation (run: pip install check-jsonschema)"
fi

# Check README.md has Limitations, Future Improvements, and FAQ sections.
# These are required for the template itself and derived projects are
# instructed (by .github/ISSUE_TEMPLATE/agent_init.md) to preserve them.
# Header matching is case-insensitive: `## Limitations` and `## limitations`
# both pass. The assertion is that the section exists, not that contributors
# memorized the canonical casing. See postmortem-001 + ADR-013.
if grep -qi "^## Limitations" README.md 2>/dev/null; then
  pass "README.md has Limitations section"
else
  fail "README.md missing ## Limitations section (case-insensitive)"
fi

if grep -qi "^## Future Improvements" README.md 2>/dev/null; then
  pass "README.md has Future Improvements section"
else
  fail "README.md missing ## Future Improvements section (case-insensitive)"
fi

if grep -qi "^## FAQ" README.md 2>/dev/null; then
  pass "README.md has FAQ section"
else
  fail "README.md missing ## FAQ section (case-insensitive)"
fi

# FAQ section in README may link to docs/FAQ.md or keep content inline — both are valid.
if [ -f "docs/FAQ.md" ]; then
  if grep -q "docs/FAQ.md" README.md 2>/dev/null; then
    pass "README.md links to docs/FAQ.md"
  else
    warn "docs/FAQ.md exists but README.md does not link to it"
  fi
else
  pass "README.md keeps FAQ content inline (docs/FAQ.md not present)"
fi

echo ""
