#!/bin/bash
# Description: One-command project setup
# Usage: ./scripts/setup.sh
#
# This script handles:
# 1. Installing dependencies
# 2. Setting up environment variables
# 3. Running database migrations (if applicable)
# 4. Verifying the environment
#
# TEMPLATE_PLACEHOLDER: Customize this for your project

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$1"; }
log_warn() { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"; }
log_error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1"; }
log_step() { printf '\n%b==>%b %s\n' "$GREEN" "$NC" "$1"; }

echo "========================================"
echo "Project Setup"
echo "========================================"

# --- Step 0: Auto-detect repo and update config ---
log_step "Auto-detecting repository"

# FULL_REPO is the canonical "owner/repo" slug used by Step 5 to scope every
# `gh` call (labels, variables). Initialized empty; populated below from any
# of: explicit env override, parsed git remote, or (later, in Step 5)
# `gh repo view` once gh is authenticated.
FULL_REPO=""

# Honor explicit overrides first. GH_REPO is gh's own convention; in
# Codespaces/Actions GITHUB_REPOSITORY is auto-set by the platform.
if [[ -n "${GH_REPO:-}" ]]; then
    FULL_REPO=$(printf "%s" "$GH_REPO" | tr -cd '[:alnum:]_./-')
    log_info "Using GH_REPO override: $FULL_REPO"
elif [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    FULL_REPO=$(printf "%s" "$GITHUB_REPOSITORY" | tr -cd '[:alnum:]_./-')
    log_info "Using GITHUB_REPOSITORY: $FULL_REPO"
fi

# Try to detect the GitHub repository from git remote
if command -v git &> /dev/null && git rev-parse --is-inside-work-tree &> /dev/null; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [[ -n "$REMOTE_URL" ]]; then
        # Extract owner/repo from various URL formats. Supported examples:
        #   SSH:            git@github.com:owner/repo.git         -> owner/repo
        #   HTTPS:          https://github.com/owner/repo.git     -> owner/repo
        #   HTTPS no .git:  https://github.com/owner/repo         -> owner/repo
        #   Repo with dot:  git@github.com:owner/my.repo.name.git -> owner/my.repo.name
        # Not supported (intentional): GitHub Enterprise Server on custom
        # domains (e.g., github.mycorp.com) — the regex requires the literal
        # "github.com" host. Set FULL_REPO manually if you need Enterprise.
        # Match repo names with dots (e.g., my.repo.name) - strip .git suffix separately
        if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/(.+)$ ]]; then
            REPO_OWNER="${BASH_REMATCH[1]}"
            REPO_NAME="${BASH_REMATCH[2]}"
            # Strip trailing .git if present
            REPO_NAME="${REPO_NAME%.git}"
            
            # Sanitize variables to prevent command injection (security fix)
            # Use printf instead of echo (echo interprets options like -n)
            # Put hyphen at end of tr character class to avoid range ambiguity
            SAFE_OWNER=$(printf "%s" "$REPO_OWNER" | tr -cd '[:alnum:]_.-')
            SAFE_NAME=$(printf "%s" "$REPO_NAME" | tr -cd '[:alnum:]_.-')
            
            # Validate non-empty before using in sed
            if [[ -z "$SAFE_OWNER" || -z "$SAFE_NAME" ]]; then
                log_warn "Could not extract valid owner/repo from remote URL"
            else
                # Don't clobber an explicit GH_REPO/GITHUB_REPOSITORY override.
                if [[ -z "$FULL_REPO" ]]; then
                    FULL_REPO="${SAFE_OWNER}/${SAFE_NAME}"
                    log_info "Detected repository: $FULL_REPO"
                else
                    log_info "Git remote points at ${SAFE_OWNER}/${SAFE_NAME}; keeping override $FULL_REPO"
                fi
            fi
        else
            log_warn "Could not parse repository from remote URL: $REMOTE_URL"
        fi
    else
        log_warn "No git remote configured, skipping repo auto-detection"
    fi
else
    log_warn "Not a git repository, skipping repo auto-detection"
fi

