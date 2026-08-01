#!/usr/bin/env bash
set -euo pipefail
umask 077

REPO=""
SECRET_NAME="CLAUDE_OAUTH_SECRET"
APPLY=false

usage() {
  cat >&2 <<'EOF'
Usage: sync-claude-oauth-secret.sh [--apply] [--repo OWNER/REPO]

Dry-run by default. Reads CLAUDE_CODE_OAUTH_TOKEN or prompts silently on a
terminal, then updates the CLAUDE_OAUTH_SECRET Actions secret with --apply.
Generate the token first with: claude setup-token
EOF
}

while (($#)); do
  case "$1" in
    --apply)
      APPLY=true
      shift
      ;;
    --repo)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      REPO="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

token="${CLAUDE_CODE_OAUTH_TOKEN:-}"
if [[ -z "$token" && -t 0 ]]; then
  read -r -s -p "Claude Code OAuth token: " token
  printf '\n' >&2
fi
[[ -n "$token" ]] || {
  echo "Run claude setup-token, then set CLAUDE_CODE_OAUTH_TOKEN or rerun from a terminal for a hidden prompt." >&2
  exit 1
}

if [[ -z "$REPO" ]]; then
  command -v gh >/dev/null 2>&1 || {
    echo "gh is required when --repo is omitted" >&2
    exit 1
  }
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi
[[ "$REPO" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] || {
  echo "Invalid repository: $REPO" >&2
  exit 2
}

printf 'Repository: %s\nSecret: %s\n' "$REPO" "$SECRET_NAME"
if [[ "$APPLY" != true ]]; then
  echo "Dry-run only; pass --apply to update the Actions secret."
  exit 0
fi

command -v gh >/dev/null 2>&1 || {
  echo "gh is required for --apply" >&2
  exit 1
}
printf '%s' "$token" | gh secret set "$SECRET_NAME" --repo "$REPO"
echo "Updated ${SECRET_NAME} for ${REPO}."
