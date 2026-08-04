#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/create-derived-repo.sh"
  MANIFEST="$REPO_ROOT/.config/derived-repo-secrets.json"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/derived-repo-bootstrap.XXXXXX")"
  BIN_DIR="$TEST_ROOT/bin"
  GH_LOG="$TEST_ROOT/gh.log"
  PROVIDER_CODESPACES_SECRETS=(
    ACEDATACLOUD_API_TOKEN
    CLOUDFLARE_API_KEY
    CLOUDFLARE_GLOBAL_API_KEY
    ELEVENLABS_API_KEY
    GH_PAT
    MUREKA_API_KEY
    NETLIFY_API_KEY
    RAILWAY_API_KEY
    RENDER_API_KEY
    SUPABASE_API_KEY
    VERCEL_API_KEY
  )
  mkdir -p "$BIN_DIR"
  : >"$GH_LOG"

  cat >"$BIN_DIR/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$GH_LOG"
case "${1:-} ${2:-}" in
  "auth status") exit 0 ;;
  "repo view")
    if [[ "${GH_REPO_EXISTS:-false}" == true ]]; then
      printf '{"id":4242,"nameWithOwner":"acme/demo"}\n'
      exit 0
    fi
    exit 1
    ;;
  "repo create") exit 0 ;;
  "secret set")
    read -r _secret_value || true
    printf 'secret-value-bytes=%s\n' "${#_secret_value}" >>"$GH_LOG"
    exit 0
    ;;
  "api repos/acme/demo")
    printf '{"id":4242,"visibility":"%s","template_repository":{"full_name":"%s"}}\n' \
      "${GH_REPO_VISIBILITY:-private}" "${GH_TEMPLATE_REPO:-mikejmckinney/ai-repo-template}"
    ;;
  "api user/codespaces/secrets?per_page=100")
    [[ "${GH_CODESPACES_ACCESS:-true}" == true ]] || exit 1
    if [[ -n "${GH_CODESPACES_JSON:-}" ]]; then
      printf '%s\n' "$GH_CODESPACES_JSON"
      exit 0
    fi
    printf '%s\n' '{"secrets":[{"name":"OPENCODE_GITHUB_TOKEN","visibility":"selected"},{"name":"OPENROUTER_API_KEY","visibility":"all"},{"name":"CURSOR_API_KEY","visibility":"private"},{"name":"ACEDATACLOUD_API_TOKEN","visibility":"selected"},{"name":"CLOUDFLARE_API_KEY","visibility":"selected"},{"name":"CLOUDFLARE_GLOBAL_API_KEY","visibility":"selected"},{"name":"ELEVENLABS_API_KEY","visibility":"selected"},{"name":"GH_PAT","visibility":"selected"},{"name":"MUREKA_API_KEY","visibility":"selected"},{"name":"NETLIFY_API_KEY","visibility":"selected"},{"name":"RAILWAY_API_KEY","visibility":"selected"},{"name":"RENDER_API_KEY","visibility":"selected"},{"name":"SUPABASE_API_KEY","visibility":"selected"},{"name":"VERCEL_API_KEY","visibility":"selected"}]}'
    ;;
  "api user/codespaces/secrets/OPENCODE_GITHUB_TOKEN")
    printf 'selected\n'
    ;;
  "api user/codespaces/secrets/OPENROUTER_API_KEY")
    printf 'all\n'
    ;;
  "api user/codespaces/secrets/"*) exit 1 ;;
  "api --method") exit 0 ;;
  *)
    printf 'unexpected gh invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "$BIN_DIR/gh"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