# Update config.yml placeholder using FULL_REPO. Runs after all detection paths
# so env overrides (GH_REPO/GITHUB_REPOSITORY) work even without a git remote.
if [[ -n "$FULL_REPO" ]]; then
    CONFIG_FILE=".github/ISSUE_TEMPLATE/config.yml"
    # Template-detection guard: when the current repo IS the template itself,
    # leave placeholders intact so source files don't get rewritten.
    # See .github/copilot-instructions.md "Template detection" section.
    _is_template_repo=false
    case "$FULL_REPO" in
        mikejmckinney/ai-repo-template|mikejmckinney/dotfiles) _is_template_repo=true ;;
    esac
    if [[ "$_is_template_repo" == "true" ]]; then
        log_info "Detected template repo ($FULL_REPO); leaving $CONFIG_FILE placeholders intact"
    elif [[ -f "$CONFIG_FILE" ]]; then
        # Note: Using temp file for portability (BSD sed on macOS differs from GNU sed)
        if grep -q "PLEASE_UPDATE_THIS/URL" "$CONFIG_FILE"; then
            sed "s|PLEASE_UPDATE_THIS/URL|${FULL_REPO}|g" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            log_info "Updated $CONFIG_FILE with repository URL"
        elif grep -q "YOUR_USERNAME/YOUR_REPOSITORY" "$CONFIG_FILE"; then
            sed "s|YOUR_USERNAME/YOUR_REPOSITORY|${FULL_REPO}|g" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            log_info "Updated $CONFIG_FILE with repository URL"
        else
            log_info "$CONFIG_FILE already configured"
        fi
    fi
fi

# --- Step 1: Environment File ---
log_step "Setting up environment variables"

if [[ -f ".env" ]]; then
    log_info ".env already exists, skipping"
elif [[ -f ".env.example" ]]; then
    cp .env.example .env
    log_info "Created .env from .env.example"
    log_warn "Review .env and update any placeholder values"
else
    log_warn "No .env.example found, skipping environment setup"
fi

# --- Step 2: Install Dependencies ---
log_step "Installing dependencies"

# Node.js
if [[ -f "package.json" ]]; then
    log_info "Found package.json, installing Node.js dependencies..."
    if [[ -f "package-lock.json" ]]; then
        npm ci
    else
        npm install
    fi
    log_info "Node.js dependencies installed"
fi

# Python
if [[ -f "requirements.txt" ]]; then
    log_info "Found requirements.txt, installing Python dependencies..."
    pip install -r requirements.txt
    log_info "Python dependencies installed"
elif [[ -f "pyproject.toml" ]]; then
    log_info "Found pyproject.toml, installing Python dependencies..."
    pip install -e .
    log_info "Python dependencies installed"
fi

# --- Step 3: Database Setup (if applicable) ---
log_step "Setting up database"

# Uncomment and customize for your project:
# if [[ -f "prisma/schema.prisma" ]]; then
#     log_info "Running Prisma migrations..."
#     npx prisma migrate dev
#     log_info "Database migrations complete"
# fi

# if [[ -f "alembic.ini" ]]; then
#     log_info "Running Alembic migrations..."
#     alembic upgrade head
#     log_info "Database migrations complete"
# fi

log_info "No database configuration detected (customize setup.sh if needed)"

# --- Step 4: Build (if applicable) ---
log_step "Building project"

# Check specifically for scripts.build to avoid false positives
# Use node to properly parse JSON if available, otherwise fall back to grep
BUILD_EXISTS=false
if [[ -f "package.json" ]]; then
    if command -v node &> /dev/null; then
        # Use node to properly check for scripts.build
        # Avoid optional chaining (?.) for compatibility with Node <14
        BUILD_EXISTS=$(node -e "var p=require('./package.json'); console.log(!!(p.scripts && p.scripts.build))" 2>/dev/null || echo "false")
    fi
    
    # Fallback to grep if node failed or not available
    if [[ "$BUILD_EXISTS" != "true" ]]; then
        # Options before pattern for BSD grep compatibility
        if grep -q '"scripts"' package.json && grep -A100 '"scripts"' package.json | grep -q '^\s*"build":'; then
            BUILD_EXISTS="true"
        fi
    fi
fi

if [[ "$BUILD_EXISTS" == "true" ]]; then
    log_info "Running build..."
    npm run build
    log_info "Build complete"
else
    log_info "No build step configured"
fi

