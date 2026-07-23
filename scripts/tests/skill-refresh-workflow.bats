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

@test "nightly refresh workflow publishes one aggregate review PR" {
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
  [ "$status" -eq 1 ]
  # shellcheck disable=SC2016
  run grep -Fq 'group: skill-refresh-aggregate' "$WORKFLOW"
  [ "$status" -eq 0 ]
  # shellcheck disable=SC2016
  run grep -Fq 'branch: automation/skill-refresh/all' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'uses: peter-evans/create-pull-request@5f6978faf089d4d20b00c7766989d076bb2fc7f1' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'draft: always-true' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'delete-branch: false' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'docs/guides/skill-supply-chain.md' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'render-license-inventory' "$REPO_ROOT/scripts/skill-supply-chain.py"
  [ "$status" -eq 0 ]
  run grep -Fq 'gh workflow run ci-tests.yml' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'gh workflow run lint-and-format.yml' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'REFRESH_BRANCH: automation/skill-refresh/all' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq -- '--ref "$REFRESH_BRANCH"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q "if: steps.refresh.outputs.content_changed == 'true'" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'echo "content_changed=true"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'scan-skill-secrets.py' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'Content-changed packages' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'Ref-only lock records' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'Missing upstream paths block that source' "$WORKFLOW"
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

@test "aggregate refresh processes sources sequentially with source rollback" {
  run grep -Fq 'REQUESTED_SOURCE:' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'for source in "${sources[@]}"; do' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'backup_source "$source"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'restore_source "$source"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'failed-sources.jsonl' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'successful-sources.jsonl' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'Failed sources remain unchanged' "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "targeted dispatch reuses the aggregate branch and pull request" {
  [ "$(grep -Fc 'automation/skill-refresh/all' "$WORKFLOW")" -ge 2 ]
  run grep -Fq 'Resolve aggregate refresh base' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'ref: ${{ steps.refresh-base.outputs.ref }}' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'git rebase origin/main' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'git diff --binary origin/main...HEAD' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'git checkout -B main origin/main' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'git apply "$AGGREGATE_PATCH"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'echo "base_sha=$(git rev-parse HEAD)"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'Optional owner/repository source to refresh' "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "required workflows accept trusted exact-head skill refresh dispatches" {
  ci_workflow="$REPO_ROOT/.github/workflows/ci-tests.yml"
  lint_workflow="$REPO_ROOT/.github/workflows/lint-and-format.yml"

  run grep -Fq 'REFRESH_HEAD: ${{ steps.create-pr.outputs.pull-request-head-sha }}' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$(grep -Fc -- '-f head_sha="$REFRESH_HEAD"' "$WORKFLOW")" -eq 2 ]
  run grep -Fq 'REFRESH_BASE: ${{ steps.refresh.outputs.base_sha }}' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq -- '-f base_sha="$REFRESH_BASE"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'workflow_dispatch:' "$ci_workflow"
  [ "$status" -eq 0 ]
  run grep -q 'workflow_dispatch:' "$lint_workflow"
  [ "$status" -eq 0 ]
  run grep -q 'base_sha:' "$lint_workflow"
  [ "$status" -eq 0 ]
  run grep -q 'head_sha:' "$lint_workflow"
  [ "$status" -eq 0 ]
  run grep -q 'head_sha:' "$ci_workflow"
  [ "$status" -eq 0 ]
  run grep -Fq "ref: \${{ github.event_name == 'workflow_dispatch' && inputs.head_sha || '' }}" "$ci_workflow"
  [ "$status" -eq 0 ]
  run grep -Fq 'EXPECTED_HEAD: ${{ inputs.head_sha }}' "$ci_workflow"
  [ "$status" -eq 0 ]
  run grep -Fq 'run: test "$(git rev-parse HEAD)" = "$EXPECTED_HEAD"' "$ci_workflow"
  [ "$status" -eq 0 ]
  run grep -Fq "ref: \${{ github.event_name == 'workflow_dispatch' && inputs.head_sha || '' }}" "$lint_workflow"
  [ "$status" -eq 0 ]
  run grep -Fq 'EXPECTED_HEAD: ${{ inputs.head_sha }}' "$lint_workflow"
  [ "$status" -eq 0 ]
  run grep -Fq 'run: test "$(git rev-parse HEAD)" = "$EXPECTED_HEAD"' "$lint_workflow"
  [ "$status" -eq 0 ]
  run grep -Fq 'base_ref="${{ inputs.base_sha }}"' "$lint_workflow"
  [ "$status" -eq 0 ]
  run grep -Fq 'head_ref="${{ inputs.head_sha }}"' "$lint_workflow"
  [ "$status" -eq 0 ]
}

@test "skill refresh documentation explains aggregate publication and PR authorization" {
  guide="$REPO_ROOT/docs/guides/skill-supply-chain.md"

  run grep -Fq 'one stable aggregate branch and draft PR' "$guide"
  [ "$status" -eq 0 ]
  run grep -Fq 'failed source remains unchanged' "$guide"
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
