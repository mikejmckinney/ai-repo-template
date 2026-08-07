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
    .features["ghcr.io/devcontainers/features/node:2"].version == "24" and
    .features["ghcr.io/devcontainers/features/node:2"].pnpmVersion == "10.33.2" and
    .postCreateCommand == "bash scripts/codespace-post-create.sh" and
    .postStartCommand == "bash scripts/codespace-post-start.sh" and
    ([.postCreateCommand, .postStartCommand] | all(contains("scripts/setup.sh") | not)) and
    ([.postCreateCommand, .postStartCommand] | all(contains("install.sh") | not))
  ' "$DEVCONTAINER"

  [ "$status" -eq 0 ]
}

@test "Dev Container excludes bundled VS Code extensions" {
  run jq -e '.customizations.vscode.extensions == ["-dbaeumer.vscode-eslint"]' "$DEVCONTAINER"

  [ "$status" -eq 0 ]
}

@test "post-create delegates only to the default tool profile" {
  cat >"$TEST_ROOT/install-tools" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$POST_CREATE_LOG"
EOF
  cat >"$TEST_ROOT/prewarm" <<'EOF'
#!/usr/bin/env bash
printf 'prewarm\n' >>"$POST_CREATE_LOG"
EOF
  chmod +x "$TEST_ROOT/install-tools" "$TEST_ROOT/prewarm"

  run env CODESPACE_POST_CREATE_INSTALLER="$TEST_ROOT/install-tools" \
    CODESPACE_POST_CREATE_PREWARM="$TEST_ROOT/prewarm" \
    POST_CREATE_LOG="$TEST_ROOT/install.log" bash "$POST_CREATE"
  [ "$status" -eq 0 ]

  run env CODESPACE_POST_CREATE_INSTALLER="$TEST_ROOT/install-tools" \
    CODESPACE_POST_CREATE_PREWARM="$TEST_ROOT/prewarm" \
    POST_CREATE_LOG="$TEST_ROOT/install.log" bash "$POST_CREATE"
  [ "$status" -eq 0 ]

  [ "$(wc -l <"$TEST_ROOT/install.log" | tr -d ' ')" -eq 4 ]
  [ "$(sed -n '1p' "$TEST_ROOT/install.log")" = "--profile default" ]
  [ "$(sed -n '2p' "$TEST_ROOT/install.log")" = "prewarm" ]
  [ "$(sed -n '3p' "$TEST_ROOT/install.log")" = "--profile default" ]
  [ "$(sed -n '4p' "$TEST_ROOT/install.log")" = "prewarm" ]
}

@test "post-create keeps prewarm failures non-fatal" {
  cat >"$TEST_ROOT/install-tools" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"$TEST_ROOT/prewarm" <<'EOF'
#!/usr/bin/env bash
printf 'prewarm failed with secret-value\n' >&2
exit 7
EOF
  chmod +x "$TEST_ROOT/install-tools" "$TEST_ROOT/prewarm"

  run env CODESPACE_POST_CREATE_INSTALLER="$TEST_ROOT/install-tools" \
    CODESPACE_POST_CREATE_PREWARM="$TEST_ROOT/prewarm" bash "$POST_CREATE"

  [ "$status" -eq 0 ]
  [[ "$output" == *"MCP prewarm failed"* ]]
  [[ "$output" != *"secret-value"* ]]
}

@test "legacy install entrypoint is removed" {
  [ ! -e "$REPO_ROOT/install.sh" ]

  run grep -F '"install.sh"' "$REPO_ROOT/scripts/checks/010-required-files.sh"
  [ "$status" -eq 1 ]
}
