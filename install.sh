#!/bin/bash
# =============================================================================
# AI Repo Template — Codespace Install Script
# =============================================================================
# This script runs automatically when a GitHub Codespace starts (via the
# Codespaces "Dotfiles" feature). It installs VS Code extensions and copies
# the agent workflow kit into the workspace.
#
# About the $DOTFILES variable (legacy naming, intentional):
#   The GitHub Codespaces "Dotfiles" feature sets $DOTFILES to the path of the
#   repository the user linked as their Codespaces dotfiles repo. The name is
#   a Codespaces convention and has nothing to do with Unix dotfiles
#   (~/.bashrc, ~/.vimrc, etc.). This template uses that hook purely as a
#   bootstrap mechanism; we keep the variable name as-is so the script still
#   works with Codespaces unmodified.
#
# Environment:
#   $DOTFILES - Path to the template repo (set by GitHub Codespaces; falls
#               back to the script's own directory if unset).
#   $HOME     - User home directory.
#
# Usage:
#   Automatic: Linked via GitHub Codespaces "Dotfiles" setting.
#   Manual:    DOTFILES=/path/to/ai-repo-template bash install.sh
# =============================================================================

set -e # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$1"
}

log_warn() {
  printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"
}

log_error() {
  printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1"
}

# =============================================================================
# Pre-flight Checks
# =============================================================================

# Check if we're in a Codespace or VS Code environment
if ! command -v code &>/dev/null; then
  log_warn "'code' command not found. Extension installation will be skipped."
  log_warn "This is expected outside of VS Code/Codespaces environments."
  SKIP_EXTENSIONS=true
else
  SKIP_EXTENSIONS=false
fi

# Determine template path. $DOTFILES is set by the Codespaces "Dotfiles"
# feature (see header note); outside Codespaces we fall back to the script's
# own directory so the script still works for local testing.
if [[ -z "$DOTFILES" ]]; then
  DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  log_warn "DOTFILES not set. Using script directory: $DOTFILES"
fi

# Determine workspace path
if [[ -z "$WORKSPACE" ]]; then
  if [[ -d "/workspaces" ]]; then
    # GitHub Codespaces default
    WORKSPACE=$(find /workspaces -maxdepth 1 -type d ! -name workspaces | head -1)
  elif [[ -d "$HOME/workspace" ]]; then
    WORKSPACE="$HOME/workspace"
  else
    WORKSPACE="$PWD"
  fi
fi

# Validate workspace path is not empty
if [[ -z "$WORKSPACE" ]]; then
  log_error "Could not determine workspace path. Please set WORKSPACE environment variable."
  exit 1
fi

log_info "Template path: $DOTFILES"
log_info "Workspace path: $WORKSPACE"

# =============================================================================
# 1. Install VS Code Extensions
# =============================================================================

EXTENSIONS=(
  "saoudrizwan.claude-dev"     # Cline (formerly Claude Dev) - AI assistant
  "ms-vscode.live-server"      # Live Preview for web development
  "esbenp.prettier-vscode"     # Prettier - code formatter
  "ms-vsliveshare.vsliveshare" # Live Share - collaborative development
)

if [[ "$SKIP_EXTENSIONS" == "false" ]]; then
  log_info "Installing VS Code extensions..."

  for ext in "${EXTENSIONS[@]}"; do
    ext_name="$ext"
    if code --install-extension "$ext_name" 2>/dev/null; then
      log_info "  ✓ Installed: $ext_name"
    else
      log_warn "  ⚠ Failed to install: $ext_name"
    fi
  done
else
  log_info "Skipping extension installation (no 'code' command)"
fi

# =============================================================================
# 2. Copy Agent Workflow Kit to Workspace
# =============================================================================

# Copy AGENTS.md to workspace root if not present
AGENTS_SRC="$DOTFILES/AGENTS.md"
AGENTS_DST="$WORKSPACE/AGENTS.md"
AGENTS_SRC_EXISTS=false

if [[ -f "$AGENTS_SRC" ]]; then
  AGENTS_SRC_EXISTS=true
  if [[ -f "$AGENTS_DST" ]]; then
    log_warn "  ⚠ $AGENTS_DST already exists, skipping"
  else
    cp "$AGENTS_SRC" "$AGENTS_DST"
    log_info "  ✓ Copied: AGENTS.md"
  fi
fi

# ---------------------------------------------------------------------------
# Agent workflow kit
# ---------------------------------------------------------------------------
# Copy the monolithic workflow, review, context, and verification surfaces.
#
# Each copy is best-effort: a missing source is a warning, not a fatal error,
# so Codespaces bootstrap does not fail for users of older template versions.

# Helper: copy a relative path from $DOTFILES into $WORKSPACE, skipping if the
# destination already exists and warning if the source is missing. Creates the
# destination directory when needed. Tracks pass/skip counts for the summary.
MULTIAGENT_COPIED=0
MULTIAGENT_SKIPPED=0
MULTIAGENT_MISSING=0

copy_template_file() {
  local rel_path="$1"
  local src="$DOTFILES/$rel_path"
  local dst="$WORKSPACE/$rel_path"

  if [[ ! -e "$src" ]]; then
    log_warn "  ⚠ Source missing: $rel_path"
    MULTIAGENT_MISSING=$((MULTIAGENT_MISSING + 1))
    return
  fi

  if [[ -e "$dst" ]]; then
    log_info "  = Exists: $rel_path (skipping)"
    MULTIAGENT_SKIPPED=$((MULTIAGENT_SKIPPED + 1))
    return
  fi

  local dst_dir
  dst_dir="$(dirname "$dst")"
  if [[ ! -d "$dst_dir" ]]; then
    mkdir -p "$dst_dir"
  fi

  if [[ -d "$src" ]]; then
    cp -R "$src" "$dst" || {
      log_warn "  ⚠ Failed to copy directory: $rel_path"
      return
    }
  else
    cp "$src" "$dst" || {
      log_warn "  ⚠ Failed to copy file: $rel_path"
      return
    }
  fi

  log_info "  ✓ Copied: $rel_path"
  MULTIAGENT_COPIED=$((MULTIAGENT_COPIED + 1))
}

