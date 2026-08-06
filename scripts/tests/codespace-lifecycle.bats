#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  DEVCONTAINER="$REPO_ROOT/.devcontainer/devcontainer.json"
  POST_CREATE="$REPO_ROOT/scripts/codespace-post-create.sh"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codespace-lifecycle.XXXXXX")"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "repository owns the canonical Codespaces lifecycle" {
  run jq -e '
    .image == "mcr.microsoft.com/devcontainers/universal:2" and
    .postCreateCommand == "bash scripts/codespace-post-create.sh" and
    .postStartCommand == "bash scripts/codespace-post-start.sh" and
    ([.postCreateCommand, .postStartCommand] | all(contains("scripts/setup.sh") | not)) and
    ([.postCreateCommand, .postStartCommand] | all(contains("install.sh") | not))
  ' "$DEVCONTAINER"

  [ "$status" -eq 0 ]
}

@test "Dev Container does not prescribe VS Code extensions" {
  run jq -e 'has("customizations") | not' "$DEVCONTAINER"

  [ "$status" -eq 0 ]
}

@test "post-create delegates only to the default tool profile" {
  cat >"$TEST_ROOT/install-tools" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$POST_CREATE_LOG"
EOF
  chmod +x "$TEST_ROOT/install-tools"

  run env CODESPACE_POST_CREATE_INSTALLER="$TEST_ROOT/install-tools" \
    POST_CREATE_LOG="$TEST_ROOT/install.log" bash "$POST_CREATE"
  [ "$status" -eq 0 ]

  run env CODESPACE_POST_CREATE_INSTALLER="$TEST_ROOT/install-tools" \
    POST_CREATE_LOG="$TEST_ROOT/install.log" bash "$POST_CREATE"
  [ "$status" -eq 0 ]

  [ "$(wc -l <"$TEST_ROOT/install.log" | tr -d ' ')" -eq 2 ]
  [ "$(sort -u "$TEST_ROOT/install.log")" = "--profile default" ]
}

@test "legacy install entrypoint is removed" {
  [ ! -e "$REPO_ROOT/install.sh" ]

  run grep -F '"install.sh"' "$REPO_ROOT/scripts/checks/010-required-files.sh"
  [ "$status" -eq 1 ]
}
