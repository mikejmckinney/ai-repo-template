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
identity="${remote:-$(basename "$REPO")}"
signals=()

contains_pattern() {
  local pattern="$1"
  shift
  grep -qE "$pattern" "$@" 2>/dev/null
}

if contains_pattern 'TEMPLATE_PLACEHOLDER' "$REPO/README.md" "$REPO/AI_REPO_GUIDE.md"; then
  signals+=("primary documentation contains TEMPLATE_PLACEHOLDER")
fi
if contains_pattern 'PLEASE_UPDATE_THIS/URL' "$REPO/.github/ISSUE_TEMPLATE/config.yml"; then
  signals+=("issue template contains placeholder URL")
fi
tick='`'
context_identity_pattern="\\*\\*Project Name\\*\\*:[[:space:]]*${tick}?ai-repo-template${tick}?|A Codespaces-first repository template for AI-assisted software delivery"
if contains_pattern "$context_identity_pattern" "$REPO/.context/00_INDEX.md"; then
  signals+=("context index still describes ai-repo-template")
fi
if contains_pattern '^# ai-repo-template Roadmap' "$REPO/.context/roadmap.md"; then
  signals+=("roadmap still describes ai-repo-template")
fi
if contains_pattern 'template repo.s design and workflow diagrams|process/template project' "$REPO/.context/vision/README.md"; then
  signals+=("vision still describes the template repository")
fi
if [[ -e "$REPO/.context/vision/architecture/multi-agent-flow.md" ||
  -e "$REPO/.context/vision/architecture/state-surfaces.md" ]]; then
  signals+=("template-only architecture diagrams remain")
fi
if [[ -x "$REPO/scripts/verify-env.sh" ]]; then
  verify_output=$(cd "$REPO" && ./scripts/verify-env.sh 2>&1 || true)
  if printf '%s\n' "$verify_output" | grep -qE '[1-9][0-9]* files still contain TEMPLATE_PLACEHOLDER'; then
    signals+=("verify-env reports unresolved template placeholders")
  fi
fi

if printf '%s\n' "$identity" | grep -qE '(^|[:/])(mikejmckinney/)?(ai-repo-template|dotfiles)(\.git)?$'; then
  mode=A
  requires_bootstrap=false
elif [[ ${#signals[@]} -gt 0 ]]; then
  mode=B
  requires_bootstrap=true
else
  mode=C
  requires_bootstrap=false
fi

if [[ ${#signals[@]} -eq 0 ]]; then
  signals_json='[]'
else
  signals_json=$(printf '%s\n' "${signals[@]}" | jq -R . | jq -s .)
fi
jq -n \
  --arg status success \
  --arg mode "$mode" \
  --arg repository "$REPO" \
  --arg identity "$identity" \
  --argjson requires_bootstrap "$requires_bootstrap" \
  --argjson signals "$signals_json" \
  '{status: $status, mode: $mode, repository: $repository,
    identity: $identity, requires_bootstrap: $requires_bootstrap,
    signals: $signals}'