# --- Step 5: Pipeline Labels & Repo Variables ---
# Labels and budget knobs consumed by the autonomous agent pipeline (see
# docs/guides/agent-pipeline.md). Safe to re-run: `gh label
# create` returns non-zero when a label already exists, which we swallow.
# Requires `gh auth login` first; otherwise the whole step is skipped.
log_step "Configuring pipeline labels and repo variables"

# Pre-flight: detect the Codespaces auto-injected GITHUB_TOKEN case. That
# token is scoped to `contents:write, metadata:read` by default, which means
# every `gh label create` (needs `issues:write`) and every `gh variable set`
# (needs admin) will 403. Rather than spam ~13 warnings, print one clear
# remediation block and skip Step 5.
#
# If the user has set a Codespaces user secret named GH_PAT (or one of the
# common aliases), prefer it: unset GITHUB_TOKEN and `gh auth login --with-token`
# so subsequent gh calls use the elevated PAT automatically. Recommended PAT:
# fine-grained, scoped to this repo, with Issues + Variables + Contents +
# Metadata + Pull requests = read/write, and Workflows = read/write if you
# edit workflows. Set it once at https://github.com/settings/codespaces.
_pipeline_setup_skip_reason=""
_gh_auth_ok=""
if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    _gh_auth_ok="true"
    # Only treat the `(GITHUB_TOKEN)` auth source as the Codespaces-limited
    # case when we're actually running inside a Codespace (`CODESPACES=true`).
    # In GitHub Actions or when a user has set `GITHUB_TOKEN` manually, the
    # same auth-source string shows up but the remediation below (Codespaces
    # user secret) doesn't apply — fall through to the normal per-command
    # error reporting instead.
    # `gh auth status` writes the token-source line to stderr.
    if [[ "${CODESPACES:-}" == "true" ]] && \
       gh auth status 2>&1 | grep -qE 'Logged in to github\.com.*\(GITHUB_TOKEN\)'; then
        # Try to upgrade auth using a Codespaces user secret if one is set.
        _user_pat=""
        for _var in GH_PAT GH_TOKEN_PAT CODESPACES_GH_PAT GITHUB_PAT; do
            if [[ -n "${!_var:-}" ]]; then
                _user_pat="${!_var}"
                _user_pat_var="$_var"
                break
            fi
        done
        if [[ -n "$_user_pat" ]]; then
            log_info "Found Codespaces secret \$$_user_pat_var; logging gh in with it."
            unset GITHUB_TOKEN
            if printf '%s' "$_user_pat" | gh auth login --with-token 2>/dev/null; then
                log_info "gh re-authenticated with \$$_user_pat_var"
            else
                log_warn "Failed to authenticate gh with \$$_user_pat_var; falling back to skip."
            fi
            unset _user_pat
        fi

        # Re-probe permission after potential upgrade. Only skip when the
        # probe succeeds AND explicitly returns "false" (token is
        # authenticated against the repo but lacks admin). If the probe
        # errors or returns empty (network blip, repo not found, jq miss),
        # fall through so per-command errors get surfaced rather than
        # silently swallowed behind the remediation block.
        _repo_admin=$(gh api "repos/{owner}/{repo}" --jq '.permissions.admin' 2>/dev/null || echo "")
        if [[ "$_repo_admin" == "false" ]]; then
            _pipeline_setup_skip_reason="codespaces-token"
        fi
    fi
fi

if [[ -n "$_pipeline_setup_skip_reason" ]]; then
    log_warn "gh is using the Codespaces-injected GITHUB_TOKEN, which lacks 'issues:write' and admin scopes."
    log_warn "Skipping label/variable creation to avoid noisy 403 errors."
    log_warn "Recommended (one-time setup, auto-applies to every future Codespace):"
    log_warn "  1) Create a fine-grained PAT: https://github.com/settings/personal-access-tokens/new"
    log_warn "     Repo permissions: Issues r/w, Variables r/w, Contents r/w, Metadata r, Pull requests r/w, Workflows r/w"
    log_warn "  2) Add as a Codespaces user secret named GH_PAT: https://github.com/settings/codespaces"
    log_warn "     Grant it access to this repo, then rebuild the Codespace (or re-run setup.sh in a new one)."
    log_warn "Ad-hoc alternative (current Codespace only):"
    log_warn "  unset GITHUB_TOKEN && gh auth login -s repo,workflow && ./scripts/setup.sh"
    log_warn "Or create the following manually:"
    log_warn "  Labels: auto-merge, agent-complete, no-auto-ready, claude-fix, claude-review, copilot-relay, smoke-test, copilot:ready, copilot:in-progress, copilot:queued, copilot:daily-cap-hit, from-backlog, needs-human, coordination-sync, no-coordination-check"
    log_warn "  Variables: MAX_COPILOT_CONCURRENT=3, MAX_COPILOT_DAILY=20"
