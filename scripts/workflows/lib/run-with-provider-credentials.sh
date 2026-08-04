#!/usr/bin/env bash
set -euo pipefail

provider="${1:?usage: run-with-provider-credentials.sh <provider> <command> [args...]}"
shift

case "$provider" in
  claude)
    exec env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
      -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN \
      -u OPENCODE_GITHUB_TOKEN -u OPENCODE_AUTH_CONTENT -u OPENAI_API_KEY \
      -u OPENROUTER_API_KEY -u CURSOR_API_KEY -u GEMINI_API_KEY -u GOOGLE_API_KEY \
      "$@"
    ;;
  opencode | opencode-sol | opencode-kimi)
    exec env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
      -u ADVISORY_GITHUB_TOKEN \
      -u CLAUDE_CODE_OAUTH_TOKEN -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN \
      -u CURSOR_API_KEY -u GEMINI_API_KEY -u GOOGLE_API_KEY -u OPENAI_API_KEY \
      "$@"
    ;;
  cursor)
    exec env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
      -u CLAUDE_CODE_OAUTH_TOKEN -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN \
      -u OPENCODE_GITHUB_TOKEN -u OPENCODE_AUTH_CONTENT -u OPENAI_API_KEY \
      -u OPENROUTER_API_KEY -u GEMINI_API_KEY -u GOOGLE_API_KEY \
      "$@"
    ;;
  gemini)
    exec env -u GITHUB_TOKEN -u GH_TOKEN -u SANDBOX_BOOTSTRAP_TOKEN \
      -u ADVISORY_GITHUB_TOKEN \
      -u CLAUDE_CODE_OAUTH_TOKEN -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN \
      -u OPENCODE_GITHUB_TOKEN -u OPENCODE_AUTH_CONTENT -u OPENAI_API_KEY \
      -u OPENROUTER_API_KEY -u CURSOR_API_KEY \
      "$@"
    ;;
  *)
    echo "::error::run-with-provider-credentials: unsupported provider '${provider}'" >&2
    exit 1
    ;;
esac
