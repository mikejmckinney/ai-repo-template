#!/bin/bash
# Template verification script
# Ensures all required files exist and are properly formatted

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PASS=0
FAIL=0
WARN=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    FAIL=$((FAIL + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARN=$((WARN + 1))
}

echo "========================================"
echo "Template Repository Verification"
echo "========================================"
echo ""

# --- Required Files Check ---
echo "Checking required files..."

REQUIRED_FILES=(
    "AI_REPO_GUIDE.md"
    "AGENTS.md"
    "AGENT.md"
    "CLAUDE.md"
    "README.md"
    "install.sh"
    ".cursor/BUGBOT.md"
    ".gemini/styleguide.md"
    ".gemini/config.yaml"
    ".github/copilot-instructions.md"
    ".github/agents/judge.agent.md"
    ".github/agents/critic.agent.md"
    ".github/agents/architect.agent.md"
    ".github/agents/pm.agent.md"
    ".github/agents/frontend.agent.md"
    ".github/agents/backend.agent.md"
    ".github/agents/qa.agent.md"
    ".github/agents/devops.agent.md"
    ".github/agents/docs.agent.md"
    ".github/agents/analyst.agent.md"
    ".claude/agents/architect.md"
    ".claude/agents/judge.md"
    ".claude/agents/critic.md"
    ".claude/agents/pm.md"
    ".claude/agents/frontend.md"
    ".claude/agents/backend.md"
    ".claude/agents/qa.md"
    ".claude/agents/devops.md"
    ".claude/agents/docs.md"
    ".claude/agents/analyst.md"
    ".github/prompts/README.md"
    ".github/prompts/repo-onboarding.md"
    ".github/prompts/pr-resolve-all.md"
    ".github/prompts/expand-backlog-entry.md"
    ".github/prompts/capture-postmortem.md"
    ".github/prompts/mirror-postmortem.md"
    ".github/pull_request_template.md"
    ".github/PLAN_TEMPLATE.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        pass "$file exists"
    else
        fail "$file is missing"
    fi
done

echo ""

# --- Context Pack Check ---
echo "Checking context pack structure..."

CONTEXT_FILES=(
    ".context/00_INDEX.md"
    ".context/backlog.yaml"
    ".context/backlog.schema.json"
    ".context/roadmap.md"
    ".context/rules/README.md"
    ".context/rules/agent_ownership.md"
    ".context/rules/domain_code_quality.md"
    ".context/rules/process_doc_maintenance.md"
    ".context/sessions/README.md"
    ".context/sessions/latest_summary.md"
    ".context/state/README.md"
    ".context/state/_active.md"
    ".context/state/coordination.md"
    ".context/state/task_template.md"
    ".context/state/handoff_template.md"
    ".context/state/feedback_template.md"
    ".context/vision/README.md"
)

for file in "${CONTEXT_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        pass "$file exists"
    else
        fail "$file is missing"
    fi
done

# Check context directories exist
CONTEXT_DIRS=(
    ".context/rules"
    ".context/sessions"
    ".context/state"
    ".context/vision/mockups"
    ".context/vision/architecture"
)

for dir in "${CONTEXT_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        pass "$dir directory exists"
    else
        fail "$dir directory is missing"
    fi
done

echo ""

# --- Docs Structure Check ---
echo "Checking docs structure..."

DOCS_FILES=(
    "docs/README.md"
    "docs/FAQ.md"
    "docs/smoke-a.md"
    "docs/smoke-e.md"
    "docs/guides/agent-best-practices.md"
    "docs/guides/agent-pipeline.md"
    "docs/guides/context-files-explained.md"
    "docs/guides/multi-agent-coordination.md"
    "docs/guides/optional-skills.md"
    "docs/decisions/adr-template.md"
    "docs/decisions/README.md"
    "docs/decisions/adr-001-context-pack-structure.md"
    "docs/decisions/adr-002-agents-md-ownership.md"
    "docs/decisions/adr-003-claude-code-subagent-registration.md"
    "docs/decisions/adr-004-analyst-role-and-feedback-loop.md"
    "docs/decisions/adr-005-analyst-preflight-gate.md"
    "docs/decisions/adr-006-auto-merge-opt-in-model.md"
    "docs/decisions/adr-007-auto-resolve-review-threads.md"
    "docs/decisions/adr-008-phase4-default-and-copilot-fallback.md"
    "docs/decisions/adr-009-parallel-multi-agent-execution.md"
    "docs/decisions/adr-010-auto-rebase-on-merge.md"
    "docs/decisions/adr-011-plan-as-comment-requirement.md"
    "docs/decisions/adr-015-postmortem-feedback-loop.md"
    "docs/postmortems/README.md"
    "docs/postmortems/postmortem-template.md"
    "docs/postmortems/postmortem-001-workflow-bypass.md"
    "docs/postmortems/postmortem-002-poc-outcome-mismatch.md"
)

for file in "${DOCS_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        pass "$file exists"
    else
        fail "$file is missing"
    fi
done

DOCS_DIRS=(
    "docs/reference"
    "docs/research"
    "docs/guides"
    "docs/decisions"
    "docs/postmortems"
)

for dir in "${DOCS_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        pass "$dir directory exists"
    else
        fail "$dir directory is missing"
    fi
done

echo ""

# --- Workflow Files Check ---
echo "Checking workflow files..."

WORKFLOW_FILES=(
    ".github/workflows/agent-assign-copilot.yml"
    ".github/workflows/agent-auto-merge.yml"
    ".github/workflows/agent-auto-ready.yml"
    ".github/workflows/agent-coordination-sync.yml"
    ".github/workflows/agent-fix-reviews.yml"
    ".github/workflows/agent-heartbeat.yml.template"
    ".github/workflows/agent-multi-dispatch.yml"
    ".github/workflows/agent-parallelism-report.yml"
    ".github/workflows/agent-relay-reviews.yml"
    ".github/workflows/agent-release-slot.yml"
    ".github/workflows/agent-review-on-push.yml"
    ".github/workflows/auto-rebase-on-merge.yml"
    ".github/workflows/backlog-to-issues.yml"
    ".github/workflows/ci-tests.yml"
    ".github/workflows/claude.yml"
    ".github/workflows/keep-warm.yml"
    ".github/workflows/lint-and-format.yml"
    ".github/workflows/validate-connections.yml"
)

for file in "${WORKFLOW_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        pass "$file exists"
    else
        fail "$file is missing"
    fi
done

echo ""

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

# Check AGENTS.md has testing requirements
if grep -q "Testing requirements" AGENTS.md 2>/dev/null; then
    pass "AGENTS.md has testing requirements section"
else
    warn "AGENTS.md missing testing requirements section"
fi

# Check AGENTS.md has PR completion criteria section (issue #206)
if grep -q "^## PR completion criteria" AGENTS.md 2>/dev/null; then
    pass "AGENTS.md has PR completion criteria section"
else
    warn "AGENTS.md missing PR completion criteria section"
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
    if grep -qE "vars\.REVIEW_ON_PUSH[[:space:]]*==[[:space:]]*'true'" "$RP_FILE"; then
        pass "agent-review-on-push.yml gated on vars.REVIEW_ON_PUSH == 'true'"
    else
        fail "agent-review-on-push.yml missing exact REVIEW_ON_PUSH opt-in gate"
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
   && grep -qE 'Session handshake v[0-9]+' AGENTS.md 2>/dev/null; then
    pass "AGENTS.md has Session handshake instruction with token"
else
    fail "AGENTS.md missing Session handshake instruction or token"
fi

# Verify the version inside the handshake token matches AGENTS_MD_VERSION
agents_md_version=$(grep -oE '^<!-- AGENTS_MD_VERSION: [0-9]+ -->' AGENTS.md 2>/dev/null | grep -oE '[0-9]+' | head -1)
handshake_version=$(grep -oE 'Session handshake v[0-9]+' AGENTS.md 2>/dev/null | grep -oE '[0-9]+' | head -1)
if [ -n "$agents_md_version" ] && [ "$agents_md_version" = "$handshake_version" ]; then
    pass "AGENTS.md handshake token version matches AGENTS_MD_VERSION ($agents_md_version)"
else
    fail "AGENTS.md handshake token (v$handshake_version) does not match AGENTS_MD_VERSION ($agents_md_version) — bump both together"
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
if grep -E "(log_info|log_warn|log_error|echo)[[:space:]]+[\"'][^\"']*Dotfiles" install.sh > /dev/null; then
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

# --- Pre-flight gate extension (ADR-014) ---
# Four invariants ensure the broadened Pre-Flight gate stays wired up
# end-to-end. See ADR-014.
#
#   1. The outcome-validated opt-out label is declared in setup.sh so a
#      fresh `bash scripts/setup.sh` run creates it on the target repo.
#   2. ADR-014 exists with the expected Status line.
#   3. ADR-005's Status line marks partial supersession by ADR-014, so the
#      supersession trail is one grep away (per docs/decisions/README.md
#      "Supersession discipline").
#   4. AGENTS.md names the opt-out label literally inside the "Analyst
#      pre-flight gate" section, so the trigger condition is documented
#      where agents read it.
ADR014_PATH="docs/decisions/adr-014-extend-preflight-to-adhoc-deliverables.md"

if grep -q '_ensure_label "outcome-validated"' scripts/setup.sh 2>/dev/null; then
    pass "scripts/setup.sh declares the outcome-validated label (ADR-014)"
else
    fail "scripts/setup.sh missing _ensure_label \"outcome-validated\" (ADR-014)"
fi

if [[ -f "$ADR014_PATH" ]] \
    && grep -qE '^Accepted$' "$ADR014_PATH" 2>/dev/null; then
    pass "ADR-014 exists with Status: Accepted"
else
    fail "ADR-014 missing or Status line is not 'Accepted' ($ADR014_PATH)"
fi

if grep -q 'superseded in part by ADR-014' docs/decisions/adr-005-analyst-preflight-gate.md 2>/dev/null; then
    pass "ADR-005 Status line marks partial supersession by ADR-014"
else
    fail "ADR-005 Status line missing 'superseded in part by ADR-014' (supersession discipline)"
fi

# Extract the "Analyst pre-flight gate" subsection from AGENTS.md (between
# its H3 heading and the next H3) and confirm it mentions the opt-out label
# literally. awk range pattern: print from the first marker through the
# second marker (inclusive of both matching heading lines).
gate_section=$(awk '/^### Analyst pre-flight gate/,/^### Plan-as-comment requirement/' AGENTS.md 2>/dev/null)
if printf '%s' "$gate_section" | grep -q 'outcome-validated'; then
    pass "AGENTS.md \"Analyst pre-flight gate\" section names outcome-validated (ADR-014)"
else
    fail "AGENTS.md \"Analyst pre-flight gate\" section does not mention outcome-validated (ADR-014)"
fi

# Check context 00_INDEX.md has truth hierarchy
if grep -q "priority" .context/00_INDEX.md 2>/dev/null; then
    pass ".context/00_INDEX.md has priority information"
else
    warn ".context/00_INDEX.md missing priority information"
fi

# Validate backlog.yaml against its schema (requires check-jsonschema)
if command -v check-jsonschema &>/dev/null; then
    if check-jsonschema --schemafile .context/backlog.schema.json .context/backlog.yaml 2>/dev/null; then
        pass "backlog.yaml validates against backlog.schema.json"
    else
        fail "backlog.yaml failed schema validation against backlog.schema.json"
    fi
else
    warn "check-jsonschema not installed; skipping backlog.yaml schema validation (run: pip install check-jsonschema)"
fi

# Check README.md has Limitations, Future Improvements, and FAQ sections.
# These are required for the template itself and derived projects are
# instructed (by .github/ISSUE_TEMPLATE/agent_init.md) to preserve them.
# Header matching is case-insensitive: `## Limitations` and `## limitations`
# both pass. The assertion is that the section exists, not that contributors
# memorized the canonical casing. See postmortem-001 + ADR-013.
if grep -qi "^## Limitations" README.md 2>/dev/null; then
    pass "README.md has Limitations section"
else
    fail "README.md missing ## Limitations section (case-insensitive)"
fi

if grep -qi "^## Future Improvements" README.md 2>/dev/null; then
    pass "README.md has Future Improvements section"
else
    fail "README.md missing ## Future Improvements section (case-insensitive)"
fi

if grep -qi "^## FAQ" README.md 2>/dev/null; then
    pass "README.md has FAQ section"
else
    fail "README.md missing ## FAQ section (case-insensitive)"
fi

# FAQ section in README may link to docs/FAQ.md or keep content inline — both are valid.
if [ -f "docs/FAQ.md" ]; then
    if grep -q "docs/FAQ.md" README.md 2>/dev/null; then
        pass "README.md links to docs/FAQ.md"
    else
        warn "docs/FAQ.md exists but README.md does not link to it"
    fi
else
    pass "README.md keeps FAQ content inline (docs/FAQ.md not present)"
fi

echo ""

# --- Agent Mirror Sanity Checks ---
# The template ships two parallel agent registries so both Copilot's custom-
# agent runtime and Claude Code's native subagent loader dispatch on the same
# 9 roles. Canonical role files live in .github/agents/<role>.agent.md
# (Copilot schema); Claude Code mirrors live in .claude/agents/<role>.md
# (Claude Code schema). See docs/decisions/adr-002-claude-code-subagent-
# registration.md for rationale.
echo "Checking .claude/agents mirror of .github/agents..."

# Check A: every canonical .github/agents/*.agent.md has a matching
# .claude/agents/*.md mirror. This prevents future role additions from
# silently skipping Claude Code registration.
for gh_file in .github/agents/*.agent.md; do
    [[ -f "$gh_file" ]] || continue
    role="$(basename "$gh_file" .agent.md)"
    claude_file=".claude/agents/${role}.md"
    if [[ -f "$claude_file" ]]; then
        pass "$claude_file mirrors $gh_file"
    else
        fail "$claude_file is missing (every .github/agents/<role>.agent.md needs a .claude/agents/<role>.md mirror)"
    fi
done

# Check B: description: frontmatter line must be byte-identical between the
# two copies for every role, so Copilot SDK intent-matching and Claude Code
# auto-dispatch route on the same string. Drift is a hard failure.
for gh_file in .github/agents/*.agent.md; do
    [[ -f "$gh_file" ]] || continue
    role="$(basename "$gh_file" .agent.md)"
    claude_file=".claude/agents/${role}.md"
    [[ -f "$claude_file" ]] || continue  # Check A already flagged this
    gh_desc="$(grep -m1 '^description:' "$gh_file" || true)"
    cc_desc="$(grep -m1 '^description:' "$claude_file" || true)"
    if [[ -n "$gh_desc" && "$gh_desc" == "$cc_desc" ]]; then
        pass "$role description: matches between .github and .claude"
    else
        fail "$role description: differs between $gh_file and $claude_file"
    fi
done

echo ""

# --- Script Syntax Check ---
echo "Checking script syntax..."

if bash -n install.sh 2>/dev/null; then
    pass "install.sh has valid bash syntax"
else
    fail "install.sh has syntax errors"
fi

if bash -n test.sh 2>/dev/null; then
    pass "test.sh has valid bash syntax"
else
    fail "test.sh has syntax errors"
fi

echo ""

# --- Markdown Structure Checks ---
echo "Checking markdown structure..."

# Check that key files have headers
for file in AI_REPO_GUIDE.md AGENTS.md README.md .context/00_INDEX.md; do
    if [[ -f "$file" ]] && head -5 "$file" | grep -q "^#"; then
        pass "$file has a header"
    else
        warn "$file missing header"
    fi
done

echo ""

# --- YAML Syntax Check ---
echo "Checking workflow YAML syntax..."

# Basic YAML check (just verifies files aren't completely broken)
for file in .github/workflows/*.yml; do
    if [[ -f "$file" ]]; then
        # Check for common YAML issues
        if head -1 "$file" | grep -qE "^(name:|#)"; then
            pass "$file has valid YAML header"
        else
            warn "$file may have YAML issues"
        fi
    fi
done

echo ""

# --- Phase 4 fallback parser unit tests (issue #108 regression cover) ---
echo "Running Phase 4 fallback parser unit tests..."
if [[ -f scripts/test-phase4-fallback-parser.sh ]]; then
    PARSER_LOG=$(mktemp)
    if bash scripts/test-phase4-fallback-parser.sh > "$PARSER_LOG" 2>&1; then
        parser_passed=$(grep -c '^  ✅ ' "$PARSER_LOG" || true)
        pass "scripts/test-phase4-fallback-parser.sh ($parser_passed assertions passed)"
    else
        fail "scripts/test-phase4-fallback-parser.sh failed (see log below)"
        cat "$PARSER_LOG"
    fi
    rm -f "$PARSER_LOG"
else
    fail "scripts/test-phase4-fallback-parser.sh missing"
fi

echo ""

# --- Parallelism report parser unit tests (issue #49 / ADR-009) ---
# Includes a live-format assertion against agent_ownership.md so that
# format-changing PRs to the ownership table fail CI at the change PR
# rather than at the next overlap report.
echo "Running parallelism report parser unit tests..."
if [[ -f scripts/test-parallelism-report-parser.sh ]]; then
    PR_PARSER_LOG=$(mktemp)
    if bash scripts/test-parallelism-report-parser.sh > "$PR_PARSER_LOG" 2>&1; then
        pr_parser_passed=$(grep -c '^  ✅ ' "$PR_PARSER_LOG" || true)
        pass "scripts/test-parallelism-report-parser.sh ($pr_parser_passed assertions passed)"
    else
        fail "scripts/test-parallelism-report-parser.sh failed (see log below)"
        cat "$PR_PARSER_LOG"
    fi
    rm -f "$PR_PARSER_LOG"
else
    fail "scripts/test-parallelism-report-parser.sh missing"
fi

echo ""

# --- Coordination sync awk pipeline unit tests (issue #115) ---
# Includes a live-format assertion against .context/state/coordination.md
# so that PRs which restructure the lock template trip CI at the change
# rather than turning the workflow into a silent no-op.
echo "Running coordination sync parser unit tests..."
if [[ -f scripts/test-coordination-sync.sh ]]; then
    CS_LOG=$(mktemp)
    if bash scripts/test-coordination-sync.sh > "$CS_LOG" 2>&1; then
        cs_passed=$(grep -c '^  ✅ ' "$CS_LOG" || true)
        pass "scripts/test-coordination-sync.sh ($cs_passed assertions passed)"
    else
        fail "scripts/test-coordination-sync.sh failed (see log below)"
        cat "$CS_LOG"
    fi
    rm -f "$CS_LOG"
else
    fail "scripts/test-coordination-sync.sh missing"
fi

echo ""

# --- Multi-dispatch safety library unit tests (issue #114) ---
# Exercises the four pure-bash functions in
# scripts/multi-dispatch-safety.sh that the multi-issue dispatcher
# (.github/workflows/agent-multi-dispatch.yml) relies on for conflict
# detection. If these regress, the dispatcher would silently assign
# Copilot to overlapping issues. Hard-fail keeps regressions out of CI.
echo "Running multi-dispatch safety unit tests..."
if [[ -f scripts/test-multi-dispatch-safety.sh ]]; then
    MDS_LOG=$(mktemp)
    if bash scripts/test-multi-dispatch-safety.sh > "$MDS_LOG" 2>&1; then
        mds_passed=$(grep -c '^  ✅ ' "$MDS_LOG" || true)
        pass "scripts/test-multi-dispatch-safety.sh ($mds_passed assertions passed)"
    else
        fail "scripts/test-multi-dispatch-safety.sh failed (see log below)"
        cat "$MDS_LOG"
    fi
    rm -f "$MDS_LOG"
else
    fail "scripts/test-multi-dispatch-safety.sh missing"
fi

echo ""

# --- Auto-rebase-on-merge Library Tests (#116) ---
# Exercises the library used by .github/workflows/auto-rebase-on-merge.yml
# (should_rebase_pr / attempt_rebase / format_*_comment). If these
# regress, the workflow could force-push to PRs it shouldn't or fail to
# act on PRs it should. Hard-fail keeps regressions out of CI.
echo "Running auto-rebase-on-merge unit tests..."
if [[ -f scripts/test-auto-rebase-overlapping.sh ]]; then
    ARO_LOG=$(mktemp)
    if bash scripts/test-auto-rebase-overlapping.sh > "$ARO_LOG" 2>&1; then
        aro_passed=$(grep -c '^  ✅ ' "$ARO_LOG" || true)
        pass "scripts/test-auto-rebase-overlapping.sh ($aro_passed assertions passed)"
    else
        fail "scripts/test-auto-rebase-overlapping.sh failed (see log below)"
        cat "$ARO_LOG"
    fi
    rm -f "$ARO_LOG"
else
    fail "scripts/test-auto-rebase-overlapping.sh missing"
fi

echo ""

# --- Issue Templates Check ---
echo "Checking issue templates..."

ISSUE_TEMPLATES=(
    ".github/ISSUE_TEMPLATE/bug_report.md"
    ".github/ISSUE_TEMPLATE/feature_request.md"
    ".github/ISSUE_TEMPLATE/agent_init.md"
    ".github/ISSUE_TEMPLATE/config.yml"
)

for file in "${ISSUE_TEMPLATES[@]}"; do
    if [[ -f "$file" ]]; then
        pass "$file exists"
    else
        fail "$file is missing"
    fi
done

echo ""

# --- Config Templates Check ---
echo "Checking config templates..."

CONFIG_FILES=(
    "config/README.md"
    "config/vercel.json.template"
    "config/railway.toml.template"
    "config/render.yaml.template"
    "config/docker-compose.yml.template"
    ".pre-commit-config.yaml.template"
    ".cursorignore"
)

for file in "${CONFIG_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        pass "$file exists"
    else
        fail "$file is missing"
    fi
done

echo ""

# --- Scripts Check ---
echo "Checking scripts..."

SCRIPT_FILES=(
    "scripts/README.md"
    "scripts/setup.sh"
    "scripts/verify-env.sh"
    "scripts/db-reset.sh"
    "scripts/auto-rebase-overlapping.sh"
    "scripts/multi-dispatch-safety.sh"
    "scripts/parse-ownership-table.sh"
)

for file in "${SCRIPT_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        pass "$file exists"
    else
        fail "$file is missing"
    fi
done

# Check scripts are executable
for script in scripts/*.sh; do
    [ -f "$script" ] || continue
    if [[ -x "$script" ]]; then
        pass "$script is executable"
    else
        warn "$script is not executable"
    fi
done

echo ""

# --- Workflow Secret Guard Check (issue #162) ---
# Every workflow that references secrets.CLAUDE_PAT or
# secrets.ANTHROPIC_API_KEY must contain a "Verify required secrets"
# step so derived repos missing those secrets get an actionable error
# instead of an obscure `gh: set GH_TOKEN` failure deep in a step.
echo "Checking workflow secret-presence guards..."
for wf in .github/workflows/*.yml; do
    [[ -f "$wf" ]] || continue
    if grep -qE 'secrets\.(CLAUDE_PAT|ANTHROPIC_API_KEY)\b' "$wf"; then
        if grep -q 'Verify required secrets' "$wf"; then
            pass "$wf has Verify required secrets guard"
        else
            fail "$wf references CLAUDE_PAT/ANTHROPIC_API_KEY but is missing the 'Verify required secrets' guard step (issue #162)"
        fi
    fi
done

echo ""

# --- Postmortem frontmatter check (ADR-015) ---
# Every docs/postmortems/postmortem-*.md must carry the YAML frontmatter
# block introduced by ADR-015. Required keys: postmortem_number, date,
# source_repo, source_commit, stacks, generalizes, follow_up_artifact,
# mirror_status. The template file is included intentionally — its
# frontmatter is the canonical example.
echo "Checking postmortem frontmatter (ADR-015)..."

REQUIRED_PM_KEYS=(
    "postmortem_number:"
    "date:"
    "source_repo:"
    "source_commit:"
    "stacks:"
    "generalizes:"
    "follow_up_artifact:"
    "mirror_status:"
)

for pm in docs/postmortems/postmortem-*.md; do
    [[ -f "$pm" ]] || continue
    # Extract the YAML frontmatter block.
    # Invariants enforced (per ADR-015 + bot review feedback on PR #218):
    #   1. Line 1 of the file MUST be `---`. The YAML-line-1 rule
    #      (commit 9c784ae) is what makes GitHub render the styled
    #      table view; anything before the opening delimiter — blank
    #      lines, HTML comments, BOMs — breaks that rendering. We
    #      enforce it strictly here so CI catches drift, not GitHub's
    #      preview.
    #   2. The block MUST be closed by a second `---`. Without this,
    #      a missing terminator would silently consume the rest of the
    #      file as "frontmatter" and key checks could pass on body text.
    # awk exit codes: 1 = line 1 is not `---`; 2 = no closing delim.
    awk_status=0
    fm=$(awk '
        BEGIN { in_fm = 0; saw_close = 0; bailed = 0 }
        NR == 1 {
            # Strip a UTF-8 BOM if present (some Windows editors add one).
            # Without this strip, the BOM bytes would make the line not
            # match `^---$` and CI would reject a file that GitHub still
            # renders the YAML table for, producing a confusing failure.
            sub(/^\357\273\277/, "")
            if ($0 !~ /^---[[:space:]]*$/) { bailed = 1; exit 1 }
            in_fm = 1
            next
        }
        in_fm && /^---[[:space:]]*$/ { saw_close = 1; exit }
        in_fm { print }
        END {
            # awk runs END even after a body `exit N`. Skip the
            # post-processing checks if we already bailed, otherwise
            # END would overwrite the body exit code.
            if (bailed) { exit 1 }
            if (NR == 0) { exit 1 }
            if (!saw_close) { exit 2 }
        }
    ' "$pm") || awk_status=$?
    if [[ $awk_status -eq 1 ]]; then
        fail "$pm does not begin with --- on line 1 (YAML frontmatter must be at line 1 for GitHub rendering; ADR-015)"
        continue
    elif [[ $awk_status -eq 2 ]]; then
        fail "$pm is missing the closing --- of its YAML frontmatter (ADR-015)"
        continue
    elif [[ $awk_status -ne 0 ]]; then
        fail "$pm frontmatter extraction failed with awk exit $awk_status (ADR-015)"
        continue
    fi
    if [[ -z "$fm" ]]; then
        fail "$pm has an empty YAML frontmatter block (ADR-015)"
        continue
    fi
    missing=""
    for key in "${REQUIRED_PM_KEYS[@]}"; do
        # grep -E with ^ anchor + key + exactly-one-space + non-space-non-comment:
        # enforces "key at BOL followed by exactly one space and immediately
        # a real value character" (the repo style guide convention for YAML
        # key-value formatting). Rejecting '#' as the first value character
        # prevents comment-only placeholders like 'source_commit: # TODO'
        # from passing: YAML parses those as null/empty even though they
        # look non-empty to a line-based grep. The key already includes the
        # trailing colon, so this catches wrong-position, wrong-spacing, and
        # comment-only placeholder drift in one check.
        if ! grep -qE "^${key} [^[:space:]#]" <<<"$fm"; then
            missing="$missing $key"
        fi
    done
    if [[ -n "$missing" ]]; then
        fail "$pm frontmatter missing keys:$missing"
    else
        pass "$pm has all required frontmatter keys"
    fi
    # Validate source_commit looks like a commit SHA (7-40 hex chars).
    # Values like 'main' or 'release/latest' are mutable branch refs and
    # weaken incident provenance (ADR-015 requires immutable SHA).
    # The template file legitimately holds the placeholder string
    # '<sha-at-time-of-incident>' — skip the SHA format check for it.
    if [[ "$pm" != *postmortem-template* ]]; then
        sc=$(grep -E '^source_commit: ' <<<"$fm" | sed 's/^source_commit: //' | tr -d '[:space:]')
        if [[ -z "$sc" ]]; then
            : # already caught by the required-keys loop above
        elif [[ ! "$sc" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
            fail "$pm source_commit '$sc' does not look like a commit SHA (need 7-40 hex chars; ADR-015)"
        else
            pass "$pm source_commit looks like a commit SHA"
        fi
    fi
    # Validate generalizes and follow_up_artifact canonical values (ADR-015).
    # These checks apply to all files including the template (which has
    # valid canonical defaults: generalizes: No, follow_up_artifact: none).
    gen=$(grep -E '^generalizes: ' <<<"$fm" | sed 's/^generalizes: //' | tr -d '[:space:]')
    if [[ "$gen" =~ ^(Yes|No|Unclear)$ ]]; then
        pass "$pm generalizes value is valid"
    else
        fail "$pm generalizes '$gen' is not one of Yes | No | Unclear (ADR-015)"
    fi
    fua=$(grep -E '^follow_up_artifact: ' <<<"$fm" | sed 's/^follow_up_artifact: //' | tr -d '[:space:]')
    if [[ "$fua" =~ ^(ADR-[0-9]+|issue-[0-9]+|PR-[0-9]+|none)$ ]]; then
        pass "$pm follow_up_artifact value matches canonical schema"
    else
        fail "$pm follow_up_artifact '$fua' does not match canonical schema ADR-NNN|issue-NNN|PR-NNN|none (ADR-015)"
    fi
done

echo ""

# --- Summary ---
echo "========================================"
echo "Summary"
echo "========================================"
echo -e "${GREEN}Passed:${NC} $PASS"
echo -e "${YELLOW}Warnings:${NC} $WARN"
echo -e "${RED}Failed:${NC} $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}Template verification FAILED${NC}"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo -e "${YELLOW}Template verification PASSED with warnings${NC}"
    exit 0
else
    echo -e "${GREEN}Template verification PASSED${NC}"
    exit 0
fi