elif [[ -n "$_gh_auth_ok" ]]; then
    # Last-resort FULL_REPO fallback: if Step 0 couldn't parse a remote and
    # no env override was provided, ask gh itself. This works when gh has
    # been authenticated against a repo via some out-of-band mechanism
    # (e.g., default repo set via `gh repo set-default`).
    if [[ -z "$FULL_REPO" ]]; then
        _repo_nwo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
        if [[ -n "$_repo_nwo" ]]; then
            # Prefix with GH_HOST for GHES / multi-host setups so the exported
            # GH_REPO value resolves against the correct GitHub instance.
            if [[ -n "${GH_HOST:-}" ]]; then
                FULL_REPO="${GH_HOST}/${_repo_nwo}"
            else
                FULL_REPO="$_repo_nwo"
            fi
            log_info "Resolved repository from gh: $FULL_REPO"
        fi
    fi

    # If we still don't know which repo to target, every `gh label`/`gh
    # variable` call below would emit the raw "no git remotes found" error.
    # Surface one consolidated remediation block instead.
    if [[ -z "$FULL_REPO" ]]; then
        log_warn "No GitHub repo target found; cannot create labels/variables."
        log_warn "Cause: no 'origin' git remote, and neither GH_REPO nor GITHUB_REPOSITORY is set."
        log_warn "Pick one:"
        log_warn "  a) Add a remote, then re-run:"
        log_warn "       git remote add origin https://github.com/<owner>/<repo>.git"
        log_warn "       ./scripts/setup.sh"
        log_warn "  b) One-shot override:"
        log_warn "       GH_REPO=<owner>/<repo> ./scripts/setup.sh"
        log_warn "Or create the following manually in the GitHub UI:"
        log_warn "  Labels: auto-merge, agent-complete, no-auto-ready, claude-fix, claude-review, copilot-relay, smoke-test, copilot:ready, copilot:in-progress, copilot:queued, copilot:daily-cap-hit, from-backlog, needs-human, coordination-sync, no-coordination-check"
        log_warn "  Variables: MAX_COPILOT_CONCURRENT=3, MAX_COPILOT_DAILY=20"
    else
        # Scope every `gh` call in this block to FULL_REPO. gh respects
        # GH_REPO as the "default repo" override, which avoids having to
        # thread `--repo "$FULL_REPO"` through each helper.
        export GH_REPO="$FULL_REPO"
        log_info "Targeting $FULL_REPO for label/variable creation"

    # Helper: create a label idempotently, surfacing real failures.
    # `gh label create` exits non-zero for both "already exists" and real errors;
    # check existence on failure so genuine permission/API errors aren't swallowed.
    # Capture stderr so the WARN includes the actual gh/API error message.
    _ensure_label() {
        local name="$1" color="$2" desc="$3" err first_err
        err=$(gh label create "$name" --color "$color" --description "$desc" 2>&1 >/dev/null) && return 0
        # Failure path: confirm whether the label already exists (quiet) or report real error.
        if gh label list --json name --jq '.[].name' 2>/dev/null | grep -qF "$name"; then
            return 0
        fi
        first_err=$(printf '%s\n' "$err" | grep -v '^$' | head -n1)
        log_warn "Could not create label '$name' — ${first_err:-unknown error}"
    }

    # Create every pipeline label surfaced in docs/guides/agent-pipeline.md's
    # label table so the doc's "created automatically by setup.sh" claim
    # is literally true. Split into two groups for readability:
    #   - Opt-in / state labels driving the workflows.
    #   - copilot:* state labels driving the backlog pipeline.
    _ensure_label "auto-merge"            "0E8A16" "Enable auto-merge workflow for this PR"
    _ensure_label "agent-complete"        "0E8A16" "PR merged and linked issue closed"
    _ensure_label "no-auto-ready"         "BFDADC" "Opt out of automatic ready-state handling"
    _ensure_label "claude-fix"            "FBCA04" "Opt PR in to agent-fix-reviews.yml (Claude resolution)"
    _ensure_label "claude-review"         "1D76DB" "Opt PR in to claude.yml auto-review (invokes judge subagent)"
    _ensure_label "copilot-relay"         "5319E7" "Opt PR in to agent-relay-reviews.yml (Copilot resolution; included in subscription)"
    _ensure_label "smoke-test"            "E99695" "Workflow-validation PR; auto-merge/relay/fix-reviews skip to avoid mid-test interference"
    _ensure_label "copilot:ready"         "0E8A16" "Assign Copilot when budget allows"
    _ensure_label "copilot:in-progress"   "1D76DB" "Assigned to Copilot, counts toward concurrent budget"
    _ensure_label "copilot:queued"        "FBCA04" "Waiting for an open Copilot slot"
    _ensure_label "copilot:daily-cap-hit" "D93F0B" "Hit daily assignment cap; manual re-queue required"
    _ensure_label "from-backlog"          "5319E7" "Issue auto-created from .context/backlog.yaml"
    _ensure_label "needs-human"           "B60205" "Requires human input (e.g., empty roadmap phase, CI failure)"
    _ensure_label "coordination-sync"     "BFDADC" "Auto-filed by Coordination Sync workflow (stale lock tracking)"
    _ensure_label "no-coordination-check" "EDEDED" "Opt PR out of agent-coordination-sync.yml suggestions"
    log_info "Pipeline labels ensured (auto-merge, agent-complete, no-auto-ready, claude-fix, claude-review, copilot-relay, smoke-test, copilot:*, from-backlog, needs-human, coordination-sync, no-coordination-check)"

    # Budget knobs for agent-assign-copilot.yml. Only set if missing so a
    # re-run of setup.sh doesn't clobber tuned values. `gh variable get` is
    # used instead of `gh variable list | grep` to avoid pagination limits.
    _ensure_variable() {
        local name="$1" value="$2" err first_err
        if gh variable get "$name" &>/dev/null; then
            log_info "$name already set (leaving as-is)"
            return 0
        fi
        if err=$(gh variable set "$name" --body "$value" 2>&1 >/dev/null); then
            log_info "Set $name=$value"
        else
            first_err=$(printf '%s\n' "$err" | grep -v '^$' | head -n1)
            log_warn "Could not set $name — ${first_err:-unknown error}. Set it manually to $value if needed."
        fi
    }
    _ensure_variable MAX_COPILOT_CONCURRENT 3
    _ensure_variable MAX_COPILOT_DAILY 20
    fi
