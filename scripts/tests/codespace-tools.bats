#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  INSTALLER="$REPO_ROOT/scripts/install-codespace-tools.sh"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codespace-tools.XXXXXX")"
  PREFIX="$TEST_ROOT/prefix"
  BIN_DIR="$TEST_ROOT/bin"
  mkdir -p "$PREFIX/bin" "$BIN_DIR"

  cat >"$TEST_ROOT/fake-tool" <<'EOF'
#!/usr/bin/env bash
printf 'fake-tool 1.2.3\n'
EOF
  chmod +x "$TEST_ROOT/fake-tool"
  ARTIFACT_SHA="$(sha256sum "$TEST_ROOT/fake-tool" | cut -d' ' -f1)"

  jq -n --arg sha "$ARTIFACT_SHA" '{
    schema_version: 1,
    required_commands: [],
    apt_packages: [],
    profiles: {core: ["fake-tool"], agents: []},
    tools: {
      "fake-tool": {
        type: "binary",
        command: "fake-tool",
        version: "1.2.3",
        version_args: ["--version"],
        asset: {
          url: "https://example.invalid/fake-tool",
          sha256: $sha,
          archive: "raw"
        }
      }
    }
  }' >"$TEST_ROOT/manifest.json"

  cat >"$BIN_DIR/curl" <<'EOF'
#!/usr/bin/env bash
[[ "${FETCH_MODE:-success}" == success ]] || exit 22
while (($# > 0)); do
  if [[ "$1" == "-o" ]]; then
    cp "$FETCH_SOURCE" "$2"
    exit 0
  fi
  shift
done
exit 2
EOF
  chmod +x "$BIN_DIR/curl"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

run_installer() {
  run env PATH="$BIN_DIR:$PREFIX/bin:$PATH" FETCH_SOURCE="$TEST_ROOT/fake-tool" \
    FETCH_MODE="${FETCH_MODE:-success}" bash "$INSTALLER" \
    --manifest "$TEST_ROOT/manifest.json" --prefix "$PREFIX" "$@"
  printf 'status=%s\n%s\n' "$status" "$output" | sed 's/^/# /' >&3
}

@test "canonical Codespaces manifest is structurally valid" {
  run jq -e '
    .schema_version == 1 and
    (.required_commands | type == "array" and length > 0) and
    (.apt_packages | type == "array" and length > 0) and
    (.profiles.core | index("shfmt")) and
    (.profiles.core | index("actionlint")) and
    (.profiles.core | index("markdownlint-cli2")) and
    (.profiles.core | index("uv")) and
    (.profiles.core | index("chrome-for-testing")) and
    (.profiles.core | index("open-design")) and
    (.profiles.agents | index("opencode")) and
    (.profiles.agents | index("claude")) and
    (.profiles.agents | index("cursor-agent")) and
    (.profiles.agents | index("codex")) and
    all(.tools[]; .type and .command and .version)
  ' "$REPO_ROOT/.config/codespace-tools.json"

  [ "$status" -eq 0 ]
}

@test "install.sh invokes and copies the canonical Codespaces bootstrap" {
  run grep -F 'bash "$DOTFILES/scripts/install-codespace-tools.sh" --profile "$TOOLS_PROFILE"' \
    "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]

  for path in .config/codespace-tools.json scripts/install-codespace-tools.sh \
    scripts/browser-mcp.sh scripts/open-design-mcp.sh; do
    run grep -F "\"$path\"" "$REPO_ROOT/install.sh"
    [ "$status" -eq 0 ]
  done
}

@test "unknown profile is rejected before installation" {
  run_installer --profile unknown

  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown profile: unknown"* ]]
  [ ! -e "$PREFIX/bin/fake-tool" ]
}

@test "matching binary version is skipped" {
  cp "$TEST_ROOT/fake-tool" "$PREFIX/bin/fake-tool"

  run_installer --profile core

  [ "$status" -eq 0 ]
  [[ "$output" == *"fake-tool 1.2.3 already installed"* ]]
}

@test "missing or mismatched binary is replaced by verified artifact" {
  printf '#!/usr/bin/env bash\nprintf "fake-tool 0.1.0\\n"\n' >"$PREFIX/bin/fake-tool"
  chmod +x "$PREFIX/bin/fake-tool"

  run_installer --profile core

  [ "$status" -eq 0 ]
  [[ "$output" == *"installed fake-tool 1.2.3"* ]]
  [ "$("$PREFIX/bin/fake-tool" --version)" = "fake-tool 1.2.3" ]
}

@test "checksum mismatch rejects the artifact without replacing the tool" {
  jq '.tools["fake-tool"].asset.sha256 = "0000000000000000000000000000000000000000000000000000000000000000"' \
    "$TEST_ROOT/manifest.json" >"$TEST_ROOT/bad-manifest.json"
  mv "$TEST_ROOT/bad-manifest.json" "$TEST_ROOT/manifest.json"

  run_installer --profile core

  [ "$status" -ne 0 ]
  [[ "$output" == *"checksum mismatch for fake-tool"* ]]
  [ ! -e "$PREFIX/bin/fake-tool" ]
}

@test "verify-only reports a missing tool without downloading" {
  run_installer --profile core --verify-only

  [ "$status" -ne 0 ]
  [[ "$output" == *"fake-tool 1.2.3 is missing"* ]]
  [ ! -e "$PREFIX/bin/fake-tool" ]
}

@test "download failure is surfaced and leaves no installed tool" {
  FETCH_MODE=fail run_installer --profile core

  [ "$status" -ne 0 ]
  [ ! -e "$PREFIX/bin/fake-tool" ]
}
