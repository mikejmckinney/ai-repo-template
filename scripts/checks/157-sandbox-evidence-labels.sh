#!/usr/bin/env bash
# scripts/checks/157-sandbox-evidence-labels.sh — ADR-029 §"Drift detection"
#
# Asserts the two canonical sandbox-evidence labels declared in
# docs/decisions/adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md
# §"Canonical field labels" appear verbatim in any consuming surface that
# carries a "## Sandbox dogfood evidence" section.
#
# The two labels are:
#   Sandbox issue:
#   Sandbox PR:
#
# Once a surface contains the section header, this check enforces label
# parity with ADR-029. Surfaces without the header are not validated
# (advisory until they adopt the section).
#
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions.sh} and CWD == repo root.

echo "Running sandbox-evidence label drift check (ADR-029)..."

ADR_FILE="docs/decisions/adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md"
if [[ ! -f "$ADR_FILE" ]]; then
  fail "157-sandbox-evidence-labels: ADR-029 file missing at $ADR_FILE"
  return 0 2>/dev/null || exit 0
fi

# Canonical label list — must stay in sync with ADR-029 §"Canonical field labels".
CANONICAL_LABELS=(
  "Sandbox issue:"
  "Sandbox PR:"
)

# Confirm ADR-029 itself carries the canonical labels (self-consistency).
for label in "${CANONICAL_LABELS[@]}"; do
  if ! grep -qF "$label" "$ADR_FILE"; then
    fail "157-sandbox-evidence-labels: ADR-029 missing canonical label '$label'"
  fi
done

# Consuming surfaces that MUST carry the labels once they adopt the section.
SURFACES=(
  ".github/pull_request_template.md"
  ".agents/judge.md"
)

SECTION_HEADER="## Sandbox dogfood evidence"

for surface in "${SURFACES[@]}"; do
  if [[ ! -f "$surface" ]]; then
    warn "157-sandbox-evidence-labels: surface $surface not found — skipped"
    continue
  fi
  if ! grep -qF "$SECTION_HEADER" "$surface"; then
    # Surface has not yet adopted ADR-029 — advisory only.
    continue
  fi
  for label in "${CANONICAL_LABELS[@]}"; do
    if ! grep -qF "$label" "$surface"; then
      fail "157-sandbox-evidence-labels: surface $surface carries '$SECTION_HEADER' but is missing canonical label '$label' (ADR-029 §\"Canonical field labels\")"
    fi
  done
done

pass "157-sandbox-evidence-labels: ADR-029 label drift check complete"
