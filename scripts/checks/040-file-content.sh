#!/usr/bin/env bash
# scripts/checks/040-file-content.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- File Content Checks ---
echo "Checking file contents..."

# Check AGENTS.md references AI_REPO_GUIDE.md
if grep -q "AI_REPO_GUIDE.md" AGENTS.md 2>/dev/null; then
  pass "AGENTS.md references AI_REPO_GUIDE.md"
else
  fail "AGENTS.md should reference AI_REPO_GUIDE.md"
fi

# Check AGENTS.md has truth hierarchy
if grep -q "Truth hierarchy" AGENTS.md 2>/dev/null; then
  pass "AGENTS.md has truth hierarchy section"
else
  warn "AGENTS.md missing truth hierarchy section"
fi

# Check AGENTS.md has testing requirements (now in process_work_style.md per ADR-021)
if grep -q "Testing requirements" .context/rules/process_work_style.md 2>/dev/null; then
  pass "process_work_style.md has testing requirements section"
else
  warn "process_work_style.md missing testing requirements section"
fi

# Check PR completion criteria section exists (now in process_pr_completion.md per ADR-021; issue #206)
if grep -q "^## PR completion criteria" .context/rules/process_pr_completion.md 2>/dev/null; then
  pass "process_pr_completion.md has PR completion criteria section"
else
  warn "process_pr_completion.md missing PR completion criteria section"
fi

# Check thin AGENTS.md links to per-concern process_*.md files (ADR-021).
# Rationale: hard-coded contract assertion per repo convention. Limitation: regex
# matches standard markdown link syntax `[label](file)`; assumes no nested parens.
# Scope is restricted to the "Per-concern process rules" section so an unrelated
# pointer link elsewhere in the file (e.g. the Section-anchor redirects table)
# can't mask a missing table row. Reported by codex on PR #264 R5.
CORE_RULE_FILES=(
  "process_template_detection.md" "process_critical_thinking.md" "process_work_style.md"
  "process_clarification.md" "process_role_selection.md" "process_gates.md"
  "process_session_state.md" "process_pr_completion.md" "process_model_tier.md"
  "process_subagent_bootstrap.md"
  "process_doc_maintenance.md" "domain_code_quality.md" "repo_orchestration_patterns.md"
  "agent_ownership.md"
)
# Extract markdown table rows (lines starting with '|') from the
# "Per-concern process rules" section. Restricting to table rows guards
# against false-pass from prose mentions of the same filename within the
# section (reported by codex on PR #264 R6).
# Limitation: awk's range pattern terminates at the next '## ' header.
# This is robust as long as AGENTS.md keeps the table inside its own
# section. If a contributor inserts non-table content (e.g., another
# table) between the section header and the link table, the filter could
# include extra rows; the regex below still requires the canonical
# `.context/rules/<file>.md` link target so unrelated rows wouldn't
# false-match. Documented per repo "document simplification" rule
# (Gemini, R10).
LINK_TABLE_BLOCK=""
if [[ -f "AGENTS.md" ]]; then
  LINK_TABLE_BLOCK=$(awk '/^## Per-concern process rules/{flag=1; next} /^## /{flag=0} flag && /^\|/' AGENTS.md)