else
    log_warn "gh CLI not authenticated; skipping label/variable creation."
    log_warn "After running 'gh auth login', re-run scripts/setup.sh, or create the following manually:"
    log_warn "  Labels: auto-merge, agent-complete, no-auto-ready, claude-fix, claude-review, copilot-relay, smoke-test, copilot:ready, copilot:in-progress, copilot:queued, copilot:daily-cap-hit, from-backlog, needs-human, coordination-sync, no-coordination-check"
    log_warn "  Variables: MAX_COPILOT_CONCURRENT=3, MAX_COPILOT_DAILY=20"
fi

# --- Step 6: Verify Environment ---
log_step "Verifying environment"

if [[ -f "scripts/verify-env.sh" ]]; then
    ./scripts/verify-env.sh
else
    log_warn "verify-env.sh not found, skipping verification"
fi

# --- Done ---
echo ""
echo "========================================"
printf '%bSetup Complete!%b\n' "$GREEN" "$NC"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Review .env and update any placeholder values"
echo "  2. Check .context/00_INDEX.md for project context"
echo "  3. Start development!"
echo ""

# Show available scripts if package.json exists
if [[ -f "package.json" ]]; then
    echo "Available npm scripts:"
    grep -E '^\s+"[^"]+":' package.json | head -10 | sed 's/[",]//g' | sed 's/^/  /'
fi
