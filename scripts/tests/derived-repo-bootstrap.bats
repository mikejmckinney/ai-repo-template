#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/create-derived-repo.sh"
  MANIFEST="$REPO_ROOT/.config/derived-repo-secrets.json"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/derived-repo-bootstrap.XXXXXX")"
  BIN_DIR="$TEST_ROOT/bin"
  GH_LOG="$TEST_ROOT/gh.log"
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
    printf '{"id":4242,"template_repository":{"full_name":"mikejmckinney/ai-repo-template"}}\n'
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
  run env PATH="$BIN_DIR:$PATH" GH_LOG="$GH_LOG" \
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
      (.consumers | type == "array" and length > 0)
    ) and
    ([.secrets[] | select(.name == "REPO_BOOTSTRAP_TOKEN" and .actions == false and .codespaces == true)] | length == 1)
  ' "$MANIFEST"
  [ "$status" -eq 0 ]
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
}

@test "existing repository requires explicit reuse and verified template metadata" {
  TEST_REPO_BOOTSTRAP_TOKEN="bootstrap-secret"
  GH_REPO_EXISTS=true run_bootstrap --apply

  [ "$status" -ne 0 ]
  [[ "$output" == *"--reuse"* ]]

  : >"$GH_LOG"
  GH_REPO_EXISTS=true run_bootstrap --apply --reuse
  [ "$status" -eq 0 ]
  run grep -F 'repo create' "$GH_LOG"
  [ "$status" -ne 0 ]
}

@test "manual workflow is guarded and maps the canonical allowlist explicitly" {
  workflow="$REPO_ROOT/.github/workflows/create-derived-repository.yml"
  run grep -F 'workflow_dispatch:' "$workflow"
  [ "$status" -eq 0 ]
  run grep -F "github.repository == 'mikejmckinney/ai-repo-template'" "$workflow"
  [ "$status" -eq 0 ]
  run grep -F 'REPO_BOOTSTRAP_TOKEN: ${{ secrets.REPO_BOOTSTRAP_TOKEN }}' "$workflow"
  [ "$status" -eq 0 ]

  run python3 - "$MANIFEST" "$workflow" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
workflow = pathlib.Path(sys.argv[2]).read_text()
expected = {item["env"] for item in manifest["secrets"] if item["actions"]}
missing = sorted(name for name in expected if f"secrets.{name}" not in workflow)
if missing:
    raise SystemExit(f"workflow mappings missing: {missing}")
PY
  [ "$status" -eq 0 ]
}
