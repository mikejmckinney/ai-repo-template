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
    ".github/prompts/copilot-onboarding.md"
    ".github/prompts/repo-onboarding.md"
    ".github/prompts/fleet.md"
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
    ".context/roadmap.md"
    ".context/rules/README.md"
    ".context/rules/agent_ownership.md"
    ".context/rules/domain_code_quality.md"
    ".context/sessions/README.md"
    ".context/sessions/latest_summary.md"
    ".context/state/README.md"
    ".context/state/_active.md"
    ".context/state/coordination.md"
    ".context/state/task_template.md"
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
    "docs/guides/agent-best-practices.md"
    "docs/guides/context-files-explained.md"
    "docs/guides/multi-agent-coordination.md"
    "docs/guides/optional-skills.md"
    "docs/decisions/adr-template.md"
    "docs/decisions/adr-001-context-pack-structure.md"
    "docs/decisions/adr-004-analyst-role-and-feedback-loop.md"
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
    ".github/workflows/auto-resolve-on-merge.yml"
    ".github/workflows/ci-tests.yml"
    ".github/workflows/claude.yml"
    ".github/workflows/keep-warm.yml"
    ".github/workflows/validate-connections.yml"
    ".github/workflows/agent-heartbeat.yml.template"
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

# Check context 00_INDEX.md has truth hierarchy
if grep -q "priority" .context/00_INDEX.md 2>/dev/null; then
    pass ".context/00_INDEX.md has priority information"
else
    warn ".context/00_INDEX.md missing priority information"
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
