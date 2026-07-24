#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/priority-retro.XXXXXX")"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

make_installer_fixture() {
  mkdir -p "$TEST_ROOT/dotfiles/.github" "$TEST_ROOT/workspace"
  printf '%s\n' '* @mikejmckinney' >"$TEST_ROOT/dotfiles/.github/CODEOWNERS"
  git -C "$TEST_ROOT/workspace" init -q
}

@test "installer assigns CODEOWNERS to the workspace repository owner" {
  make_installer_fixture
  git -C "$TEST_ROOT/workspace" remote add origin https://github.com/acme/example.git

  run env -u GITHUB_REPOSITORY_OWNER PATH=/usr/bin:/bin \
    DOTFILES="$TEST_ROOT/dotfiles" WORKSPACE="$TEST_ROOT/workspace" \
    /bin/bash "$REPO_ROOT/install.sh"

  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/workspace/.github/CODEOWNERS")" = '* @acme' ]
}

@test "installer does not copy a maintainer-specific CODEOWNERS without a target owner" {
  make_installer_fixture

  run env -u GITHUB_REPOSITORY_OWNER PATH=/usr/bin:/bin \
    DOTFILES="$TEST_ROOT/dotfiles" WORKSPACE="$TEST_ROOT/workspace" \
    /bin/bash "$REPO_ROOT/install.sh"

  [ "$status" -eq 0 ]
  [ ! -e "$TEST_ROOT/workspace/.github/CODEOWNERS" ]
  [[ "$output" == *"Could not resolve workspace repository owner; skipping .github/CODEOWNERS"* ]]
}

@test "installer falls back to the Codespaces repository owner" {
  make_installer_fixture

  run env PATH=/usr/bin:/bin GITHUB_REPOSITORY_OWNER=octocat \
    DOTFILES="$TEST_ROOT/dotfiles" WORKSPACE="$TEST_ROOT/workspace" \
    /bin/bash "$REPO_ROOT/install.sh"

  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/workspace/.github/CODEOWNERS")" = '* @octocat' ]
}

make_azure_stubs() {
  mkdir -p "$TEST_ROOT/bin"
  export AZ_LOG="$TEST_ROOT/az.log"
  export AZD_LOG="$TEST_ROOT/azd.log"
  : >"$AZ_LOG"
  : >"$AZD_LOG"

  cat >"$TEST_ROOT/bin/azd" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$AZD_LOG"
if [[ "$1 $2" == "env get-values" ]]; then
  printf '%s\n' 'AZURE_RESOURCE_GROUP="example-rg"'
  if [[ -n "${AZD_VALUES_EXTRA:-}" ]]; then
    printf '%s\n' "$AZD_VALUES_EXTRA"
  fi
fi
EOF

  cat >"$TEST_ROOT/bin/az" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$AZ_LOG"
if [[ "$1 $2" == "acr list" ]]; then
  scenario="${ACR_SCENARIO:-${RESOURCE_SCENARIO:-single}}"
else
  scenario="${IDENTITY_SCENARIO:-${RESOURCE_SCENARIO:-single}}"
fi
case "$1 $2:$scenario" in
  "acr list:zero"|"identity list:zero") ;;
  "acr list:single") printf '%s\n' 'example.azurecr.io' ;;
  "acr list:multiple") printf '%s\n' 'first.azurecr.io' 'second.azurecr.io' ;;
  "identity list:single") printf '%s\t%s\n' '/subscriptions/example/identities/app' 'client-one' ;;
  "identity list:multiple")
    printf '%s\t%s\n' '/subscriptions/example/identities/first' 'client-one'
    printf '%s\t%s\n' '/subscriptions/example/identities/second' 'client-two'
    ;;
esac
EOF
  chmod +x "$TEST_ROOT/bin/az" "$TEST_ROOT/bin/azd"
}

@test "Aspire Bash helper accepts one registry and one identity from one query each" {
  make_azure_stubs

  run env PATH="$TEST_ROOT/bin:$PATH" RESOURCE_SCENARIO=single \
    /bin/bash "$REPO_ROOT/.agents/skills/azure/azure-validate/references/recipes/azd/scripts/set-aspire-aca-env.sh"

  [ "$status" -eq 0 ]
  [ "$(grep -c '^acr list ' "$AZ_LOG")" -eq 1 ]
  [ "$(grep -c '^identity list ' "$AZ_LOG")" -eq 1 ]
  grep -Fq 'env set AZURE_CONTAINER_REGISTRY_ENDPOINT example.azurecr.io' "$AZD_LOG"
  grep -Fq 'env set AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID /subscriptions/example/identities/app' "$AZD_LOG"
  grep -Fq 'env set MANAGED_IDENTITY_CLIENT_ID client-one' "$AZD_LOG"
}

