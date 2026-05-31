#!/usr/bin/env bash
# Project-specific shell convention linter (issue #229 Phase 1.5).
# Encodes runtime-semantics rules that shellcheck cannot catch.
#
# RULE-01  Do not use 'grep -c' in scripts with 'set -e' (errexit).
#          'grep -c' exits 1 on zero matches, triggering set -e and
#          aborting the script. 'pipefail' alone does NOT cause abort.
#          Use 'grep ... | wc -l | tr -d " "' instead.
#          Root cause: PR #228 R5→R7 — shellcheck SC2126 *recommended*
#          'grep -c' as a style improvement; that recommendation is wrong
#          for scripts that use set -e / set -o errexit.
#          Safe pattern: $(grep pattern file | wc -l | tr -d ' ')
#          If 'grep -c' is genuinely correct (e.g., protected by || true on
#          the same line), add per-file suppression with a reason comment.
#
# RULE-02  In grep -E literal-quoted patterns, '|'-delimited alternatives
#          must end with an end-of-line anchor ('$') or word-boundary ('\b')
#          before the closing quote. A lone '\' or closing ')' are NOT valid
#          anchors: ')' ends a group but does not prevent substring matches
#          (grep -E '(foo|bar)' still matches 'foo.bak'). Unanchored
#          alternatives match as substrings of longer strings.
#          Root cause: PR #228 R7→R8 — an unanchored _PLACEHOLDER_EXCLUDE
#          regex allowed 'latest_summary.md.bak' to match the exclude list
#          because it was a substring of 'latest_summary.md'.
#          NOTE: Variable-expanded patterns (grep -E "$VAR") cannot be
#          checked statically; RULE-02 only applies to literal quoted strings.
#
# Inline suppression (use sparingly; reason is required):
#   # shell-conventions:disable=RULE-NN reason: <why>
#
# Known limitations (deliberate; not bugs to fix):
#
#   KL-01  RULE-01 cannot detect 'grep -c' used safely via '&&' when '&&'
#          appears inside a quoted pattern ('foo&&bar'). Line-level grep
#          cannot distinguish shell operators from quoted text. Use || true
#          or 'if grep -c ...' instead.
#
#   KL-02  RULE-02 only checks the final alternative's anchor, not every
#          branch. 'foo|bar$|baz' (baz unanchored) is not caught when the
#          double-quoted pattern also contains a dollar sign (e.g. "$file"
#          on the same line). Per-token parsing is required; out of scope.
#
#   KL-03  RULE-02 anchor check is line-wide. A second quoted string on
#          the same line (e.g. 'other$') that happens to end with a valid
#          anchor will cause the whole line to pass even if the grep pattern
#          is unanchored. Per-token isolation is required; out of scope.
#
#   KL-04  RULE-01/02 do not cover 'git grep' which has the same exit-code
#          semantics as grep. Add suppression if needed.
#
#   KL-05  This script uses 'set -uo pipefail' without '-e'. Adding '-e'
#          requires suppressing RULE-01 on the linter's own grep calls.
#          Deferred as a separate cleanup task.
#
#   KL-06  RULE-02 candidate regex requires at least one space between the
#          '-E' flag and the quoted pattern (e.g. 'grep -E 'pat'').  This
#          misses: (a) flags between -E and the pattern ('grep -E -i 'p|q''),
#          (b) no-space invocations ('grep -E'p|q''). Per-option reordering
#          detection requires per-token parsing; out of scope. Use the
#          canonical space-separated form 'grep -E 'pattern'' to ensure
#          RULE-02 catches unanchored alternatives.
#
#   KL-07  RULE-01 _pre_grep extraction uses 'sed s/\bgrep\b...//' to strip
#          the grep invocation and everything after from the line before
#          checking guard keywords. Two limitations:
#          (a) GNU sed required: '\b' word boundary in sed is GNU-only;
#              POSIX/BSD sed does not support it. This linter targets Linux CI
#              where GNU sed is standard; BSD portability is not a goal.
#          (b) Multi-command false negative: 'grep -c foo || true; grep -c bar'
#              — sed strips from the first grep to EOL, so the line becomes
#              'grep -c foo || true; ' which passes the || guard; the second
#              unguarded grep is not detected. Per-command isolation requires
#              splitting on ';' and '&&', which is out of scope.
#
#   KL-08  'scripts/test-lint-shell-conventions.sh' with RULE-01/RULE-02 fixture
#          cases does not exist. Creating it is significant scope (positive and
#          negative fixture scripts, suppression tests, edge-case patterns).
#          The linter's wiring is tested by test.sh L899-908; the linter itself
#          does not use set -e (KL-05), so the diff-coupling gate's set-e fixture
#          requirement does not strictly apply. Tracked as a follow-up task.
#
# Usage:  bash scripts/lint-shell-conventions.sh [<path> ...]
#         Defaults to searching scripts/ directory.
# Exit:   0 = all pass; 1 = one or more violations found.

set -uo pipefail