log_info "Installing agent workflow kit..."

MULTIAGENT_FILES=(
  "AGENT.md"
  ".github/PLAN_TEMPLATE.md"
  ".github/pull_request_template.md"
  ".github/templates/issue-implementation-plan.md"
  ".github/agent-runtime"
  ".github/schemas/postmerge-retro-monolithic.schema.json"
  ".github/schemas/weekly-review.schema.json"
  ".agents/skills"
  ".cursor"
  ".mcp.json"
  ".opencode/opencode.json"
  "skills-lock.json"
  ".context/00_INDEX.md"
  ".context/roadmap.md"
  ".context/sessions/README.md"
  ".context/sessions/feedback_template.md"
  ".context/sessions/latest_summary.md"
  ".context/state/README.md"
  ".context/state/agent_state_comment_template.md"
  ".context/vision/README.md"
  ".context/vision/architecture"
  ".context/vision/mockups"
  "docs/guides/agent-best-practices.md"
  "docs/guides/agent-pipeline.md"
  "docs/guides/agents-md-section-redirects.md"
  "docs/guides/context-files-explained.md"
  "docs/guides/opportunity-feedback-examples.md"
  "docs/guides/opencode-termination-diagnostics.md"
  "docs/guides/problem-framing.md"
  "docs/guides/repo-orchestration-patterns-reference.md"
  "docs/guides/design-patterns.md"
  "docs/guides/design-patterns-concurrency.md"
  "docs/guides/design-patterns-data.md"
  "docs/guides/design-patterns-gof.md"
  "docs/guides/design-patterns-integration.md"
  "docs/guides/design-patterns-post-gof.md"
  "docs/guides/optional-skills.md"
  "docs/guides/sandbox-verification.md"
  ".github/prompts/README.md"
  ".github/prompts/capture-postmortem.md"
  ".github/prompts/mirror-postmortem.md"
  ".github/prompts/shared-review-lenses.md"
  "scripts/diag-sandbox.sh"
  "scripts/diag-hang-snapshot.sh"
  "scripts/archive-opencode-database.sh"
  "scripts/diagnose-opencode-session.sh"
  "scripts/format.sh"
  "scripts/check-markdown-links.py"
  "scripts/generate-pap-catalog.py"
  "scripts/generate-issue-plans.py"
  "scripts/validate-active-labels.py"
  "scripts/codespace-post-start.sh"
  "scripts/lib/ensure-gh-pat-auth.sh"
  "scripts/lib/sandbox-remote.sh"
  "scripts/lib/assertions.sh"
  "scripts/lib/logging.sh"
  "scripts/workflows/lib/run-opencode.mjs"
  "scripts/workflows/lib/run-opencode-fix.sh"
  "scripts/verify-env.sh"
  "scripts/verify-pr.sh"
  "docs/research/.gitkeep"
)

for rel in "${MULTIAGENT_FILES[@]}"; do
  copy_template_file "$rel"
done

log_info "Agent workflow kit: copied=$MULTIAGENT_COPIED skipped=$MULTIAGENT_SKIPPED missing=$MULTIAGENT_MISSING"

# =============================================================================
# 2b. Codespace post-start (gh PAT auth + sandbox advisory; non-fatal)
# =============================================================================

if [[ "${CODESPACES:-}" == "true" ]] && [[ -f "$WORKSPACE/scripts/codespace-post-start.sh" ]]; then
  log_info "Running Codespace post-start hook..."
  if (cd "$WORKSPACE" && bash scripts/codespace-post-start.sh); then
    log_info "Codespace post-start hook finished."
  else
    log_warn "Codespace post-start hook reported issues (non-fatal)."
  fi
elif [[ "${CODESPACES:-}" == "true" ]]; then
  log_warn "scripts/codespace-post-start.sh not found in workspace; skipping PAT auth hook."
fi

# =============================================================================
# 3. Verification
# =============================================================================

log_info "Verifying installation..."

VERIFY_PASS=0
VERIFY_FAIL=0

verify() {
  if [[ -e "$1" ]]; then
    log_info "  ✓ $1"
    VERIFY_PASS=$((VERIFY_PASS + 1))
  else
    log_error "  ✗ $1"
    VERIFY_FAIL=$((VERIFY_FAIL + 1))
  fi
}

if [[ "$SKIP_EXTENSIONS" == "false" ]]; then
  # Verify extensions are installed
  for ext in "${EXTENSIONS[@]}"; do
    ext_name="$ext"
    if code --list-extensions 2>/dev/null | grep -qi "$ext_name"; then
      log_info "  ✓ Extension: $ext_name"
      VERIFY_PASS=$((VERIFY_PASS + 1))
    else
      log_warn "  ⚠ Extension may not be installed: $ext_name"
    fi
  done
fi

# Verify copied files (only if source existed)
if [[ "$AGENTS_SRC_EXISTS" == "true" ]]; then
  verify "$AGENTS_DST"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "========================================"
echo "Installation Complete"
echo "========================================"
echo "Template: $DOTFILES"
echo "Workspace: $WORKSPACE"

if [[ "$SKIP_EXTENSIONS" == "false" ]]; then
  echo "Extensions: ${#EXTENSIONS[@]} configured"
fi

echo ""
log_info "✅ Template installation complete!"
