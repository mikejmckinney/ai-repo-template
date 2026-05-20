#!/usr/bin/env bash
# scripts/checks/157-sandbox-evidence-labels.sh — ADR-029 §"Drift detection"
#
# Asserts the 5 canonical sandbox-evidence labels declared in
# docs/decisions/adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md
# §"Canonical 5 field labels" appear verbatim in any consuming surface that
# carries a "## Sandbox dogfood evidence" section.
#
# The 5 labels are:
#   Sandbox issue:
#   Sandbox PR:
#   Negative control:
#   Positive control:
#   Role-comment render:
#
# Advisory until consuming surfaces (PR template, judge.md, verify-pr.sh)
# adopt the section header. Once a surface contains the header, this check
# enforces label parity with ADR-029.
#
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions.sh} and CWD == repo root.

echo "Running sandbox-evidence label drift check (ADR-029)..."

ADR_FILE="docs/decisions/adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md"
if [[ ! -f "$ADR_FILE" ]]; then
    fail "157-sandbox-evidence-labels: ADR-029 file missing at $ADR_FILE"
    return 0 2>/dev/null || exit 0
fi

# Canonical label list — must stay in sync with ADR-029 §"Canonical 5 field labels".
CANONICAL_LABELS=(
    "Sandbox issue:"
    "Sandbox PR:"
    "Negative control:"
    "Positive control:"
    "Role-comment render:"
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
    "scripts/verify-pr.sh"
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
            fail "157-sandbox-evidence-labels: surface $surface carries '$SECTION_HEADER' but is missing canonical label '$label' (ADR-029 §\"Canonical 5 field labels\")"
        fi
    done
done

pass "157-sandbox-evidence-labels: ADR-029 label drift check complete"
