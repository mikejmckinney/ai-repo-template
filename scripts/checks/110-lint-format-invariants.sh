#!/usr/bin/env bash
# scripts/checks/110-lint-format-invariants.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- lint-and-format.yml invariants (issue #229 Phase 1) ---
# These assertions verify that the real lint tools stay wired up. They double as
# a canary: if a future PR removes shellcheck/shfmt/actionlint, CI fails instead
# of silently regressing.
LF_FILE=".github/workflows/lint-and-format.yml"
echo "Checking lint-and-format.yml structure (issue #229)..."
if [[ -f "$LF_FILE" ]]; then
  # Shell linter run step must be present.
  # 'shellcheck --severity' only appears in the run: block — not in comments —
  # so removing the run step (while leaving comments) would fail this check.
  if grep -qE 'shellcheck[[:space:]]+--severity' "$LF_FILE"; then
    pass "$LF_FILE has shellcheck run step"
  else
    fail "$LF_FILE missing shellcheck run step (issue #229 Phase 1)"
  fi

  # shfmt run step must be present.
  # 'shfmt -d' (diff mode) only appears in the run: block.
  if grep -qE 'shfmt[[:space:]]+-d' "$LF_FILE"; then
    pass "$LF_FILE has shfmt run step"
  else
    fail "$LF_FILE missing shfmt run step (issue #229 Phase 1)"
  fi

  # actionlint run step must be present.
  # 'xargs -r -0 actionlint' only appears in the run: block.
  if grep -qE 'xargs[[:space:]]+-r[[:space:]]+-0[[:space:]]+actionlint' "$LF_FILE"; then
    pass "$LF_FILE has actionlint run step"
  else
    fail "$LF_FILE missing actionlint run step (issue #229 Phase 1)"
  fi

  # Changed markdown collection must use null-delimited diff output so paths
  # with spaces or escapes are handled safely.
  if grep -qE '^[[:space:]]*git[[:space:]]+-c[[:space:]]+core\.quotepath=off[[:space:]]+diff[[:space:]]+.*(--name-only.*-z|-z.*--name-only)\b' "$LF_FILE"; then
    pass "$LF_FILE uses null-delimited changed-markdown collection"
  else
    fail "$LF_FILE missing null-delimited changed-markdown collection"
  fi

  # pull_request path computation must include merge-base fallback to avoid
  # linting unrelated target-branch drift.
  if grep -qE '^[[:space:]]*merge_base=.*git[[:space:]]+merge-base' "$LF_FILE" \
    && grep -qE '^[[:space:]]*base_ref=.*merge_base' "$LF_FILE"; then
    pass "$LF_FILE computes changed-markdown diff from merge-base"
  else
    fail "$LF_FILE missing merge-base changed-markdown diff guard"
  fi

  # Null-delimited output must also be consumed safely in both collection and
  # blocking lint steps. Both are strictly required: 'while' for filtering
  # paths, and 'mapfile' for passing them to markdownlint-cli2 safely.
  if grep -qE "^[[:space:]]*while[[:space:]]+IFS=.*read[[:space:]]+.*-d[[:space:]]+''" "$LF_FILE" \
    && grep -qE "^[[:space:]]*mapfile[[:space:]]+.*-d[[:space:]]+''" "$LF_FILE"; then
    pass "$LF_FILE consumes changed-markdown paths as null-delimited"
  else
    fail "$LF_FILE missing null-delimited consumers for changed-markdown paths"
  fi

  # Advisory markdownlint summary must run even when blocking lint fails.
  # Match always() inside the same step block to avoid file-wide false passes.
  if awk '
    /^[[:space:]]*- / {
      if (has_name && has_if) {
        found=1
        exit
      }
      has_name=0
      has_if=0
    }
    /^[[:space:]]*(- )?name: Markdownlint advisory repo-wide summary$/ {
      has_name=1
    }
    /^[[:space:]]*(- )?if: \$\{\{ always\(\) \}\}$/ {
      has_if=1
    }
    END {
      if (has_name && has_if) found=1
      exit(found ? 0 : 1)
    }
  ' "$LF_FILE"; then
    pass "$LF_FILE runs markdownlint advisory summary with always()"
  else
    fail "$LF_FILE missing always() guard on markdownlint advisory summary"
  fi

  if grep -qF 'python3 scripts/check-markdown-links.py' "$LF_FILE" \
    && grep -qF 'contents: read' "$LF_FILE" \
    && ! grep -qF 'contents: write' "$LF_FILE"; then
    pass "$LF_FILE validates local Markdown links without write permission"
  else
    fail "$LF_FILE must check local Markdown links and remain read-only"
  fi
else
  fail "$LF_FILE is missing"
fi

if [[ -x scripts/format.sh ]] \
  && grep -qF -- '--write' scripts/format.sh \
  && [[ -x scripts/check-markdown-links.py ]]; then
  pass "local formatting and Markdown-link entrypoints exist"
else
  fail "local formatting or Markdown-link entrypoint is missing"
fi

echo ""