run_bootstrap() {
  run env -i PATH="$BIN_DIR:$PATH" HOME="$TEST_ROOT/home" GH_LOG="$GH_LOG" \
    GH_REPO_EXISTS="${TEST_GH_REPO_EXISTS:-false}" \
    GH_CODESPACES_ACCESS="${TEST_GH_CODESPACES_ACCESS:-true}" \
    GH_CODESPACES_JSON="${TEST_GH_CODESPACES_JSON:-}" \
    GH_TEMPLATE_REPO="${TEST_GH_TEMPLATE_REPO:-mikejmckinney/ai-repo-template}" \
    GH_REPO_VISIBILITY="${TEST_GH_REPO_VISIBILITY:-private}" \
    REPO_BOOTSTRAP_TOKEN="${TEST_REPO_BOOTSTRAP_TOKEN:-}" \
    OPENCODE_GITHUB_TOKEN="${TEST_OPENCODE_GITHUB_TOKEN:-}" \
    OPENROUTER_API_KEY="${TEST_OPENROUTER_API_KEY:-}" \
    bash "$SCRIPT" --repo acme/demo "$@"
  printf 'status=%s\n%s\n' "$status" "$output" >&3
}

@test "credential manifest is explicit and never publishes the bootstrap token to Actions" {
  run jq -e '
    .schema_version == 1 and
    (.secrets | type == "array" and length > 0) and
    all(.secrets[];
      (.name | test("^[A-Z][A-Z0-9_]+$")) and
      (.env | test("^[A-Z][A-Z0-9_]+$")) and
      (.required | type == "boolean") and
      (.actions | type == "boolean") and
      (.codespaces | type == "boolean") and
      ((if has("bootstrap") then .bootstrap else true end) | type == "boolean") and
      (.consumers | type == "array" and length > 0)
    ) and
    ([.secrets[] | select(.name == "REPO_BOOTSTRAP_TOKEN" and .actions == false and .codespaces == false)] | length == 1) and
    ([.secrets[] | select(
      .name == "SKILL_REFRESH_PR_TOKEN" and
      .required == true and
      .actions == true and
      .codespaces == false and
      .bootstrap == false
    )] | length == 1) and
    ([.secrets[] | select(.name == "CLAUDE_OAUTH_SECRET")][0].consumers == [
      "pre-merge Claude advisory",
      "daily post-merge Claude analysis",
      "weekly Claude analysis"
    ])
  ' "$MANIFEST"
  [ "$status" -eq 0 ]
}

@test "provider credentials are Codespaces-only destinations" {
  for name in "${PROVIDER_CODESPACES_SECRETS[@]}"; do
    run jq -e --arg name "$name" '
      [.secrets[] | select(
        .name == $name and
        .env == $name and
        .required == false and
        .actions == false and
        .codespaces == true
      )] | length == 1
    ' "$MANIFEST"
    [ "$status" -eq 0 ]
  done
}

@test "credential guidance records destination and least-privilege boundaries" {
  run python3 - "$REPO_ROOT/AI_REPO_GUIDE.md" \
    "$REPO_ROOT/docs/guides/derived-repository-bootstrap.md" \
    "$REPO_ROOT/scripts/codespace-post-start.sh" <<'PY'
import sys
from pathlib import Path

repo_guide = " ".join(Path(sys.argv[1]).read_text(encoding="utf-8").split())
bootstrap_guide = " ".join(Path(sys.argv[2]).read_text(encoding="utf-8").split())
post_start = " ".join(Path(sys.argv[3]).read_text(encoding="utf-8").split())

assert "entries marked `codespaces: true` and `actions: false`" in repo_guide, "destination flags missing"
assert "`CLOUDFLARE_GLOBAL_API_KEY`" in bootstrap_guide, "global key warning missing"
assert "https://developers.cloudflare.com/fundamentals/api/get-started/keys/#limitations" in bootstrap_guide, "Cloudflare limitation source missing"
assert "fine-grained PAT restricted to the required upstream and sandbox repositories" in bootstrap_guide, "fine-grained GH_PAT guidance missing"
assert "fine-grained PAT restricted to the upstream and sandbox repositories" in post_start, "startup GH_PAT guidance missing"
PY

  [ "$status" -eq 0 ]
}

