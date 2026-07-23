#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCANNER="$REPO_ROOT/scripts/scan-skill-secrets.py"
  WORKFLOW="$REPO_ROOT/.github/workflows/skill-refresh.yml"
  FIXTURE_ROOT="$BATS_TEST_TMPDIR/secret-fixtures"
  mkdir -p "$FIXTURE_ROOT"
}

@test "skill secret scan rejects credential signatures with locations" {
  cat >"$FIXTURE_ROOT/leaked.md" <<'EOF'
access_key = AKIAIOSFODNN7EXAMPLE
-----BEGIN PRIVATE KEY-----
EOF

  run python3 "$SCANNER" "$FIXTURE_ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"leaked.md:1: aws-access-key-id"* ]]
  [[ "$output" == *"leaked.md:2: private-key"* ]]
}

@test "skill secret scan accepts documented placeholders" {
  cat >"$FIXTURE_ROOT/placeholders.md" <<'EOF'
api_key = "${RENDER_API_KEY}"
password = "replace-with-your-password"
token = "<your-token>"
password = "strong-password-here"
token="$env:TEMP\hf-token.txt"
CLIENT_SECRET="abc123~defGHI456jklMNO789pqrSTU"
EOF

  run python3 "$SCANNER" "$FIXTURE_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"findings": 0'* ]]
}

@test "skill secret scan still rejects unrecognized generic assignments" {
  printf '%s\n' 'password = "actualSensitiveValue12345"' >"$FIXTURE_ROOT/generic.md"

  run python3 "$SCANNER" "$FIXTURE_ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"generic.md:1: generic-secret-assignment"* ]]
}

@test "nightly refresh workflow is source-scoped and review-first" {
  [ -f "$WORKFLOW" ]
  run grep -q 'cron: "0 5 \* \* \*"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'workflow_dispatch:' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'contents: write' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'pull-requests: write' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'actions: write' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'matrix.source' "$WORKFLOW"
  [ "$status" -eq 0 ]
  # shellcheck disable=SC2016
  run grep -Fq 'group: skill-refresh-${{ matrix.source }}' "$WORKFLOW"
  [ "$status" -eq 0 ]
  # shellcheck disable=SC2016
  run grep -Fq 'branch: automation/skill-refresh/${{ matrix.source }}' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'uses: peter-evans/create-pull-request@5f6978faf089d4d20b00c7766989d076bb2fc7f1' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'draft: always-true' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'delete-branch: false' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'docs/guides/skill-supply-chain.md' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'scripts/tests/provider-integrations.bats' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'gh workflow run ci-tests.yml' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'gh workflow run lint-and-format.yml' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq -- '--ref "automation/skill-refresh/${{ matrix.source }}"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q "if: steps.check.outputs.content_changed == 'true'" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q "content_changed=.*\.changed" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'scan-skill-secrets.py' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'Content-changed packages' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'Ref-only lock records' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'Missing upstream paths block refresh' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'validate-lock' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'sudo apt-get install -y -qq bats parallel ripgrep' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'set -o pipefail' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q './test.sh' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Eiq 'enable-auto-merge|merge-method:|auto-merge:' "$WORKFLOW"
  [ "$status" -eq 1 ]
}

@test "required workflows accept trusted exact-head skill refresh dispatches" {
  ci_workflow="$REPO_ROOT/.github/workflows/ci-tests.yml"
  lint_workflow="$REPO_ROOT/.github/workflows/lint-and-format.yml"

  run grep -q 'workflow_dispatch:' "$ci_workflow"
  [ "$status" -eq 0 ]
  run grep -q 'workflow_dispatch:' "$lint_workflow"
  [ "$status" -eq 0 ]
  run grep -q 'base_sha:' "$lint_workflow"
  [ "$status" -eq 0 ]
  run grep -q 'head_sha:' "$lint_workflow"
  [ "$status" -eq 0 ]
}

@test "skill refresh documentation explains source branches and PR authorization" {
  guide="$REPO_ROOT/docs/guides/skill-supply-chain.md"

  run grep -Fq 'one branch and draft PR per upstream source repository' "$guide"
  [ "$status" -eq 0 ]
  run grep -Fq 'Allow GitHub Actions to create and approve pull requests' "$guide"
  [ "$status" -eq 0 ]
  run grep -Fq 'required code-owner approval' "$guide"
  [ "$status" -eq 0 ]
}

@test "repository assigns every path to the maintainer code owner" {
  [ -f "$REPO_ROOT/.github/CODEOWNERS" ]
  [ "$(cat "$REPO_ROOT/.github/CODEOWNERS")" = '* @mikejmckinney' ]
  run grep -Fq '  ".github/CODEOWNERS"' "$REPO_ROOT/scripts/checks/010-required-files.sh"
  [ "$status" -eq 0 ]
}
