#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_ROOT/.config/derived-repo-secrets.json"
TEMPLATE_REPO="mikejmckinney/ai-repo-template"
TARGET_REPO=""
VISIBILITY="private"
APPLY=false
REUSE=false

usage() {
  cat >&2 <<'EOF'
Usage: create-derived-repo.sh --repo OWNER/REPO [options]

Create a remote repository from mikejmckinney/ai-repo-template, synchronize
allowlisted Actions secrets from this process environment, and add the new
repository to matching selected Codespaces user secrets.

Options:
  --repo OWNER/REPO       Required destination repository.
  --visibility VALUE      private (default), public, or internal.
  --reuse                 Synchronize an existing repository after validation.
  --apply                 Perform mutations. The default is a redacted dry-run.
  --manifest PATH         Override the credential manifest.
  -h, --help              Show this help.
EOF
}

die() {
  printf 'derived-repo: error: %s\n' "$*" >&2
  exit 1
}

status() {
  printf 'derived-repo: %s\n' "$*"
}

while (($# > 0)); do
  case "$1" in
    --repo)
      (($# >= 2)) || die "--repo requires OWNER/REPO"
      TARGET_REPO="$2"
      shift 2
      ;;
    --visibility)
      (($# >= 2)) || die "--visibility requires private, public, or internal"
      VISIBILITY="$2"
      shift 2
      ;;
    --reuse)
      REUSE=true
      shift
      ;;
    --apply)
      APPLY=true
      shift
      ;;
    --manifest)
      (($# >= 2)) || die "--manifest requires a path"
      MANIFEST="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      die "unknown argument: $1"
      ;;
  esac
done

[[ "$TARGET_REPO" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] \
  || die "--repo must use OWNER/REPO format"
case "$VISIBILITY" in
  private | public | internal) ;;
  *) die "unsupported visibility: $VISIBILITY" ;;
esac
[[ -f "$MANIFEST" ]] || die "manifest not found: $MANIFEST"
command -v jq >/dev/null 2>&1 || die "jq is required"

jq -e '
  .schema_version == 1 and
  (.secrets | type == "array" and length > 0) and
  ([.secrets[].name] | length == (unique | length)) and
  all(.secrets[];
    (.name | type == "string" and test("^[A-Z][A-Z0-9_]+$")) and
    (.env | type == "string" and test("^[A-Z][A-Z0-9_]+$")) and
    (.required | type == "boolean") and
    (.actions | type == "boolean") and
    (.codespaces | type == "boolean") and
    (.consumers | type == "array" and length > 0)
  ) and
  ([.secrets[] | select(.env == "REPO_BOOTSTRAP_TOKEN")] | length == 1) and
  all(.secrets[] | select(.env == "REPO_BOOTSTRAP_TOKEN");
    .name == "REPO_BOOTSTRAP_TOKEN" and .actions == false and .codespaces == false
  )
' "$MANIFEST" >/dev/null || die "invalid credential manifest: $MANIFEST"

status "Target: $TARGET_REPO"
status "Template: $TEMPLATE_REPO"
status "Visibility: $VISIBILITY"

required_missing=0
while IFS= read -r item; do
  name="$(jq -r '.name' <<<"$item")"
  env_name="$(jq -r '.env' <<<"$item")"
  required="$(jq -r '.required' <<<"$item")"
  actions="$(jq -r '.actions' <<<"$item")"
  codespaces="$(jq -r '.codespaces' <<<"$item")"
  derive="$(jq -r '.derive // empty' <<<"$item")"
  value="${!env_name-}"

  if [[ "$actions" == true ]]; then
    if [[ -n "$value" ]]; then
      status "Actions $name: available"
    elif [[ "$derive" == "opencode-oauth" && -f "${HOME:-}/.local/share/opencode/auth.json" ]]; then
      status "Actions $name: locally derivable"
    elif [[ "$required" == true ]]; then
      status "Actions $name: MISSING (required)"
      required_missing=$((required_missing + 1))
    else
      status "Actions $name: missing (optional)"
    fi
  fi
  if [[ "$codespaces" == true ]]; then
    status "Codespaces $name: visibility check planned"
  fi
done < <(jq -c '.secrets[]' "$MANIFEST")

if [[ "$APPLY" != true ]]; then
  status "Dry-run only; pass --apply to create or synchronize the repository."
  [[ "$required_missing" -eq 0 ]] || exit 1
  exit 0
fi

[[ "$required_missing" -eq 0 ]] \
  || die "$required_missing required Actions secret value(s) are unavailable"
[[ -n "${REPO_BOOTSTRAP_TOKEN:-}" ]] \
  || die "REPO_BOOTSTRAP_TOKEN is required with repository and codespace:secrets access"
command -v gh >/dev/null 2>&1 || die "gh is required for --apply"

export GH_TOKEN="$REPO_BOOTSTRAP_TOKEN"
unset GITHUB_TOKEN
gh auth status >/dev/null 2>&1 \
  || die "REPO_BOOTSTRAP_TOKEN was rejected by GitHub"

codespaces_json="$(gh api 'user/codespaces/secrets?per_page=100' 2>/dev/null)" \
  || die "REPO_BOOTSTRAP_TOKEN needs codespace or codespace:secrets access"

repo_exists=false
if gh repo view "$TARGET_REPO" --json id,nameWithOwner >/dev/null 2>&1; then
  repo_exists=true
fi

if [[ "$repo_exists" == true && "$REUSE" != true ]]; then
  die "$TARGET_REPO already exists; pass --reuse to synchronize it explicitly"
fi

if [[ "$repo_exists" != true ]]; then
  gh repo create "$TARGET_REPO" --template "$TEMPLATE_REPO" "--$VISIBILITY" >/dev/null
  status "Created $TARGET_REPO from $TEMPLATE_REPO."
else
  status "Reusing existing repository $TARGET_REPO."
fi

repo_json="$(gh api "repos/$TARGET_REPO")" \
  || die "could not read destination repository metadata"
repo_id="$(jq -r '.id // empty' <<<"$repo_json")"
[[ "$repo_id" =~ ^[0-9]+$ ]] || die "destination repository id is unavailable"

if [[ "$repo_exists" == true ]]; then
  existing_visibility="$(jq -r '.visibility // empty' <<<"$repo_json")"
  case "$existing_visibility" in
    private | public | internal) VISIBILITY="$existing_visibility" ;;
    *) die "$TARGET_REPO returned unsupported visibility: $existing_visibility" ;;
  esac
  status "Existing repository visibility: $VISIBILITY"
  recorded_template="$(jq -r '.template_repository.full_name // empty' <<<"$repo_json")"
  if [[ -n "$recorded_template" && "$recorded_template" != "$TEMPLATE_REPO" ]]; then
    die "$TARGET_REPO records a different template: $recorded_template"
  fi
  if [[ -z "$recorded_template" ]]; then
    status "Existing repository template ancestry is unavailable; --reuse is the explicit authorization."
  fi
