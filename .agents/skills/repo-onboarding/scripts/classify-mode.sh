#!/usr/bin/env bash

set -euo pipefail

REPO="$PWD"

fail() {
  printf 'repo-onboarding classify: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -d "$REPO/.git" || -f "$REPO/.git" ]] || fail "--repo must be a Git worktree"
REPO="$(cd "$REPO" && pwd)"
remote=$(git -C "$REPO" remote get-url origin 2>/dev/null || true)
remote_normalized="${remote,,}"
remote_normalized="${remote_normalized%/}"
identity="${remote:-$(basename "$REPO")}"
state_file="$REPO/.context/onboarding-state.json"
warnings=()

if [[ "$remote_normalized" =~ ^(https?://github\.com/|ssh://git@github\.com/|git@github\.com:|git://github\.com/)mikejmckinney/(ai-repo-template|dotfiles)(\.git)?$ ]]; then
  mode=ai-repo-template
  requires_onboarding=false
elif [[ ! -e "$state_file" ]]; then
  mode=complete
  requires_onboarding=false
  warnings+=("legacy derived repository has no .context/onboarding-state.json; treating it as complete until state is backfilled")
else
  if ! jq -e '
    type == "object" and
    .schema_version == 1 and
    .template == "mikejmckinney/ai-repo-template" and
    (.status == "template-seed" or .status == "complete")
  ' "$state_file" >/dev/null 2>&1; then
    fail "invalid onboarding state in .context/onboarding-state.json"
  fi
  mode=$(jq -r '.status' "$state_file")
  if [[ "$mode" == template-seed ]]; then
    requires_onboarding=true
  else
    requires_onboarding=false
  fi
fi

if [[ ${#warnings[@]} -eq 0 ]]; then
  warnings_json='[]'
else
  warnings_json=$(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s .)
fi
jq -n \
  --arg status success \
  --arg mode "$mode" \
  --arg repository "$REPO" \
  --arg identity "$identity" \
  --argjson requires_onboarding "$requires_onboarding" \
  --argjson warnings "$warnings_json" \
  '{status: $status, mode: $mode, repository: $repository,
    identity: $identity, requires_onboarding: $requires_onboarding,
    warnings: $warnings}'
