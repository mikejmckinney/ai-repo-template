#!/usr/bin/env bash
# Description: One-time bootstrap of the sandbox sibling repo (ADR-016).
# Usage: SANDBOX_PAT=<value> [SANDBOX_ANTHROPIC_KEY=<value>] \
#        [SANDBOX_REPO_NAME=<owner/repo>] [SANDBOX_REMOTE=sandbox] \
#        ./scripts/sandbox-bootstrap.sh
#
# Performs the steps documented in docs/guides/sandbox-verification.md
# § "One-time setup":
#   1. Resolve upstream repo (owner + name) from `origin`.
#   2. Create the sandbox sibling repo (private; same owner).
#   3. Mirror upstream main into the sandbox.
#   4. Set CLAUDE_PAT secret on the sandbox repo from $SANDBOX_PAT.
#   5. (Optional) Set ANTHROPIC_API_KEY from $SANDBOX_ANTHROPIC_KEY.
#   6. Add a git remote on this checkout pointing at the sandbox.
#
# Idempotent: re-running on an already-bootstrapped sandbox is safe.
# Existing repo / existing remote / existing secret are skipped with a
# log line, not a hard error.
#
# Required environment:
#   SANDBOX_PAT           Fine-grained PAT scoped to the sandbox repo only.
#                         Must NOT reuse the production CLAUDE_PAT — see
#                         "Secrets hygiene" in sandbox-verification.md.
#                         Required scopes: Contents R/W, Pull requests R/W,
#                         Issues R/W, Actions R, Variables R, Metadata R.
#
# Optional environment:
#   BOOTSTRAP_GH_TOKEN    Personal token used ONLY for the repo-create +
#                         mirror-push steps. Use this when your default
#                         `gh auth` is a Codespace/Actions token that
#                         cannot create repos under your owner namespace
#                         (the symptom is GraphQL: "Resource not
#                         accessible by integration (createRepository)").
#                         Required scopes: classic `repo` (and `admin:org`
#                         if creating under an org), OR fine-grained on
#                         your user account with Administration: R/W,
#                         Contents: R/W, Metadata: R at the **account**
#                         level — not just the upstream repo level.
#                         When unset, the script uses your existing
#                         `gh auth` identity.
#   SANDBOX_ANTHROPIC_KEY Anthropic API key for sandbox-only claude.yml /
#                         agent-fix-reviews.yml runs. A separate
#                         sandbox-budget key is recommended.
#   SANDBOX_REPO_NAME     Override the default sandbox slug
#                         ("<upstream-owner>/<upstream-name>-sandbox").
#                         Use full "owner/repo" form.
#   SANDBOX_REMOTE        Local git remote name to add (default: "sandbox").

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$1"; }
log_warn() { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"; }
log_error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1" >&2; }
log_step() { printf '\n%b==>%b %s\n' "$GREEN" "$NC" "$1"; }

# ── Preconditions ───────────────────────────────────────────────────────────

if ! command -v gh >/dev/null 2>&1; then
  log_error "gh CLI not found. Install gh >= 2.40 first."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  log_error "gh is not authenticated. Run 'gh auth login' first."
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log_error "Not inside a git working tree. Run from your upstream repo checkout."
  exit 1
fi

if [[ -z "${SANDBOX_PAT:-}" ]]; then
  log_error "SANDBOX_PAT is required. Mint a sandbox-only PAT first; do NOT reuse production CLAUDE_PAT."
  log_error "See docs/guides/sandbox-verification.md § 'One-time setup' for required scopes."
  exit 1
fi

# If BOOTSTRAP_GH_TOKEN is set, scope it to this script run only via
# GH_TOKEN. gh's auth-precedence treats GH_TOKEN as overriding the
# stored credential without modifying ~/.config/gh, so the user's
# global `gh auth login` state is left untouched.
if [[ -n "${BOOTSTRAP_GH_TOKEN:-}" ]]; then
  export GH_TOKEN="$BOOTSTRAP_GH_TOKEN"
  log_info "Using BOOTSTRAP_GH_TOKEN for gh API calls in this run."
fi

# ── Step 1: Resolve upstream repo ───────────────────────────────────────────

log_step "Resolving upstream repo from 'origin' remote"

UPSTREAM_URL=$(git remote get-url origin)
UPSTREAM_NAME=$(basename "$UPSTREAM_URL" .git)
UPSTREAM_OWNER=$(gh repo view --json owner -q .owner.login)
SANDBOX_REPO="${SANDBOX_REPO_NAME:-${UPSTREAM_OWNER}/${UPSTREAM_NAME}-sandbox}"
SANDBOX_REMOTE="${SANDBOX_REMOTE:-sandbox}"

log_info "Upstream: ${UPSTREAM_OWNER}/${UPSTREAM_NAME}"
log_info "Sandbox:  ${SANDBOX_REPO}"
log_info "Remote:   ${SANDBOX_REMOTE}"

# ── Step 2: Create sandbox sibling repo ─────────────────────────────────────

log_step "Creating sandbox repo (private)"

if gh repo view "$SANDBOX_REPO" >/dev/null 2>&1; then
  log_info "Sandbox repo already exists — skipping create."
else
  if ! gh repo create "$SANDBOX_REPO" \
    --private \
    --description "Sandbox for verifying default-branch-only workflow changes from ${UPSTREAM_NAME} (see ADR-016)" 2>/tmp/sandbox-bootstrap-create.err; then
    err=$(cat /tmp/sandbox-bootstrap-create.err)
    rm -f /tmp/sandbox-bootstrap-create.err
    log_error "gh repo create failed:"
    log_error "  ${err}"
    if [[ "$err" == *"Resource not accessible by integration"* ]] \
      || [[ "$err" == *"createRepository"* ]] \
      || [[ "$err" == *"403"* ]]; then
      log_error ""
      log_error "This usually means your gh auth identity (Codespaces token, Actions"
      log_error "token, or a fine-grained PAT scoped only to one repo) lacks the"
      log_error "owner-level permission needed to create new repos."
      log_error ""
      log_error "Fix: re-run with a personal token that has owner-level repo-create"
      log_error "scope, e.g.:"
      log_error "  BOOTSTRAP_GH_TOKEN=<your personal PAT> SANDBOX_PAT=<...> \\"
      log_error "    ./scripts/sandbox-bootstrap.sh"
      log_error ""
      log_error "Required scopes: classic 'repo' (and 'admin:org' if creating under"
      log_error "an org), OR fine-grained on your user account with Administration:"
      log_error "R/W, Contents: R/W, Metadata: R at the **account** level."
    fi
    exit 1
  fi
  rm -f /tmp/sandbox-bootstrap-create.err
  log_info "Created ${SANDBOX_REPO}."
fi

# ── Step 3: Mirror upstream main into sandbox ───────────────────────────────

log_step "Mirroring upstream into sandbox"

MIRROR_PARENT=$(mktemp -d)
MIRROR_DIR="${MIRROR_PARENT}/upstream.git"
trap 'rm -rf "$MIRROR_PARENT"' EXIT

git clone --bare "$UPSTREAM_URL" "$MIRROR_DIR" >/dev/null 2>&1
# Use a credential helper that injects $GH_TOKEN as the password so the
# mirror push uses the same token as the rest of the bootstrap (matters
# when BOOTSTRAP_GH_TOKEN is set to override the default gh auth).
if ! git -C "$MIRROR_DIR" \
  -c "credential.helper=!f() { echo \"username=x-access-token\"; echo \"password=${GH_TOKEN:-$(gh auth token)}\"; }; f" \
  push --mirror "https://github.com/${SANDBOX_REPO}.git" >/dev/null 2>&1; then
  log_error "Mirror push to ${SANDBOX_REPO} failed. Check that the auth token has 'Contents: R/W' on the sandbox repo."
  exit 1
fi
log_info "Mirror push complete."

# ── Step 4: Set CLAUDE_PAT secret ───────────────────────────────────────────

log_step "Setting CLAUDE_PAT secret on sandbox repo"

# `gh secret set --body` reads the value from the flag; the secret never
# touches the shell history beyond the current process env. Use --body-file
# /dev/stdin if you'd rather pipe; both go through the same upload path.
printf '%s' "$SANDBOX_PAT" | gh secret set CLAUDE_PAT \
  --repo "$SANDBOX_REPO" \
  --body-file -
log_info "CLAUDE_PAT set."

# ── Step 5: (Optional) Set ANTHROPIC_API_KEY ────────────────────────────────

if [[ -n "${SANDBOX_ANTHROPIC_KEY:-}" ]]; then
  log_step "Setting ANTHROPIC_API_KEY secret on sandbox repo"
  printf '%s' "$SANDBOX_ANTHROPIC_KEY" | gh secret set ANTHROPIC_API_KEY \
    --repo "$SANDBOX_REPO" \
    --body-file -
  log_info "ANTHROPIC_API_KEY set."
else
  log_warn "SANDBOX_ANTHROPIC_KEY not set — skipping ANTHROPIC_API_KEY (sandbox claude.yml runs will be unavailable until set manually)."
fi

# ── Step 6: Add sandbox git remote ──────────────────────────────────────────

log_step "Adding '${SANDBOX_REMOTE}' git remote on this checkout"

SANDBOX_URL="https://github.com/${SANDBOX_REPO}.git"
if git remote get-url "$SANDBOX_REMOTE" >/dev/null 2>&1; then
  current_url=$(git remote get-url "$SANDBOX_REMOTE")
  if [[ "$current_url" == "$SANDBOX_URL" ]]; then
    log_info "Remote '${SANDBOX_REMOTE}' already configured."
  else
    log_warn "Remote '${SANDBOX_REMOTE}' points elsewhere (${current_url}); leaving untouched."
    log_warn "Run 'git remote set-url ${SANDBOX_REMOTE} ${SANDBOX_URL}' to repoint manually."
  fi
else
  git remote add "$SANDBOX_REMOTE" "$SANDBOX_URL"
  log_info "Remote added."
fi

# ── Done ────────────────────────────────────────────────────────────────────

log_step "Sandbox bootstrap complete"
git remote -v | grep -E "^(origin|${SANDBOX_REMOTE})" || true
echo
log_info "Next: see docs/guides/sandbox-verification.md § 'Per-PR verification flow'."
