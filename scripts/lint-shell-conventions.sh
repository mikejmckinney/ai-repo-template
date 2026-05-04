#!/usr/bin/env bash
# Project-specific shell convention linter (issue #229 Phase 1.5).
# Encodes runtime-semantics rules that shellcheck cannot catch.
#
# RULE-01  Do not use 'grep -c' in scripts with 'set -e' or 'pipefail'.
#          'grep -c' exits 1 on zero matches, triggering set -e and
#          aborting the script. Use 'grep ... | wc -l | tr -d " "' instead.
#          Root cause: PR #228 R5→R7 — shellcheck SC2126 *recommended*
#          'grep -c' as a style improvement; that recommendation is wrong
#          for scripts that use set -e / pipefail.
#          Safe pattern: $(grep pattern file | wc -l | tr -d ' ')
#          If 'grep -c' is genuinely correct (e.g., protected by || true on
#          the same line), add per-file suppression with a reason comment.
#
# RULE-02  In grep -E literal-quoted patterns, '|'-delimited alternatives
#          must end with an end-of-line anchor ('$'), word-boundary ('\b'),
#          or a closing group ')' before the closing quote. Unanchored
#          alternatives match as substrings of longer strings.
#          Root cause: PR #228 R7→R8 — an unanchored _PLACEHOLDER_EXCLUDE
#          regex allowed 'coordination.md.bak' to match the exclude list
#          because it was a substring of 'coordination.md'.
#          NOTE: Variable-expanded patterns (grep -E "$VAR") cannot be
#          checked statically; RULE-02 only applies to literal quoted strings.
#
# Inline suppression (use sparingly; reason is required):
#   # shell-conventions:disable=RULE-NN reason: <why>
#
# Usage:  bash scripts/lint-shell-conventions.sh [<path> ...]
#         Defaults to searching scripts/ directory.
# Exit:   0 = all pass; 1 = one or more violations found.

set -uo pipefail

TARGET_PATHS=("${@:-scripts/}")
VIOLATION_FILE=$(mktemp)
# shellcheck disable=SC2317  # invoked via trap
cleanup() { rm -f "$VIOLATION_FILE"; }
trap cleanup EXIT

find "${TARGET_PATHS[@]}" -name '*.sh' ! -name 'lint-shell-conventions.sh' -type f 2>/dev/null \
  | sort | while IFS= read -r file; do

  # ── RULE-01: grep -c with set -e / pipefail ──────────────────────────────
  if ! grep -qE '#[[:space:]]*shell-conventions:disable=RULE-01' "$file"; then
    if grep -qE '(^|[^#[:alnum:]])(set[[:space:]]+-[a-z]*e([^a-z]|$)|set[[:space:]]+-o[[:space:]]+pipefail|pipefail)' "$file"; then
      # Look for grep -c (short option, combined or standalone) not on a line
      # that also contains '|| true' or '|| echo' (which guard the exit code).
      while IFS= read -r grep_line; do
        if ! printf '%s' "$grep_line" | grep -qE '\|\|[[:space:]]*(true|echo|:)'; then
          printf 'RULE-01: %s\n' "$file"
          printf '%s\n' "VIOLATION" >>"$VIOLATION_FILE"
          break
        fi
      done < <(grep -E '(^|[^#[:alnum:]])grep[[:space:]]+-[a-zA-Z]*c([[:space:]]|$)' "$file" \
                 | grep -v '#[[:space:]]*shell-conventions:disable' || true)
    fi
  fi

  # ── RULE-02: unanchored alternatives in grep -E literal patterns ──────────
  if ! grep -qE '#[[:space:]]*shell-conventions:disable=RULE-02' "$file"; then
    # Detect: grep -E 'X|Y' (single-quoted) where last char before closing '
    # is not $, ), \b, or \.
    if grep -qE "grep[[:space:]]+-[a-zA-Z]*E[[:space:]]+'[^']*\|[^']*[^\$')\\\\]'" "$file" \
      || grep -qE 'grep[[:space:]]+-[a-zA-Z]*E[[:space:]]+"[^"]*\|[^"]*[^\$")\]"' "$file"; then
      printf 'RULE-02: %s — grep -E pattern with "|" alternatives lacks end-anchor ($, \\b, or ) before closing quote\n' "$file"
      printf '%s\n' "VIOLATION" >>"$VIOLATION_FILE"
    fi
  fi

done

VIOLATIONS=$(wc -l <"$VIOLATION_FILE" | tr -d ' ')
if [[ "$VIOLATIONS" -eq 0 ]]; then
  printf 'lint-shell-conventions: all checks passed.\n'
  exit 0
else
  printf 'lint-shell-conventions: %d violation(s) found.\n' "$VIOLATIONS"
  exit 1
fi