fi
MISSING_LINKS=0
for pfile in "${CORE_RULE_FILES[@]}"; do
  # Escape regex metachars (notably '.') in filename for grep -E.
  pfile_re=${pfile//./\\.}
  # Require the canonical link target `.context/rules/<file>.md` exactly,
  # optionally followed by '#anchor', then ')'. The leading '.context/rules/'
  # prefix prevents wrong-directory false-positives like `docs/process_X.md`
  # (Codex, R9). The trailing terminator prevents suffix typos like '.mdx'
  # (Codex, R7). Together they pin the regex to the exact canonical paths
  # used in the link table.
  if ! printf '%s\n' "$LINK_TABLE_BLOCK" | grep -qE "\[[^]]*\]\(\.context/rules/${pfile_re}(#[^)]*)?\)" 2>/dev/null; then
    fail "AGENTS.md missing link table entry for $pfile (ADR-021)"
    MISSING_LINKS=$((MISSING_LINKS + 1))
  fi
done
if [[ $MISSING_LINKS -eq 0 ]]; then
  pass "AGENTS.md link table references all core process files (ADR-021)"
fi

# Check agent-review-on-push.yml has required invariants (issue #205)
# Patterns are tightened to match exact YAML structure / API surface so the
# checks don't false-pass on the same keyword appearing in a comment block.
# Reported by copilot-pull-request-reviewer on PR #217.
#
# Policy on regex tightness (PR #217 rounds 3-4 retrospective):
# This block validates the SHAPE of a workflow file we author and own.
# It is NOT validating user-supplied input. Strict regexes act as a
# low-fidelity formatter — they keep `agent-review-on-push.yml` in a
# consistent canonical form and surface drift fast. We deliberately
# DO NOT relax patterns to accept every YAML-legal alternate form
# (single vs double quotes around `'true'`, zero-or-one space after a
# colon, single-line flow-style permissions blocks, whitespace inside
# `gh api graphql -f query='...'` strings, etc.). Those variants are
# valid YAML / valid bash, but nothing in this repo's toolchain emits
# them, so any test failure caused by such a reformat is a signal worth
# inspecting (~30 sec to re-tighten or update the test). Tolerance
# fixes ARE applied where the tradeoff genuinely tips the other way:
#   - POSIX portability (awk replaces grep -Pzo for BSD/macOS)
#   - Real semantic ambiguity (gemini-then-copilot vs copilot-then-gemini)
#   - Anchoring to executable lines, not just any occurrence in the file
# Gemini Code Assist is configured (in .gemini/styleguide.md) to skip
# stylistic-quote-and-whitespace nits on this file; if it flags one
# anyway, defer with a reply pointing at this comment.
RP_FILE=".github/workflows/agent-review-on-push.yml"
if [[ -f "$RP_FILE" ]]; then
  # Allow either single-line `types: [synchronize]` or multi-line list form
  # (`types:` followed by `- synchronize`). YAML accepts both; both are
  # idiomatic and a contributor may legitimately choose either. Implementation
  # uses awk (POSIX) instead of `grep -Pzo` so the test runs on macOS / BSD
  # grep too — `-P` and `-z` are GNU extensions. Reported by
  # gemini-code-assist and chatgpt-codex-connector on PR #217.
  if grep -qE '^[[:space:]]+types:[[:space:]]*\[[[:space:]]*synchronize[[:space:]]*\]' "$RP_FILE" \
    || awk '
            /^[[:space:]]+types:[[:space:]]*$/ { in_block = 1; next }
            in_block && /^[[:space:]]*#/ { next }
            in_block && /^[[:space:]]+-[[:space:]]+synchronize([[:space:]]|$)/ { found = 1; exit }
            in_block && /^[[:space:]]*[^[:space:]#-]/ { in_block = 0 }
            END { exit !found }
         ' "$RP_FILE"; then
    pass "agent-review-on-push.yml triggers on pull_request synchronize (single- or multi-line list)"
  else
    fail "agent-review-on-push.yml missing 'synchronize' under pull_request types"
  fi
  if grep -qE "^[[:space:]]+cancel-in-progress:[[:space:]]+true[[:space:]]*\$" "$RP_FILE"; then
    pass "agent-review-on-push.yml has concurrency cancel-in-progress: true"
  else
    fail "agent-review-on-push.yml missing 'cancel-in-progress: true'"
  fi
  if grep -qE "vars\.REVIEW_ON_PUSH[[:space:]]*!=[[:space:]]*'false'" "$RP_FILE"; then
    pass "agent-review-on-push.yml gated on vars.REVIEW_ON_PUSH != 'false' (opt-out default)"
  else
    fail "agent-review-on-push.yml missing REVIEW_ON_PUSH opt-out gate (vars.REVIEW_ON_PUSH != 'false')"
  fi
  # Implementation switched (a third time) to the only mechanism that
  # actually fires: GraphQL `requestReviewsByLogin` with `botLogins:
  # ["copilot-pull-request-reviewer[bot]"]`. Earlier attempts: REST
  # `requested_reviewers` 422s on bare bot login; REST with friendly
  # aliases silently no-ops (HTTP 200, empty result); `requestReviews`
  # with Bot node ID rejects "Could not resolve to User node" because
  # its `userIds` field is User-only. Mechanism confirmed by reading
  # cli/cli source. The `[bot]` suffix is REQUIRED.
  #
  # Anchor to the actual `gh api graphql -f query=...` line and the
  # `-f bots=...` argument so the invariant doesn't false-pass on
  # comment text alone. Reported by chatgpt-codex-connector on PR #217.
  if grep -qE 'requestReviewsByLogin\(input:\{pullRequestId:' "$RP_FILE" \
    && grep -qE "^[[:space:]]+-f bots='copilot-pull-request-reviewer\[bot\]'[[:space:]]*\$" "$RP_FILE"; then
    pass "agent-review-on-push.yml re-requests Copilot via GraphQL requestReviewsByLogin + suffixed bot login (executable line, not comment)"
  else
    fail "agent-review-on-push.yml missing executable requestReviewsByLogin mutation call or '-f bots=...[bot]' argument"
  fi
  if grep -qE "body='/gemini review'" "$RP_FILE"; then
    pass "agent-review-on-push.yml posts -f body='/gemini review' to comments API"
  else
    fail "agent-review-on-push.yml missing -f body='/gemini review' comment"
  fi
  if grep -qE "^[[:space:]]+issues:[[:space:]]+write" "$RP_FILE"; then
    pass "agent-review-on-push.yml grants issues: write (required for /gemini review comment)"
  else
    fail "agent-review-on-push.yml missing 'issues: write' permission for issue-comments API"
  fi
  # Verify the actual conditional logic (both outcomes failure-AND-ed),
  # not just that the strings appear somewhere in the file. Tolerate
  # either order (gemini-then-copilot or copilot-then-gemini) — a
  # refactor may legitimately swap them. Reported by gemini-code-assist
  # on PR #217.
  if grep -qE "steps\.gemini\.outcome[[:space:]]*==[[:space:]]*'failure'[[:space:]]*&&[[:space:]]*steps\.copilot\.outcome[[:space:]]*==[[:space:]]*'failure'" "$RP_FILE" \
    || grep -qE "steps\.copilot\.outcome[[:space:]]*==[[:space:]]*'failure'[[:space:]]*&&[[:space:]]*steps\.gemini\.outcome[[:space:]]*==[[:space:]]*'failure'" "$RP_FILE"; then
    pass "agent-review-on-push.yml fails job when BOTH nudges fail (verified gate logic, either order)"
  else
    fail "agent-review-on-push.yml missing both-failed conditional gate (steps.gemini.outcome AND steps.copilot.outcome failure check)"
  fi
  if grep -qE 'GH_TOKEN:[[:space:]]+\$\{\{[[:space:]]*secrets\.CLAUDE_PAT[[:space:]]*\}\}' "$RP_FILE"; then
    pass "agent-review-on-push.yml posts /gemini review under CLAUDE_PAT (real user identity)"
  else
    fail "agent-review-on-push.yml Gemini step missing CLAUDE_PAT (Gemini ignores bot-authored slash commands)"
  fi
  if grep -qE '^[[:space:]]+- name: Verify required secrets' "$RP_FILE"; then
    pass "agent-review-on-push.yml has 'Verify required secrets' guard step"
  else
    fail "agent-review-on-push.yml missing secrets-guard step (CLAUDE_PAT could silently be empty)"
  fi
fi

# Check agent-pipeline.md documents REVIEW_ON_PUSH knob
if grep -q "REVIEW_ON_PUSH" docs/guides/agent-pipeline.md 2>/dev/null; then
  pass "agent-pipeline.md documents REVIEW_ON_PUSH"
else
  fail "agent-pipeline.md should document REVIEW_ON_PUSH knob"
fi

# Check AGENTS.md has versioned session handshake (read-receipt canary)
if grep -qE '^<!-- AGENTS_MD_VERSION: [0-9]+ -->' AGENTS.md 2>/dev/null; then
  pass "AGENTS.md has AGENTS_MD_VERSION marker"
else
  fail "AGENTS.md missing AGENTS_MD_VERSION marker (handshake canary)"
fi

if grep -q "Session handshake" AGENTS.md 2>/dev/null \
  && (grep -qE 'Session handshake vAGENTS_MD_VERSION' AGENTS.md 2>/dev/null \
    || grep -qE 'Session handshake v?[0-9]+' AGENTS.md 2>/dev/null); then
  pass "AGENTS.md has Session handshake instruction with token placeholder or legacy literal"
else
  fail "AGENTS.md missing Session handshake instruction or token"
fi

# Verify the handshake token either defers to AGENTS_MD_VERSION via the
# template placeholder or (legacy form) embeds a matching literal version.
agents_md_version=$(grep -oE '^<!-- AGENTS_MD_VERSION: [0-9]+ -->' AGENTS.md 2>/dev/null | grep -oE '[0-9]+' | head -1)
handshake_version=$(grep -oE 'Session handshake v?[0-9]+' AGENTS.md 2>/dev/null | grep -oE '[0-9]+' | head -1)
if grep -qE 'Session handshake vAGENTS_MD_VERSION' AGENTS.md 2>/dev/null; then
  pass "AGENTS.md handshake token defers to AGENTS_MD_VERSION placeholder ($agents_md_version)"
elif [ -n "$agents_md_version" ] && [ "$agents_md_version" = "$handshake_version" ]; then
  pass "AGENTS.md handshake token version matches AGENTS_MD_VERSION ($agents_md_version)"
else
  fail "AGENTS.md handshake token does not align with AGENTS_MD_VERSION ($agents_md_version)"
fi

# Check install.sh is executable or has shebang
if head -1 install.sh | grep -q "^#!/bin/bash"; then
  pass "install.sh has bash shebang"
else
  fail "install.sh missing bash shebang"
fi

# Check install.sh documents the legacy $DOTFILES variable (Codespaces convention).
# Two loose substring matches: the file must mention both "$DOTFILES variable"
# and "Codespaces". Using separate greps (instead of an exact header-line
# match) keeps the assertion robust to cosmetic rewording of the comment.
# shellcheck disable=SC2016  # `\$DOTFILES` is a literal we're grepping for in install.sh
if grep -q '\$DOTFILES variable' install.sh && grep -q 'Codespaces' install.sh; then
  pass "install.sh has \$DOTFILES legacy-convention comment block"
else
  fail "install.sh missing \$DOTFILES legacy-convention comment block"
fi

# Guard against "Dotfiles" log strings resurfacing in install.sh user-facing
# output (we rewrote these to "Template" during the ai-repo-template rebrand).
# The variable $DOTFILES (all-caps) and comment-block mentions are fine; any
# log/echo message whose quoted string *contains* "Dotfiles" (mixed case) is
# a regression — even with a leading emoji/whitespace, and regardless of
# single vs double quotes. Case-sensitive grep means `"Template: $DOTFILES"`
# is correctly ignored because the pattern is `Dotfiles`, not `DOTFILES`.
# shell-conventions:disable=RULE-02 reason: alternation is on a complete function-name list followed by mandatory whitespace+quote, no substring-match risk
if grep -E "(log_info|log_warn|log_error|echo)\b[[:space:]]+[\"'][^\"']*Dotfiles" install.sh >/dev/null; then
  fail "install.sh contains \"Dotfiles\" log strings (should be \"Template\")"
else
  pass "install.sh has no \"Dotfiles\" log strings (rebrand intact)"
fi

# Check judge.agent.md has required sections
if grep -q "PLAN-GATE" .github/agents/judge.agent.md 2>/dev/null; then
  pass "judge.agent.md has PLAN-GATE section"
else
  warn "judge.agent.md missing PLAN-GATE section"
fi

if grep -q "DIFF-GATE" .github/agents/judge.agent.md 2>/dev/null; then
  pass "judge.agent.md has DIFF-GATE section"
else
  warn "judge.agent.md missing DIFF-GATE section"
fi

# Check for contentReference artifacts (should not be present)
if grep -q -E "contentReference|oaicite" .github/agents/judge.agent.md 2>/dev/null; then
  fail "judge.agent.md contains contentReference artifacts (clean these up)"
else
  pass "judge.agent.md is clean of artifacts"
fi