@test "setup secret check resolves the canonical manifest from the repository root" {
  run grep -F '_credential_manifest="$SCRIPT_DIR/../../.config/derived-repo-secrets.json"' \
    "$REPO_ROOT/scripts/setup/60-check-secrets.sh"

  [ "$status" -eq 0 ]
}

@test "credential manifest covers every non-ephemeral Actions secret reference" {
  run python3 - "$REPO_ROOT" "$MANIFEST" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
manifest = json.loads(pathlib.Path(sys.argv[2]).read_text())
declared = {item["name"] for item in manifest["secrets"]}
referenced = set()
for workflow in (root / ".github" / "workflows").glob("*.yml"):
    referenced.update(re.findall(r"secrets\.([A-Z][A-Z0-9_]+)", workflow.read_text()))
referenced.discard("GITHUB_TOKEN")
missing = sorted(referenced - declared)
if missing:
    raise SystemExit(f"manifest entries missing: {missing}")
PY
  [ "$status" -eq 0 ]
}

@test "override manifests cannot publish the bootstrap token" {
  codespaces_manifest="$TEST_ROOT/bootstrap-codespaces.json"
  duplicate_env_manifest="$TEST_ROOT/bootstrap-actions.json"
  gh_token_manifest="$TEST_ROOT/bootstrap-gh-token.json"
  jq '(.secrets[] | select(.name == "REPO_BOOTSTRAP_TOKEN")).codespaces = true' \
    "$MANIFEST" >"$codespaces_manifest"
  jq '(.secrets[] | select(.name == "OPENROUTER_API_KEY")).env = "REPO_BOOTSTRAP_TOKEN"' \
    "$MANIFEST" >"$duplicate_env_manifest"
  jq '(.secrets[] | select(.name == "OPENROUTER_API_KEY")).env = "GH_TOKEN"' \
    "$MANIFEST" >"$gh_token_manifest"

  run_bootstrap --manifest "$codespaces_manifest"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid credential manifest"* ]]

  run_bootstrap --manifest "$duplicate_env_manifest"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid credential manifest"* ]]

  TEST_REPO_BOOTSTRAP_TOKEN="bootstrap-secret"
  TEST_OPENCODE_GITHUB_TOKEN="available"
  run_bootstrap --apply --manifest "$gh_token_manifest"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid credential manifest"* ]]
  [ ! -s "$GH_LOG" ]
}

@test "dry-run reports names and planned operations without requiring a token or printing values" {
  TEST_OPENCODE_GITHUB_TOKEN="do-not-print-this-value"
  run_bootstrap

  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry-run"* ]]
  [[ "$output" == *"OPENCODE_GITHUB_TOKEN"* ]]
  [[ "$output" != *"do-not-print-this-value"* ]]
  [ ! -s "$GH_LOG" ]
}

@test "apply requires the dedicated bootstrap token before mutation" {
  TEST_OPENCODE_GITHUB_TOKEN="available"
  run_bootstrap --apply

  [ "$status" -ne 0 ]
  [[ "$output" == *"REPO_BOOTSTRAP_TOKEN"* ]]
  [ ! -s "$GH_LOG" ]
}

@test "missing required workflow value fails before any GitHub operation" {
  TEST_REPO_BOOTSTRAP_TOKEN="bootstrap-secret"
  run_bootstrap --apply

  [ "$status" -ne 0 ]
  [[ "$output" == *"OPENCODE_GITHUB_TOKEN: MISSING (required)"* ]]
  [ ! -s "$GH_LOG" ]
}

@test "missing Codespaces scope fails before repository creation" {
  TEST_REPO_BOOTSTRAP_TOKEN="bootstrap-secret"
  TEST_OPENCODE_GITHUB_TOKEN="available"
  TEST_GH_CODESPACES_ACCESS=false
  run_bootstrap --apply

  [ "$status" -ne 0 ]
  [[ "$output" == *"codespace:secrets"* ]]
  run grep -F 'repo create' "$GH_LOG"
  [ "$status" -ne 0 ]
}

