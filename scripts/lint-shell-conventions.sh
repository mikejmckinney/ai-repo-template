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
#          or a closing group ')' before the closing quote. A lone backslash
#          is NOT a valid anchor (incomplete escape). Unanchored
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
VIOLATION_FILE=$(mktemp "${TMPDIR:-/tmp}/shell-linter.XXXXXX")
# shellcheck disable=SC2317  # invoked via trap
cleanup() { rm -f "$VIOLATION_FILE"; }
trap cleanup EXIT

find "${TARGET_PATHS[@]}" -name '*.sh' ! -name 'lint-shell-conventions.sh' -type f 2>/dev/null \
  | sort | while IFS= read -r file; do

  # ── RULE-01: grep -c with set -e / pipefail ──────────────────────────────
  if ! grep -qE '#[[:space:]]*shell-conventions:disable=RULE-01' "$file"; then
    # ISS-10: exclude comment lines before checking for strict-mode signals
    # so a script with only a *comment* mentioning 'set -e' is not treated
    # as strict-mode.
    # ISS-22/ISS-25: [a-z]*e[a-z]* matches flag clusters containing e (e.g.
    #   set -euo); |pipefail bare alternation removed as redundant and too broad.
    # ISS-34: also match set -o errexit (long-form equivalent of set -e).
    # ISS-42: pipefail|errexit → errexit only; pipefail alone does not cause
    #   grep -c to abort; only set -e / set -o errexit triggers that.
    # ISS-41: strip inline comments (e.g. 'cmd # set -e') before matching
    #   so 'set -e' in a trailing comment does not falsely trigger RULE-01.
    # ISS-47: also detect shebang-level errexit (e.g. #!/bin/bash -e or -euo).
    if head -n 1 "$file" | grep -qE '^#!.*[[:space:]]-[a-z]*e' \
      || grep -vE '^[[:space:]]*#' "$file" \
      | sed 's/[[:space:]]*#.*//' \
        | grep -qE '(^|[^[:alnum:]])(set[[:space:]]+-[a-z]*e[a-z]*([^a-z]|$)|set[[:space:]]+-o[[:space:]]+errexit)'; then
      # Look for grep -c / grep --count not on a line that also contains
      # '|| true' or '|| echo' (which guard the exit code).
      # ISS-12: also match --count long form.
      # ISS-13: two-step detection catches split option forms like
      #   grep -E -c 'pat' (where -c is not the first option token).
      # ISS-15: filter to RULE-01 disable only (not any disable comment).
      while IFS= read -r grep_line; do
        # ISS-24: if/elif/while/until consume grep's exit code — not a set -e hazard.
        # ISS-35: until added alongside while (both consume the loop-condition exit code).
        # ISS-44: ! negation is safe: ! grep-c converts 1→0 before set -e sees it.
        # ISS-48: && guard reverted — ISS-51 showed that && inside a quoted pattern
        #   could fool the safe-guard regex; the fix would require quote-aware parsing
        #   which is out of scope. Use if/||true/! instead of && for grep -c.
        if ! printf '%s' "$grep_line" | grep -qE '(\|\|[[:space:]]*(true|echo|:)|(^|[[:space:]])(if|elif|while|until|!)[[:space:]])'; then
          printf 'RULE-01: %s\n' "$file"
          printf '%s\n' "VIOLATION" >>"$VIOLATION_FILE"
          break
        fi
      done < <({
        grep -E '(^|[^#[:alnum:]])grep[[:space:]]+(-[a-zA-Z]*c[a-zA-Z]*|--count)([[:space:]]|$)' "$file"
        grep -E '(^|[^#[:alnum:]])grep[[:space:]]+-[a-zA-Z]+[[:space:]]+.*(-[a-zA-Z]*c[a-zA-Z]*|--count)([[:space:]]|$)' "$file"
      } | sort -u \
        | grep -v '^[[:space:]]*#' \
        | grep -v '#[[:space:]]*shell-conventions:disable=RULE-01' || true)
    fi
  fi

  # ── RULE-02: unanchored alternatives in grep -E literal patterns ──────────
  if ! grep -qE '#[[:space:]]*shell-conventions:disable=RULE-02' "$file"; then
    # Detect: grep -E 'X|Y' (single-quoted) or grep -E "X|Y" (double-quoted)
    # where the last token before the closing quote is not a valid anchor.
    # Valid anchors: $ (end-of-line), ) (closing group),
    #                \b (two-char word-boundary — last char is 'b', preceded by '\').
    # Two-step approach: find candidate lines, then subtract valid endings.
    # The original single-regex form checked only a single char before the
    # quote; it false-positived on \b because the last char 'b' is not one
    # of '$', ')', or '\'.
    # ISS-39: lone '\' removed from valid-anchor list — a trailing backslash
    #   is not a valid grep -E anchor (incomplete escape); only '\b' is valid.
    r02_found=0
    # Single-quoted patterns (ISS-11: filter comment lines before checking)
    # ISS-16: [a-zA-Z]*E[a-zA-Z]* allows letters after E (e.g. -Eq form).
    if grep -E "grep[[:space:]]+-[a-zA-Z]*E[a-zA-Z]*[[:space:]]+'[^']*\|[^']*'" "$file" \
      | grep -v '^[[:space:]]*#' \
      | grep -v '#[[:space:]]*shell-conventions:disable=RULE-02' \
      | grep -qvE "([$)]|[\\\\]b)'"; then
      r02_found=1
    fi
    # Double-quoted patterns (ISS-11: filter comment lines before checking)
    # ISS-16: [a-zA-Z]*E[a-zA-Z]* allows letters after E (e.g. -Eq form).
    # ISS-30/ISS-38: candidate regex [^"$]*\|[^"$]*(\|[^"$]*)* excludes any
    #   line where $ appears in any quoted token. This prevents the ISS-30 FN
    #   (grep -E "foo|bar" "$file" skipped because "$file" has $). The mandatory
    #   first \| prevents flagging grep -E "foo" (no alternation) per ISS-38.
    #   Known limitation: "foo|bar$|baz" with $ anchor mid-pattern is NOT checked
    #   (ISS-45/ISS-52); a per-token parser would be needed to distinguish
    #   $ anchors from $ expansions without quote-aware parsing.
    if [[ $r02_found -eq 0 ]]; then
      if grep -E 'grep[[:space:]]+-[a-zA-Z]*E[a-zA-Z]*[[:space:]]+"[^"$]*\|[^"$]*(\|[^"$]*)*"' "$file" \
        | grep -v '^[[:space:]]*#' \
        | grep -v '#[[:space:]]*shell-conventions:disable=RULE-02' \
        | grep -qvE '([$)]|\\b)"'; then
        r02_found=1
      fi
    fi
    if [[ $r02_found -eq 1 ]]; then
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
