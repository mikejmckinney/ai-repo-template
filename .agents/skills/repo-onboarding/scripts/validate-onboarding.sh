#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$PWD"

fail() {
  printf 'repo-onboarding validate: %s\n' "$*" >&2
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
classification=$("$SCRIPT_DIR/classify-mode.sh" --repo "$REPO")
mode=$(jq -r '.mode' <<<"$classification")
blocking=()
warnings=()

while IFS= read -r warning; do
  warnings+=("$warning")
done < <(jq -r '.warnings[]' <<<"$classification")

if [[ "$mode" == template-seed ]]; then
  blocking+=("repository onboarding state is template-seed; explicit authorization is required")
fi

if [[ "$mode" != ai-repo-template ]]; then
  for required in README.md AI_REPO_GUIDE.md .context/00_INDEX.md; do
    [[ -f "$REPO/$required" ]] || blocking+=("required onboarding file missing: $required")
  done
fi

for optional in .context/roadmap.md .context/vision/README.md; do
  [[ -f "$REPO/$optional" ]] || warnings+=("optional orientation file missing: $optional")
done

if [[ -x "$REPO/scripts/verify-env.sh" ]]; then
  verify_log=$(mktemp "${TMPDIR:-/tmp}/repo-onboarding-verify.XXXXXX")
  if ! (cd "$REPO" && ./scripts/verify-env.sh) >"$verify_log" 2>&1; then
    blocking+=("scripts/verify-env.sh exited nonzero")
  fi
  rm -f "$verify_log"
else
  warnings+=("scripts/verify-env.sh is unavailable; environment stability was not checked")
fi

if [[ ${#blocking[@]} -eq 0 ]]; then
  blocking_json='[]'
  stable=true
else
  blocking_json=$(printf '%s\n' "${blocking[@]}" | jq -R . | jq -s .)
  stable=false
fi
if [[ ${#warnings[@]} -eq 0 ]]; then
  warnings_json='[]'
else
  warnings_json=$(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s .)
fi

jq -n \
  --arg status success \
  --arg mode "$mode" \
  --argjson stable "$stable" \
  --argjson blocking_findings "$blocking_json" \
  --argjson warnings "$warnings_json" \
  '{status: $status, mode: $mode, stable: $stable,
    blocking_findings: $blocking_findings, warnings: $warnings}'

[[ "$stable" == true ]]
