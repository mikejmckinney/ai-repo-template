#!/usr/bin/env bash
# scripts/checks/060-exemption-predicates.sh
#
# ADR-028 exemption predicate validator check — DevOps implementation (issue #349).
# Sourced by test.sh; relies on pass()/fail()/warn() and $PASS/$FAIL/$WARN from
# scripts/lib/{logging,assertions}.sh. CWD == repo root (set by test.sh).
#
# Scope: This check runs the validator against in-repo fixtures only.
# Live PR parent_compliance.exemptions[] parsing is a deliberate follow-up;
# the library is the contract surface this PR delivers.
#
# Checks:
#   1. The three ADR-028 registry YAMLs exist and parse as valid YAML.
#   2. scripts/lib/exemption_predicates.py --self-check passes all fixtures.
#
# Note on numbering: this file uses prefix 060. An existing 060-markdown-structure.sh
# also exists; both run (lexical sort: 060-exemption-predicates.sh runs first).
# A renumber to 056 or 058 would avoid the tie — tracked as opportunity note.

echo "Checking ADR-028 exemption predicate library (smoke-check; live-PR validation tracked separately)..."

REGISTRY_FILES=(
  ".context/state/judge_runtime_allowlist.yaml"
  ".context/state/exemption_label_appliers.yaml"
  ".context/state/adr_exemption_registry.yaml"
)

# --- 1. Registry files exist and parse as YAML ---
for reg in "${REGISTRY_FILES[@]}"; do
  if [[ ! -f "$reg" ]]; then
    fail "$reg is missing (required by ADR-028 exemption predicate validator)"
    continue
  fi

  if python3 -c "
import sys, yaml
try:
    data = yaml.safe_load(open('$reg'))
    if data is None:
        sys.exit(1)
    sys.exit(0)
except Exception as e:
    print(f'parse error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
    pass "$reg exists and parses as valid YAML"
  else
    fail "$reg failed YAML parse check"
  fi
done

# --- 2. Self-check: run predicate suite against all fixtures ---
PREDICATES_PY="scripts/lib/exemption_predicates.py"
FIXTURE_DIR="scripts/tests/fixtures/exemptions"

if [[ ! -f "$PREDICATES_PY" ]]; then
  fail "$PREDICATES_PY missing — cannot run exemption predicate self-check"
else
  pass "$PREDICATES_PY exists"
fi

if [[ ! -d "$FIXTURE_DIR" ]]; then
  fail "$FIXTURE_DIR missing — no fixtures for exemption predicate self-check"
else
  pass "$FIXTURE_DIR exists"
fi

if [[ -f "$PREDICATES_PY" && -d "$FIXTURE_DIR" ]]; then
  # Capture output and exit code separately
  selfcheck_output="$(python3 "$PREDICATES_PY" --self-check 2>&1)"
  selfcheck_exit=$?

  if [[ $selfcheck_exit -eq 0 ]]; then
    # Extract summary line (last non-empty line)
    summary="$(echo "$selfcheck_output" | grep -E '^[0-9]+/[0-9]+ fixtures' | tail -1)"
    pass "exemption_predicates.py --self-check: ${summary:-all fixtures passed}"
  else
    # Print each FAIL line individually so test.sh summary is meaningful
    while IFS= read -r line; do
      if [[ "$line" == *"[FAIL]"* ]]; then
        fail "exemption_predicates.py --self-check: $line"
      fi
    done <<< "$selfcheck_output"
    # If no individual FAIL lines were found, emit a generic failure
    if ! echo "$selfcheck_output" | grep -q '\[FAIL\]'; then
      fail "exemption_predicates.py --self-check exited $selfcheck_exit (no FAIL lines found)"
    fi
    # Show summary for context
    summary="$(echo "$selfcheck_output" | grep -E '^[0-9]+/[0-9]+ fixtures' | tail -1)"
    if [[ -n "$summary" ]]; then
      warn "exemption_predicates.py --self-check summary: $summary"
    fi
  fi
fi

echo ""