@test "apply creates a private template repository and synchronizes allowlisted secrets" {
  TEST_REPO_BOOTSTRAP_TOKEN="bootstrap-secret"
  TEST_OPENCODE_GITHUB_TOKEN="github-secret"
  TEST_OPENROUTER_API_KEY="model-secret"
  run_bootstrap --apply

  [ "$status" -eq 0 ]
  [[ "$output" != *"bootstrap-secret"* ]]
  [[ "$output" != *"github-secret"* ]]
  [[ "$output" != *"model-secret"* ]]
  run grep -F 'repo create acme/demo --template mikejmckinney/ai-repo-template --private' "$GH_LOG"
  [ "$status" -eq 0 ]
  run grep -F 'secret set OPENCODE_GITHUB_TOKEN --repo acme/demo --app actions' "$GH_LOG"
  [ "$status" -eq 0 ]
  run grep -F 'secret set OPENROUTER_API_KEY --repo acme/demo --app actions' "$GH_LOG"
  [ "$status" -eq 0 ]
  run grep -F 'user/codespaces/secrets/OPENCODE_GITHUB_TOKEN/repositories/4242' "$GH_LOG"
  [ "$status" -eq 0 ]
  run grep -F 'secret set REPO_BOOTSTRAP_TOKEN' "$GH_LOG"
  [ "$status" -ne 0 ]
  run grep -F 'secret set SKILL_REFRESH_PR_TOKEN' "$GH_LOG"
  [ "$status" -ne 0 ]
  run grep -F 'user/codespaces/secrets/REPO_BOOTSTRAP_TOKEN/repositories/' "$GH_LOG"
  [ "$status" -ne 0 ]
}

@test "apply grants every selected provider Codespaces secret without granting the bootstrap token" {
  TEST_REPO_BOOTSTRAP_TOKEN="bootstrap-secret"
  TEST_OPENCODE_GITHUB_TOKEN="github-secret"
  run_bootstrap --apply

  [ "$status" -eq 0 ]
  for name in "${PROVIDER_CODESPACES_SECRETS[@]}"; do
    run grep -F "user/codespaces/secrets/$name/repositories/4242" "$GH_LOG"
    [ "$status" -eq 0 ]
  done
  run grep -F 'user/codespaces/secrets/REPO_BOOTSTRAP_TOKEN/repositories/4242' "$GH_LOG"
  [ "$status" -ne 0 ]
}

@test "apply preserves all private and missing provider visibility without mutation" {
  TEST_REPO_BOOTSTRAP_TOKEN="bootstrap-secret"
  TEST_OPENCODE_GITHUB_TOKEN="github-secret"
  TEST_GH_CODESPACES_JSON='{"secrets":[{"name":"CLOUDFLARE_API_KEY","visibility":"all"},{"name":"NETLIFY_API_KEY","visibility":"private"}]}'
  run_bootstrap --apply

  [ "$status" -eq 0 ]
  [[ "$output" == *"CLOUDFLARE_API_KEY: already covered by all visibility"* ]]
  [[ "$output" == *"NETLIFY_API_KEY: already covered by private visibility"* ]]
  [[ "$output" == *"VERCEL_API_KEY: secret not configured for this user"* ]]
  run grep -F 'user/codespaces/secrets/CLOUDFLARE_API_KEY/repositories/' "$GH_LOG"
  [ "$status" -ne 0 ]
  run grep -F 'user/codespaces/secrets/NETLIFY_API_KEY/repositories/' "$GH_LOG"
  [ "$status" -ne 0 ]
  run grep -F 'user/codespaces/secrets/VERCEL_API_KEY/repositories/' "$GH_LOG"
  [ "$status" -ne 0 ]
}

