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

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
log_step() { printf "\n${GREEN}==>${NC} %s\n" "$1"; }

echo "========================================"
echo "Project Setup"
echo "========================================"

# --- Step 0: Auto-detect repo and update config ---
log_step "Auto-detecting repository"

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
                FULL_REPO="${SAFE_OWNER}/${SAFE_NAME}"
                log_info "Detected repository: $FULL_REPO"
            
                # Update issue template config with correct discussions URL
                # Note: Using temp file for portability (BSD sed on macOS differs from GNU sed)
                CONFIG_FILE=".github/ISSUE_TEMPLATE/config.yml"
                if [[ -f "$CONFIG_FILE" ]]; then
                    if grep -q "PLEASE_UPDATE_THIS/URL" "$CONFIG_FILE"; then
                        sed "s|PLEASE_UPDATE_THIS/URL|${SAFE_OWNER}/${SAFE_NAME}|g" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                        log_info "Updated $CONFIG_FILE with repository URL"
                    elif grep -q "YOUR_USERNAME/YOUR_REPOSITORY" "$CONFIG_FILE"; then
                        sed "s|YOUR_USERNAME/YOUR_REPOSITORY|${SAFE_OWNER}/${SAFE_NAME}|g" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                        log_info "Updated $CONFIG_FILE with repository URL"
                    else
                        log_info "$CONFIG_FILE already configured"
                    fi
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
# .github/workflows/AGENT-PIPELINE-GUIDE.md). Safe to re-run: `gh label
# create` returns non-zero when a label already exists, which we swallow.
# Requires `gh auth login` first; otherwise the whole step is skipped.
log_step "Configuring pipeline labels and repo variables"

if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    # Six copilot:* state labels + from-backlog marker. `needs-human` is
    # referenced by ci-tests.yml and the backlog dispatch workflow, so
    # ensure it exists too.
    gh label create "copilot:ready"          --color "0E8A16" --description "Assign Copilot when budget allows"                              2>/dev/null || true
    gh label create "copilot:in-progress"    --color "1D76DB" --description "Assigned to Copilot, counts toward concurrent budget"           2>/dev/null || true
    gh label create "copilot:queued"         --color "FBCA04" --description "Waiting for an open Copilot slot"                               2>/dev/null || true
    gh label create "copilot:daily-cap-hit"  --color "D93F0B" --description "Hit daily assignment cap; manual re-queue required"             2>/dev/null || true
    gh label create "from-backlog"           --color "5319E7" --description "Issue auto-created from .context/backlog.yaml"                  2>/dev/null || true
    gh label create "needs-human"            --color "B60205" --description "Requires human input (e.g., empty roadmap phase, CI failure)"   2>/dev/null || true
    log_info "Pipeline labels ensured (copilot:* + from-backlog + needs-human)"

    # Budget knobs for agent-assign-copilot.yml. Only set if missing so a
    # re-run of setup.sh doesn't clobber tuned values.
    if ! gh variable list --json name --jq '.[].name' 2>/dev/null | grep -q "^MAX_COPILOT_CONCURRENT$"; then
        gh variable set MAX_COPILOT_CONCURRENT --body "3"  >/dev/null && log_info "Set MAX_COPILOT_CONCURRENT=3"
    else
        log_info "MAX_COPILOT_CONCURRENT already set (leaving as-is)"
    fi
    if ! gh variable list --json name --jq '.[].name' 2>/dev/null | grep -q "^MAX_COPILOT_DAILY$"; then
        gh variable set MAX_COPILOT_DAILY      --body "20" >/dev/null && log_info "Set MAX_COPILOT_DAILY=20"
    else
        log_info "MAX_COPILOT_DAILY already set (leaving as-is)"
    fi
else
    log_warn "gh CLI not authenticated; skipping label/variable creation."
    log_warn "After running 'gh auth login', re-run scripts/setup.sh, or create the following manually:"
    log_warn "  Labels: copilot:ready, copilot:in-progress, copilot:queued, copilot:daily-cap-hit, from-backlog, needs-human"
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
printf "${GREEN}Setup Complete!${NC}\n"
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
