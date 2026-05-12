#!/usr/bin/env bash
# scripts/checks/126-adr025-invariants.sh — ADR-025 GitHub-first live-state invariants.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- ADR-025 invariants (issue #298 / GitHub-first live state) ---
echo "Checking ADR-025 components (issue #298 / GitHub-first live state)..."

ADR025_PATH="docs/decisions/adr-025-github-issues-pr-comments-as-live-state.md"
# label_declared() is defined by 045-preflight-gate.sh, which test.sh sources
# before this check.

if [[ -f "$ADR025_PATH" ]] \
  && grep -qE '^Accepted$' "$ADR025_PATH" 2>/dev/null; then
  pass "ADR-025 exists with Status: Accepted"
else
  fail "ADR-025 missing or Status line is not 'Accepted' ($ADR025_PATH)"
fi

if grep -q 'ADR-025' docs/decisions/README.md 2>/dev/null; then
  pass "docs/decisions/README.md indexes ADR-025"
else
  fail "docs/decisions/README.md missing ADR-025 row"
fi

if [[ -f ".context/state/agent_state_comment_template.md" ]] \
  && grep -q 'agent-state:v1' .context/state/agent_state_comment_template.md 2>/dev/null \
  && ! grep -qi 'Pause reason' .context/state/agent_state_comment_template.md 2>/dev/null; then
  pass ".context/state/agent_state_comment_template.md exists with slim v1 schema"
else
  fail ".context/state/agent_state_comment_template.md missing, missing agent-state:v1 marker, or contains Pause reason"
fi

for removed in .context/state/task_template.md .context/state/handoff_template.md; do
  if [[ -e "$removed" ]]; then
    fail "$removed should be removed by ADR-025"
  else
    pass "$removed removed by ADR-025"
  fi
done

# Keep these label names hardcoded in the invariant: this is a contract
# assertion, not a parser for setup.sh. setup-managed labels live in the
# pipe-delimited manifest in scripts/setup/40-ensure-labels.sh.
for label in 'agent:claimed' 'agent:blocked' 'agent:awaiting-review'; do
  if label_declared "$label" \
    && grep -qF "| \`$label\` |" docs/guides/agent-pipeline.md; then
    pass "$label is setup-managed and documented"
  else
    fail "$label missing from setup labels or agent-pipeline docs"
  fi
done

# Use targeted prose regexes for the required cadence concepts instead of
# pinning full sentences; process_session_state.md is human-facing guidance
# and may be polished without changing the underlying ADR-025 contract.
if grep -qiE 'wait-for-input[[:space:]-]*pause' .context/rules/process_session_state.md 2>/dev/null \
  && grep -qiE 'auto-summar(y|izes|ized)\b' .context/rules/process_session_state.md 2>/dev/null \
  && grep -qiE 'session ends.*not merged/closed' .context/rules/process_session_state.md 2>/dev/null; then
  pass "process_session_state.md preserves ADR-025 live-state cadence triggers"
else
  fail "process_session_state.md missing one or more ADR-025 live-state cadence triggers"
fi

if grep -q '#263.*superseded' "$ADR025_PATH" 2>/dev/null \
  && grep -q '#299' "$ADR025_PATH" 2>/dev/null; then
  pass "ADR-025 marks #263 superseded and defers archive retention to #299"
else
  fail "ADR-025 missing #263 supersession or #299 deferral"
fi

echo ""
