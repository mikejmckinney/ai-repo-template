#!/usr/bin/env bash
# Run each OpenCode fix model in a disposable worktree and promote only success.
set -euo pipefail

PROMPT_FILE="${1:-}"
OUTPUT_FILE="${2:-}"
REPO_ROOT="${3:-}"
[[ -n "$PROMPT_FILE" && -n "$OUTPUT_FILE" && -n "$REPO_ROOT" ]] || {
  echo "Usage: run-opencode-fix.sh <prompt-file> <output-file> <repo-root>" >&2
  exit 2
}

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${OPENCODE_RUNNER:-$LIB_DIR/run-opencode.mjs}"
MODELS="${OPENCODE_MODELS:-openrouter/z-ai/glm-5.2@preset/default,openrouter/minimax/minimax-m3@preset/default}"
VERIFY_COMMAND="${OPENCODE_FIX_VERIFY_COMMAND:-./test.sh}"
ATTEMPT_ROOT="$(mktemp -d)"
active_worktree=""

cleanup() {
  if [[ -n "$active_worktree" ]]; then
    git -C "$REPO_ROOT" worktree remove --force "$active_worktree" >/dev/null 2>&1 || true
  fi
  rm -rf "$ATTEMPT_ROOT"
}
trap cleanup EXIT

IFS=',' read -r -a models <<<"$MODELS"
for model in "${models[@]}"; do
  model="${model#"${model%%[![:space:]]*}"}"
  model="${model%"${model##*[![:space:]]}"}"
  [[ -n "$model" ]] || continue
  active_worktree="$ATTEMPT_ROOT/worktree-${RANDOM}"
  attempt_output="$ATTEMPT_ROOT/output-${RANDOM}.txt"
  patch_file="$ATTEMPT_ROOT/attempt.patch"
  git -C "$REPO_ROOT" worktree add --detach "$active_worktree" HEAD >/dev/null

  if (
    cd "$active_worktree"
    env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
      OPENCODE_MODE=fix OPENCODE_MODELS="$model" \
      node "$RUNNER" "$PROMPT_FILE" "$attempt_output" "${OPENCODE_OUTPUT_SCHEMA:-}"
  ); then
    if ! (
      cd "$active_worktree"
      env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
        -u OPENCODE_GITHUB_TOKEN -u OPENAI_API_KEY -u OPENROUTER_API_KEY \
        -u CURSOR_API_KEY -u GEMINI_API_KEY -u GOOGLE_API_KEY \
        bash -c "$VERIFY_COMMAND"
    ); then
      echo "::warning::Discarding unverified OpenCode fix attempt for ${model}" >&2
      git -C "$REPO_ROOT" worktree remove --force "$active_worktree" >/dev/null
      active_worktree=""
      continue
    fi
    git -C "$active_worktree" add -N -- . >/dev/null 2>&1 || true
    git -C "$active_worktree" diff --binary --full-index >"$patch_file"
    if [[ -s "$patch_file" ]]; then
      git -C "$REPO_ROOT" apply "$patch_file"
    fi
    cp "$attempt_output" "$OUTPUT_FILE"
    git -C "$REPO_ROOT" worktree remove --force "$active_worktree" >/dev/null
    active_worktree=""
    echo "OpenCode fix promoted from ${model}" >&2
    exit 0
  fi

  echo "::warning::Discarding failed OpenCode fix attempt for ${model}" >&2
  git -C "$REPO_ROOT" worktree remove --force "$active_worktree" >/dev/null
  active_worktree=""
done

echo "::error::OpenCode fix model cascade exhausted" >&2
exit 1
