#!/usr/bin/env bash
set -euo pipefail

PROMPT_FILE="${1:-}"
OUTPUT_FILE="${2:-}"
REPO_ROOT="${3:-}"
[[ -n "$PROMPT_FILE" && -n "$OUTPUT_FILE" && -n "$REPO_ROOT" ]] || {
  echo "Usage: run-cursor-fix.sh <prompt-file> <output-file> <repo-root>" >&2
  exit 2
}

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${CURSOR_FIX_RUNNER:-$LIB_DIR/../advisory-review/run-advisory-cursor.mjs}"
VERIFY_COMMAND="${CURSOR_FIX_VERIFY_COMMAND:-./test.sh}"
ATTEMPT_ROOT="$(mktemp -d)"
active_worktree="$ATTEMPT_ROOT/worktree"

cleanup() {
  if [[ -d "$active_worktree" ]] && ! git -C "$REPO_ROOT" worktree remove --force "$active_worktree" >/dev/null 2>&1; then
    echo "::warning::Could not remove Cursor fix worktree: $active_worktree" >&2
  fi
  rm -rf "$ATTEMPT_ROOT"
}
trap cleanup EXIT

attempt_output="$ATTEMPT_ROOT/output.txt"
patch_file="$ATTEMPT_ROOT/attempt.patch"
git -C "$REPO_ROOT" worktree add --detach "$active_worktree" HEAD >/dev/null

if ! (
  cd "$active_worktree"
  env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN -u OPENCODE_AUTH_CONTENT \
    -u OPENCODE_GITHUB_TOKEN -u OPENAI_API_KEY -u OPENROUTER_API_KEY \
    -u GEMINI_API_KEY -u GOOGLE_API_KEY \
    node "$RUNNER" "$PROMPT_FILE" "$attempt_output"
); then
  echo "::error::Cursor fix attempt failed" >&2
  exit 1
fi

if ! (
  cd "$active_worktree"
  env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
    -u OPENCODE_GITHUB_TOKEN -u OPENCODE_AUTH_CONTENT -u OPENAI_API_KEY \
    -u OPENROUTER_API_KEY -u CURSOR_API_KEY -u GEMINI_API_KEY -u GOOGLE_API_KEY \
    bash -c "$VERIFY_COMMAND"
); then
  echo "::error::Discarding unverified Cursor fix attempt" >&2
  exit 1
fi

if ! git -C "$active_worktree" add -N -- . >/dev/null 2>&1; then
  echo "::warning::Cursor fix worktree contains no paths to stage for diff detection" >&2
fi
git -C "$active_worktree" diff --binary --full-index >"$patch_file"
if [[ -s "$patch_file" ]]; then
  git -C "$REPO_ROOT" apply "$patch_file"
fi
cp "$attempt_output" "$OUTPUT_FILE"
git -C "$REPO_ROOT" worktree remove --force "$active_worktree" >/dev/null
active_worktree=""
echo "Cursor fix promoted after verification" >&2
