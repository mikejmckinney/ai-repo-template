#!/bin/bash
# 00-detect-repo.sh — Auto-detect GitHub repository slug for downstream modules.
#
# Sourced by scripts/setup.sh. Sets:
#   FULL_REPO  — "owner/repo" (or "host/owner/repo" for GHES) used by 40/50/60
#                to scope every gh call. Empty if detection fails (downstream
#                modules surface a single remediation block instead of erroring
#                per-call).
# Side effects:
#   - Updates the PLEASE_UPDATE_THIS/URL or YOUR_USERNAME/YOUR_REPOSITORY
#     placeholder in .github/ISSUE_TEMPLATE/config.yml when running outside
#     the template repos themselves.
#
# Re-runnable: yes. Honors GH_REPO / GITHUB_REPOSITORY env overrides.

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
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
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
  # See AGENTS.md "Template detection (important)" section.
  _is_template_repo=false
  case "$FULL_REPO" in
    mikejmckinney/ai-repo-template | mikejmckinney/dotfiles) _is_template_repo=true ;;
  esac
  if [[ "$_is_template_repo" == "true" ]]; then
    log_info "Detected template repo ($FULL_REPO); leaving $CONFIG_FILE placeholders intact"
  elif [[ -f "$CONFIG_FILE" ]]; then
    # Note: Using temp file for portability (BSD sed on macOS differs from GNU sed)
    if grep -q "PLEASE_UPDATE_THIS/URL" "$CONFIG_FILE"; then
      sed "s|PLEASE_UPDATE_THIS/URL|${FULL_REPO}|g" "$CONFIG_FILE" >"${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
      log_info "Updated $CONFIG_FILE with repository URL"
    elif grep -q "YOUR_USERNAME/YOUR_REPOSITORY" "$CONFIG_FILE"; then
      sed "s|YOUR_USERNAME/YOUR_REPOSITORY|${FULL_REPO}|g" "$CONFIG_FILE" >"${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
      log_info "Updated $CONFIG_FILE with repository URL"
    else
      log_info "$CONFIG_FILE already configured"
    fi
  fi
fi
