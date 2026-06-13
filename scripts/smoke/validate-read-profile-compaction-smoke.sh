#!/usr/bin/env bash
# Validate read-profile compaction smoke outputs (Phases A–C).
# Usage: validate-read-profile-compaction-smoke.sh <phase> <output.txt>
set -euo pipefail

PHASE="${1:-}"
OUTPUT="${2:-}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

usage() {
  echo "Usage: validate-read-profile-compaction-smoke.sh <A|B|C|all> <output.txt>" >&2
  exit 2
}

[[ -n "$PHASE" && -n "$OUTPUT" && -f "$OUTPUT" ]] || usage

failures=0
ok() { echo "OK: $*"; }
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }

read_profile_row() {
  awk '/Session handshake/{hs=1} hs && /\| *Read profile *\|/{print; exit}' "$OUTPUT"
}

validate_phase_a() {
  if head -1 "$OUTPUT" | grep -qE '^Session handshake v[0-9]+'; then
    ok "Phase A: handshake is first line"
  elif grep -m1 -qE '^Session handshake v[0-9]+' "$OUTPUT"; then
    fail "Phase A: handshake present but not first line (preamble before handshake violates AGENTS contract)"
  else
    fail "Phase A: handshake missing"
  fi
  if read_profile_row | grep -qi 'startup-min'; then
    ok "Phase A: Read profile is startup-min"
  else
    fail "Phase A: Read profile is not startup-min ($(read_profile_row || echo missing))"
  fi
  if grep -q '## Session context receipt' "$OUTPUT"; then
    ok "Phase A: context receipt present"
  else
    fail "Phase A: context receipt missing"
  fi
  if grep -q 'process_session_start.md' "$OUTPUT"; then
    ok "Phase A: process_session_start.md in receipt or narrative"
  else
    fail "Phase A: no process_session_start.md evidence"
  fi
}

validate_phase_b() {
  if grep -qE 'Session handshake v[0-9]+' "$OUTPUT"; then
    ok "Phase B: handshake present after compaction"
  else
    fail "Phase B: no handshake after compaction"
  fi
  if read_profile_row | grep -qi 'implementation'; then
    ok "Phase B: Read profile is implementation"
  else
    fail "Phase B: Read profile not implementation ($(read_profile_row || echo missing))"
  fi
  if grep -q '## Session context receipt' "$OUTPUT"; then
    ok "Phase B: context receipt present"
  else
    fail "Phase B: context receipt missing"
  fi
  if grep -q 'process_session_start.md' "$OUTPUT"; then
    ok "Phase B: process_session_start.md re-loaded"
  else
    fail "Phase B: no process_session_start.md evidence"
  fi
  if grep -qE 'process_gates\.md|domain_code_quality\.md|052-postmerge-retro-invariants' "$OUTPUT"; then
    ok "Phase B: implementation-scope file referenced"
  else
    fail "Phase B: no implementation-profile file evidence in output"
  fi
}

validate_phase_c() {
  if grep -qE 'Session handshake v[0-9]+' "$OUTPUT"; then
    ok "Phase C: handshake present after compaction"
  else
    fail "Phase C: no handshake after compaction"
  fi
  if read_profile_row | grep -qiE 'implementation|policy-adr'; then
    ok "Phase C: Read profile is implementation or policy-adr"
  else
    fail "Phase C: Read profile not implementation/policy-adr ($(read_profile_row || echo missing))"
  fi
  if grep -q '## Session context receipt' "$OUTPUT"; then
    ok "Phase C: context receipt present"
  else
    fail "Phase C: context receipt missing"
  fi
  if grep -qF '.github/prompts/NN-*.md' "$OUTPUT" || grep -qF 'NN-*.md' "$OUTPUT"; then
    ok "Phase C: quotes real trigger 1 from process_gates.md"
  else
    fail "Phase C: missing verbatim/near-verbatim trigger 1 quote (expected NN-*.md prompt reference)"
  fi
  if grep -qiE 'wrong|incorrect|false|does not|doesn.t|not (true|correct|accurate)|misleading' "$OUTPUT"; then
    ok "Phase C: identifies summary error"
  else
    fail "Phase C: does not flag false summary claim"
  fi
  if grep -qi 'fires only when issues carry the bug label' "$OUTPUT" \
    && ! grep -qiE 'wrong|incorrect|false|not (true|correct|accurate)' "$OUTPUT"; then
    fail "Phase C: repeats false summary as fact"
  else
    ok "Phase C: does not affirm false bug-label-only claim"
  fi
}

case "$PHASE" in
  A) validate_phase_a ;;
  B) validate_phase_b ;;
  C) validate_phase_c ;;
  all)
    fail "Use validate per phase file (A/B/C), not all on one file"
    ;;
  *) usage ;;
esac

if [[ "$failures" -gt 0 ]]; then
  echo "Validation failed: $failures failure(s)" >&2
  exit 1
fi
echo "Phase ${PHASE} validation passed"
