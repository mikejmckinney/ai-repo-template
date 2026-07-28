#!/usr/bin/env bash
set -euo pipefail
umask 077

AUTH_FILE="${HOME}/.local/share/opencode/auth.json"
REPO=""
SECRET_NAME="OPENCODE_OPENAI_AUTH"
APPLY=false

usage() {
  cat >&2 <<'EOF'
Usage: sync-opencode-oauth-secret.sh [--apply] [--auth-file PATH] [--repo OWNER/REPO]

Dry-run by default. Uploads an access-only OpenCode OAuth bundle to the
OPENCODE_OPENAI_AUTH Actions secret when --apply is supplied.
EOF
}

while (($#)); do
  case "$1" in
    --apply)
      APPLY=true
      shift
      ;;
    --auth-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      AUTH_FILE="$2"
      shift 2
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

[[ -f "$AUTH_FILE" ]] || {
  echo "OpenCode auth file not found: $AUTH_FILE" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "jq is required" >&2
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

payload="$(jq -c -e '
  .openai as $auth |
  if (
    $auth.type == "oauth" and
    ($auth.access | type == "string" and length > 0) and
    ($auth.refresh | type == "string" and length > 0) and
    ($auth.expires | type == "number") and
    ($auth.accountId | type == "string" and length > 0)
  ) then {
    openai: {
      type: "oauth",
      access: $auth.access,
      refresh: "ci-refresh-disabled",
      expires: ($auth.expires | floor),
      accountId: $auth.accountId
    }
  } else error("OpenAI OAuth entry is incomplete") end
' "$AUTH_FILE")" || {
  echo "OpenCode auth file does not contain a complete OpenAI OAuth entry" >&2
  exit 1
}

expires="$(jq -r '.openai.expires' <<<"$payload")"
now_ms="$(($(date +%s) * 1000))"
remaining_seconds="$(((expires - now_ms) / 1000))"
expiration_utc="$(date -u -d "@$((expires / 1000))" +%Y-%m-%dT%H:%M:%SZ)"

if ((remaining_seconds <= 0)); then
  echo "OpenCode OAuth access token is expired; authenticate with OpenCode before synchronization." >&2
  exit 1
fi

printf 'Repository: %s\nSecret: %s\nExpires: %s\nRemaining seconds: %s\n' \
  "$REPO" "$SECRET_NAME" "$expiration_utc" "$remaining_seconds"

if [[ "$APPLY" != true ]]; then
  echo "Dry-run only; pass --apply to update the Actions secret."
  exit 0
fi

command -v gh >/dev/null 2>&1 || {
  echo "gh is required for --apply" >&2
  exit 1
}
printf '%s' "$payload" | gh secret set "$SECRET_NAME" --repo "$REPO"
echo "Updated ${SECRET_NAME} for ${REPO}."