@test "existing repository requires explicit reuse and verified template metadata" {
  TEST_REPO_BOOTSTRAP_TOKEN="bootstrap-secret"
  TEST_OPENCODE_GITHUB_TOKEN="available"
  TEST_GH_REPO_EXISTS=true run_bootstrap --apply

  [ "$status" -ne 0 ]
  [[ "$output" == *"--reuse"* ]]

  : >"$GH_LOG"
  TEST_GH_REPO_EXISTS=true run_bootstrap --apply --reuse
  [ "$status" -eq 0 ]
  run grep -F 'repo create' "$GH_LOG"
  [ "$status" -ne 0 ]
}

@test "reuse rejects repository metadata that records another template" {
  TEST_REPO_BOOTSTRAP_TOKEN="bootstrap-secret"
  TEST_OPENCODE_GITHUB_TOKEN="available"
  TEST_GH_REPO_EXISTS=true
  TEST_GH_TEMPLATE_REPO="someone/other-template"
  run_bootstrap --apply --reuse

  [ "$status" -ne 0 ]
  [[ "$output" == *"records a different template"* ]]
  run grep -F 'secret set' "$GH_LOG"
  [ "$status" -ne 0 ]
}

@test "reuse uses the existing repository visibility for Codespaces coverage" {
  TEST_REPO_BOOTSTRAP_TOKEN="bootstrap-secret"
  TEST_OPENCODE_GITHUB_TOKEN="available"
  TEST_GH_REPO_EXISTS=true
  TEST_GH_REPO_VISIBILITY="public"
  run_bootstrap --apply --reuse

  [ "$status" -eq 0 ]
  [[ "$output" == *"Existing repository visibility: public"* ]]
  [[ "$output" == *"CURSOR_API_KEY: private visibility does not cover a public repository"* ]]
}

@test "manual workflow is guarded and maps the canonical allowlist explicitly" {
  workflow="$REPO_ROOT/.github/workflows/create-derived-repository.yml"
  run grep -F 'workflow_dispatch:' "$workflow"
  [ "$status" -eq 0 ]
  run grep -F "github.repository == 'mikejmckinney/ai-repo-template'" "$workflow"
  [ "$status" -eq 0 ]
  run grep -F 'REPO_BOOTSTRAP_TOKEN: ${{ secrets.REPO_BOOTSTRAP_TOKEN }}' "$workflow"
  [ "$status" -eq 0 ]
  run grep -F "github.ref == 'refs/heads/main'" "$workflow"
  [ "$status" -eq 0 ]
  run grep -F 'persist-credentials: false' "$workflow"
  [ "$status" -eq 0 ]
  run grep -F 'contents: read' "$workflow"
  [ "$status" -eq 0 ]
  run grep -F 'pull_request:' "$workflow"
  [ "$status" -ne 0 ]

  run grep -F 'TARGET_REPOSITORY: ${{ inputs.repository }}' "$workflow"
  [ "$status" -eq 0 ]
  run grep -F -- '--repo "$TARGET_REPOSITORY"' "$workflow"
  [ "$status" -eq 0 ]

  run python3 - "$MANIFEST" "$workflow" <<'PY'
import json
import pathlib
import re
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
workflow = pathlib.Path(sys.argv[2]).read_text()
expected = {
    item["env"]
    for item in manifest["secrets"]
    if item["actions"] and item.get("bootstrap", True)
}
expected.add("REPO_BOOTSTRAP_TOKEN")
mappings = re.findall(
    r"^\s{10}([A-Z][A-Z0-9_]+): \$\{\{ secrets\.([A-Z][A-Z0-9_]+) \}\}$",
    workflow,
    flags=re.MULTILINE,
)
actual_names = {name for name, _ in mappings}
actual_refs = {ref for _, ref in mappings}
if actual_names != expected or actual_refs != expected:
    raise SystemExit(
        f"workflow secret mappings differ: names={sorted(actual_names)} refs={sorted(actual_refs)} expected={sorted(expected)}"
    )
if workflow.count("${{ inputs.repository }}") != 1:
    raise SystemExit("repository input must appear only in the step environment mapping")
PY
  [ "$status" -eq 0 ]
}
