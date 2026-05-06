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
#                         cannot create repos under your owner namespace.
#
#                         RECOMMENDED: a CLASSIC personal token (ghp_...)
#                         with 'repo' AND 'workflow' scopes. Generate at:
#                           https://github.com/settings/tokens/new
#                         ('workflow' is required to push .github/workflows/
#                         files; 'repo' alone is not sufficient.)
#
#                         Fine-grained PATs (github_pat_...) will also
#                         work IF scoped to 'All repositories' (resource-
#                         owner level) with Administration: R/W + Contents:
#                         R/W + Metadata: R. Fine-grained tokens scoped to
#                         specific repos CANNOT create new repos and will
#                         fail the mirror push with 403 'Write access not
#                         granted' because the sandbox repo does not exist
#                         at token-mint time.
#
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
    if [[ "$err" == *"Resource not accessible"* ]] \
      || [[ "$err" == *"createRepository"* ]] \
      || [[ "$err" == *"403"* ]]; then
      log_error ""
      log_error "Repo creation requires an auth token with owner-level scope."
      log_error "The auto-provisioned Codespaces/Actions GITHUB_TOKEN can't create"
      log_error "repos outside its current repo. Fine-grained PATs can only create"
      log_error "repos when scoped to 'All repositories' with Administration:R/W —"
      log_error "these restrictions make classic PATs the simplest choice here."
      log_error ""
      log_error "Recommended fix: mint a CLASSIC personal token at:"
      log_error "  https://github.com/settings/tokens/new"
      log_error "Check the 'repo' scope (one box). Then re-run:"
      log_error "  BOOTSTRAP_GH_TOKEN=ghp_<classic PAT> SANDBOX_PAT=<...> \\"
      log_error "    ./scripts/sandbox-bootstrap.sh"
      log_error ""
      log_error "If you want to use a fine-grained PAT instead, it must be"
      log_error "resource-owner-level (All repositories) with:"
      log_error "  Administration: R/W, Contents: R/W, Metadata: R"
      log_error "Fine-grained tokens scoped to specific repos will always fail here"
      log_error "because the sandbox repo does not yet exist when the token is minted."
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

if ! git clone --bare "$UPSTREAM_URL" "$MIRROR_DIR" 2>/tmp/sandbox-clone.err; then
  log_error "Bare clone of upstream failed:"
  while IFS= read -r _line; do log_error "  ${_line}"; done </tmp/sandbox-clone.err
  rm -f /tmp/sandbox-clone.err
  exit 1
fi
rm -f /tmp/sandbox-clone.err

# Build a minimal GIT_ASKPASS helper that returns the bootstrap token as the
# HTTPS password. Writing it to a temp file avoids passing the token through
# git -c (which embeds it in quoting that varies by shell) and avoids putting
# it on the push URL (where it may surface in git error messages).
#
# ASKPASS contract: git calls the script with the prompt text as $1 and reads
# the credential from stdout. When the URL contains "x-access-token" as the
# user, git only asks for the password, so a single-value helper is sufficient.
_TOK_FILE="$(mktemp)"
_ASKPASS="$(mktemp)"
chmod 600 "$_TOK_FILE"
chmod 700 "$_ASKPASS"
printf '%s\n' "${GH_TOKEN:-$(gh auth token)}" >"$_TOK_FILE"
printf '#!/bin/sh\ncat "%s"\n' "$_TOK_FILE" >"$_ASKPASS"

if ! GIT_ASKPASS="$_ASKPASS" \
  git -C "$MIRROR_DIR" \
  -c credential.helper= \
  push --mirror \
  "https://x-access-token@github.com/${SANDBOX_REPO}.git" \
  2>/tmp/sandbox-mirror-push.err; then
  _err=$(cat /tmp/sandbox-mirror-push.err)
  rm -f "$_TOK_FILE" "$_ASKPASS" /tmp/sandbox-mirror-push.err
  log_error "Mirror push to ${SANDBOX_REPO} failed:"
  while IFS= read -r _line; do log_error "  ${_line}"; done <<<"$_err"
  log_error ""
  if [[ "$_err" == *"workflow"*"scope"* ]]; then
    log_error "The token is missing 'workflow' scope. Classic PATs require BOTH"
    log_error "'repo' AND 'workflow' scopes to push .github/workflows/ files."
    log_error "Edit your token at https://github.com/settings/tokens and add"
    log_error "the 'workflow' checkbox, then re-run."
  else
    log_error "This is usually a token-scope problem. Possible causes:"
    log_error "  1. Fine-grained PAT scoped to SPECIFIC repos — '${SANDBOX_REPO##*/}'"
    log_error "     was just created and was not in scope when the token was minted."
    log_error "     Fine-grained PATs do NOT auto-include repos created after minting."
    log_error "  2. The token lacks 'Contents: R/W' permission entirely."
    log_error ""
    log_error "Recommended fix: use a CLASSIC personal token (ghp_...) with 'repo'"
    log_error "AND 'workflow' scopes for BOOTSTRAP_GH_TOKEN. Generate one at:"
    log_error "  https://github.com/settings/tokens/new"
    log_error ""
    log_error "If you must use fine-grained: edit the token at"
    log_error "  https://github.com/settings/tokens"
    log_error "and either (a) switch resource owner to 'All repositories' with"
    log_error "Contents: R/W, or (b) explicitly add ${SANDBOX_REPO} to its repo list."
  fi
  exit 1
fi
rm -f "$_TOK_FILE" "$_ASKPASS"
rm -f /tmp/sandbox-mirror-push.err
log_info "Mirror push complete."

# ── Step 4: Set CLAUDE_PAT secret ───────────────────────────────────────────

log_step "Setting CLAUDE_PAT secret on sandbox repo"

# Pipe the secret value via stdin — gh reads from stdin when no --body
# flag is given. This keeps the value out of argv (process listings,
# shell history, error messages).
printf '%s' "$SANDBOX_PAT" | gh secret set CLAUDE_PAT \
  --repo "$SANDBOX_REPO"
log_info "CLAUDE_PAT set."

# ── Step 5: (Optional) Set ANTHROPIC_API_KEY ────────────────────────────────

if [[ -n "${SANDBOX_ANTHROPIC_KEY:-}" ]]; then
  log_step "Setting ANTHROPIC_API_KEY secret on sandbox repo"
  printf '%s' "$SANDBOX_ANTHROPIC_KEY" | gh secret set ANTHROPIC_API_KEY \
    --repo "$SANDBOX_REPO"
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