TARGET_PATHS=("${@:-scripts/}")
VIOLATION_FILE=$(mktemp "${TMPDIR:-/tmp}/shell-linter.XXXXXX") || exit 1
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
        # ISS-55/56: guard keyword must precede grep on the line — check the pre-grep
        #   prefix only for if/elif/while/until/case/! so keywords inside quoted patterns
        #   (e.g. grep -c 'foo if bar') do not produce false negatives.
        #   '|| exit' added to the pipe-guard list (exit 0 is a safe guard).
        _pre_grep=$(printf '%s' "$grep_line" | sed 's/[[:space:]]*\bgrep\b.*//')
        if printf '%s' "$grep_line" | grep -qE '\|\|[[:space:]]*(true|echo|:|exit)'; then
          _pre_grep=
          continue
        fi
        if printf '%s' "$_pre_grep" | grep -qE '(^|[[:space:]])(if|elif|while|until|case|!)([[:space:]]|$)'; then
          _pre_grep=
          continue
        fi
        _pre_grep=
        printf 'RULE-01: %s\n' "$file"
        printf '%s\n' "VIOLATION" >>"$VIOLATION_FILE"
        break
        # ISS-55: strip inline comments then re-filter so 'cmd # grep -c' is
        #   excluded — after stripping it becomes 'cmd' with no grep invocation.
        #   Disable-comment filter runs before sed so suppression annotations
        #   aren't stripped before they're matched.
      done < <({
        grep -E '\bgrep[[:space:]]+(-[a-zA-Z]*c[a-zA-Z]*|--count)([[:space:]]|$)' "$file"
        grep -E '\bgrep[[:space:]]+-[a-zA-Z]+[[:space:]]+.*(-[a-zA-Z]*c[a-zA-Z]*|--count)([[:space:]]|$)' "$file"
        # ISS-59: also catch long-form first: grep --extended-regexp --count 'pat'
        grep -E '\bgrep[[:space:]]+--[a-zA-Z-]+[[:space:]]+.*--count([[:space:]]|$)' "$file"
      } | sort -u \
        | grep -v '^[[:space:]]*#' \
        | grep -v '#[[:space:]]*shell-conventions:disable=RULE-01' \
        | sed 's/[[:space:]]*#.*//' \
        | grep -E '\bgrep\b.*(-[a-zA-Z]*c[a-zA-Z]*|--count)' || true)
    fi
  fi

  # ── RULE-02: unanchored alternatives in grep -E literal patterns ──────────
  if ! grep -qE '#[[:space:]]*shell-conventions:disable=RULE-02' "$file"; then
    # Detect: grep -E 'X|Y' (single-quoted) or grep -E "X|Y" (double-quoted)
    # where the last token before the closing quote is not a valid anchor.
    # Valid anchors: $ (end-of-line), \b (two-char word-boundary).
    # ISS-39: lone '\' removed — incomplete escape, not a valid anchor.
    # ISS-56: ')' removed — closing group does NOT prevent substring matches.
    #   grep -E '(foo|bar)' still matches 'foo.bak'; only $ or \b anchor.
    # Two-step approach: find candidate lines, then subtract valid endings.
    r02_found=0
    # Single-quoted patterns (ISS-11: filter comment lines before checking)
    # ISS-16: [a-zA-Z]*E[a-zA-Z]* allows letters after E (e.g. -Eq form).
    # s2z4: strip inline comments before anchor check so a comment containing
    #   'grep -E 'pat|pat'' doesn't trigger a false positive.
    if grep -E "\\bgrep[[:space:]]+-[a-zA-Z]*E[a-zA-Z]*[[:space:]]+'[^']*\|[^']*'" "$file" \
      | grep -v '^[[:space:]]*#' \
      | grep -v '#[[:space:]]*shell-conventions:disable=RULE-02' \
      | sed 's/[[:space:]]*#.*//' \
      | grep -E "\\bgrep[[:space:]]+-[a-zA-Z]*E[a-zA-Z]*[[:space:]]+'[^']*\|[^']*'" \
      | grep -qvE "([$]|[\\\\]b)'"; then
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
      if grep -E '\bgrep[[:space:]]+-[a-zA-Z]*E[a-zA-Z]*[[:space:]]+"[^"$]*\|[^"$]*(\|[^"$]*)*"' "$file" \
        | grep -v '^[[:space:]]*#' \
        | grep -v '#[[:space:]]*shell-conventions:disable=RULE-02' \
        | sed 's/[[:space:]]*#.*//' \
        | grep -E '\bgrep[[:space:]]+-[a-zA-Z]*E[a-zA-Z]*[[:space:]]+"[^"$]*\|[^"$]*' \
        | grep -qvE '([$]|\\b)"'; then
        r02_found=1
      fi
    fi
    if [[ $r02_found -eq 1 ]]; then
      printf 'RULE-02: %s — grep -E pattern with "|" alternatives lacks end-anchor ($ or \\b) before closing quote\n' "$file"
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