fi

actions_updated=0
actions_skipped=0
while IFS= read -r item; do
  name="$(jq -r '.name' <<<"$item")"
  env_name="$(jq -r '.env' <<<"$item")"
  actions="$(jq -r '.actions' <<<"$item")"
  derive="$(jq -r '.derive // empty' <<<"$item")"
  [[ "$actions" == true ]] || continue
  value="${!env_name-}"

  if [[ -n "$value" ]]; then
    printf '%s' "$value" | gh secret set "$name" --repo "$TARGET_REPO" --app actions
    status "Actions $name: updated"
    actions_updated=$((actions_updated + 1))
  elif [[ "$derive" == "opencode-oauth" && -f "${HOME:-}/.local/share/opencode/auth.json" ]]; then
    bash "$SCRIPT_DIR/sync-opencode-oauth-secret.sh" --apply --repo "$TARGET_REPO" >/dev/null
    status "Actions $name: derived and updated"
    actions_updated=$((actions_updated + 1))
  else
    status "Actions $name: skipped (value unavailable)"
    actions_skipped=$((actions_skipped + 1))
  fi
done < <(jq -c '.secrets[]' "$MANIFEST")

codespaces_granted=0
codespaces_skipped=0
while IFS= read -r item; do
  name="$(jq -r '.name' <<<"$item")"
  codespaces="$(jq -r '.codespaces' <<<"$item")"
  [[ "$codespaces" == true ]] || continue
  visibility="$(jq -r --arg name "$name" '.secrets[] | select(.name == $name) | .visibility' <<<"$codespaces_json")"
  case "$visibility" in
    selected)
      gh api --method PUT "user/codespaces/secrets/$name/repositories/$repo_id" >/dev/null
      status "Codespaces $name: repository granted"
      codespaces_granted=$((codespaces_granted + 1))
      ;;
    all)
      status "Codespaces $name: already covered by $visibility visibility"
      codespaces_skipped=$((codespaces_skipped + 1))
      ;;
    private)
      if [[ "$VISIBILITY" == private ]]; then
        status "Codespaces $name: already covered by private visibility"
      else
        status "Codespaces $name: private visibility does not cover a $VISIBILITY repository"
      fi
      codespaces_skipped=$((codespaces_skipped + 1))
      ;;
    "")
      status "Codespaces $name: secret not configured for this user"
      codespaces_skipped=$((codespaces_skipped + 1))
      ;;
    *) die "Codespaces $name returned unsupported visibility: $visibility" ;;
  esac
done < <(jq -c '.secrets[]' "$MANIFEST")

status "Complete: actions_updated=$actions_updated actions_skipped=$actions_skipped codespaces_granted=$codespaces_granted codespaces_skipped=$codespaces_skipped"