@test "Aspire Bash helper rejects missing Azure resource candidates" {
  make_azure_stubs

  run env PATH="$TEST_ROOT/bin:$PATH" RESOURCE_SCENARIO=zero \
    /bin/bash "$REPO_ROOT/.agents/skills/azure/azure-validate/references/recipes/azd/scripts/set-aspire-aca-env.sh"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Expected exactly one Azure Container Registry"* ]]
  [ ! -s "$AZD_LOG" ] || ! grep -q '^env set ' "$AZD_LOG"
}

@test "Aspire Bash helper rejects ambiguous Azure resource candidates" {
  make_azure_stubs

  run env PATH="$TEST_ROOT/bin:$PATH" RESOURCE_SCENARIO=multiple \
    /bin/bash "$REPO_ROOT/.agents/skills/azure/azure-validate/references/recipes/azd/scripts/set-aspire-aca-env.sh"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Expected exactly one Azure Container Registry"* ]]
  [ ! -s "$AZD_LOG" ] || ! grep -q '^env set ' "$AZD_LOG"
}

@test "Aspire Bash helper rejects ambiguous managed identities independently" {
  make_azure_stubs

  run env PATH="$TEST_ROOT/bin:$PATH" ACR_SCENARIO=single IDENTITY_SCENARIO=multiple \
    /bin/bash "$REPO_ROOT/.agents/skills/azure/azure-validate/references/recipes/azd/scripts/set-aspire-aca-env.sh"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Expected exactly one user-assigned managed identity"* ]]
  ! grep -q 'env set AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID' "$AZD_LOG"
  ! grep -q 'env set MANAGED_IDENTITY_CLIENT_ID' "$AZD_LOG"
}

@test "Aspire Bash helper rejects a mismatched partially configured identity" {
  make_azure_stubs

  run env PATH="$TEST_ROOT/bin:$PATH" RESOURCE_SCENARIO=single \
    AZD_VALUES_EXTRA='AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID="/subscriptions/example/identities/other"' \
    /bin/bash "$REPO_ROOT/.agents/skills/azure/azure-validate/references/recipes/azd/scripts/set-aspire-aca-env.sh"

  [ "$status" -ne 0 ]
  [[ "$output" == *"AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID does not match"* ]]
  ! grep -q 'env set MANAGED_IDENTITY_CLIENT_ID' "$AZD_LOG"
}

@test "Aspire PowerShell helper no longer selects independent first resources" {
  helper="$REPO_ROOT/.agents/skills/azure/azure-validate/references/recipes/azd/scripts/set-aspire-aca-env.ps1"

  run grep -F -- '--query "[0]' "$helper"
  [ "$status" -ne 0 ]
  [ "$(grep -c 'az identity list' "$helper")" -eq 1 ]
  grep -Fq 'Expected exactly one Azure Container Registry' "$helper"
  grep -Fq 'Expected exactly one user-assigned managed identity' "$helper"
  grep -Fq 'AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID does not match' "$helper"
  grep -Fq 'MANAGED_IDENTITY_CLIENT_ID does not match' "$helper"
}

make_terraform_stubs() {
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/infra"
  export TERRAFORM_LOG="$TEST_ROOT/terraform.log"
  : >"$TERRAFORM_LOG"

  cat >"$TEST_ROOT/bin/az" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"$TEST_ROOT/bin/terraform" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TERRAFORM_LOG"
for arg in "$@"; do
  if [[ "$arg" == -out=* ]]; then
    : >"${arg#-out=}"
  fi
done
exit 0
EOF
  chmod +x "$TEST_ROOT/bin/az" "$TEST_ROOT/bin/terraform"
}

@test "Terraform Bash validation does not request or leave a saved plan" {
  make_terraform_stubs

  run env PATH="$TEST_ROOT/bin:$PATH" \
    "$REPO_ROOT/.agents/skills/azure/azure-validate/references/recipes/terraform/scripts/validate-terraform.sh" \
    "$TEST_ROOT/infra"

  [ "$status" -eq 0 ]
  grep -Fq 'plan -input=false' "$TERRAFORM_LOG"
  run grep -F -- '-out=' "$TERRAFORM_LOG"
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_ROOT/infra/tfplan" ]
}

@test "Terraform validation helpers do not persist tfplan" {
  shell_helper="$REPO_ROOT/.agents/skills/azure/azure-validate/references/recipes/terraform/scripts/validate-terraform.sh"
  powershell_helper="$REPO_ROOT/.agents/skills/azure/azure-validate/references/recipes/terraform/scripts/validate-terraform.ps1"

  run grep -F -- '-out=tfplan' "$shell_helper" "$powershell_helper"
  [ "$status" -ne 0 ]
}
