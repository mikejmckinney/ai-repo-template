#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  INSTALLER="$REPO_ROOT/scripts/install-codespace-tools.sh"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codespace-tools.XXXXXX")"
  PREFIX="$TEST_ROOT/prefix"
  BIN_DIR="$TEST_ROOT/bin"
  mkdir -p "$PREFIX/bin" "$BIN_DIR"

  mkdir -p "$TEST_ROOT/artifact"
  cat >"$TEST_ROOT/artifact/fake-tool" <<'EOF'
#!/usr/bin/env bash
printf 'fake-tool 1.2.3\n'
EOF
  cat >"$TEST_ROOT/artifact/fake-tool-alias" <<'EOF'
#!/usr/bin/env bash
printf 'fake-tool-alias 1.2.3\n'
EOF
  chmod +x "$TEST_ROOT/artifact/fake-tool" "$TEST_ROOT/artifact/fake-tool-alias"
  tar -czf "$TEST_ROOT/fake-tool.tar.gz" -C "$TEST_ROOT/artifact" fake-tool fake-tool-alias
  ARTIFACT_SHA="$(sha256sum "$TEST_ROOT/fake-tool.tar.gz" | cut -d' ' -f1)"

  jq -n --arg sha "$ARTIFACT_SHA" '{
    schema_version: 1,
    required_commands: [],
    apt_packages: [],
    profiles: {
      core: ["fake-tool"],
      agents: ["fake-tool"],
      default: ["fake-tool"]
    },
    tools: {
      "fake-tool": {
        type: "binary",
        command: "fake-tool",
        companions: [{
          command: "fake-tool-alias",
          member: "fake-tool-alias",
          version_prefix: "fake-tool-alias ",
          version_args: ["--version"]
        }],
        version: "1.2.3",
        version_args: ["--version"],
        asset: {
          url: "https://example.invalid/fake-tool",
          sha256: $sha,
          archive: "tar.gz",
          member: "fake-tool"
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
  run env PATH="$BIN_DIR:$PREFIX/bin:$PATH" FETCH_SOURCE="$TEST_ROOT/fake-tool.tar.gz" \
    FETCH_MODE="${FETCH_MODE:-success}" bash "$INSTALLER" \
    --manifest "$TEST_ROOT/manifest.json" --prefix "$PREFIX" "$@"
  printf 'status=%s\n%s\n' "$status" "$output" | sed 's/^/# /' >&3
}

@test "canonical Codespaces manifest is structurally valid" {
  run jq -e '
    .schema_version == 1 and
    (.required_commands | type == "array" and length > 0) and
    (.apt_packages | type == "array" and length > 0) and
    (.profiles.verification == ["uv", "bats"]) and
    (.profiles.media == ["ffmpeg"]) and
    (.profiles.core | index("shfmt")) and
    (.profiles.core | index("actionlint")) and
    (.profiles.core | index("markdownlint-cli2")) and
    (.profiles.core | index("uv")) and
    (.tools.uv.companions[0].command == "uvx") and
    (.tools.uv.companions[0].version_prefix == "uvx ") and
    (.tools.bats.minimum_version == "1.7.0") and
    (.profiles.core | index("chrome-for-testing")) and
    (.profiles.core | index("open-design")) and
    (.tools.ffmpeg == {type: "apt", command: "ffmpeg", version: "system", package: "ffmpeg"}) and
    (.tools["open-design"].version == "90a660add511da6408464a1bf3d4d5945ad06400") and
    (.profiles.core | index("agent-runtime")) and
    (.profiles.agents | index("opencode")) and
    (.profiles.agents | index("claude")) and
    (.profiles.agents | index("cursor-agent")) and
    (.profiles.agents | index("codex")) and
    (.profiles.default | type == "array") and
    ((.profiles.default | sort) == ((.profiles.core + .profiles.agents) | unique | sort)) and
    ((.profiles.agents | sort) == (.profiles.default | sort)) and
    all(.tools[]; .type and .command and .version)
  ' "$REPO_ROOT/.config/codespace-tools.json"

  [ "$status" -eq 0 ]
}

@test "media profile dispatches apt tools without affecting default profiles" {
  jq '
    .profiles.media = ["fake-apt"] |
    .tools["fake-apt"] = {
      type: "apt",
      command: "fake-apt",
      version: "system",
      package: "fake-apt"
    }
  ' "$TEST_ROOT/manifest.json" >"$TEST_ROOT/media-manifest.json"
  mv "$TEST_ROOT/media-manifest.json" "$TEST_ROOT/manifest.json"

  run_installer --profile media --verify-only

  [ "$status" -ne 0 ]
  [[ "$output" == *"fake-apt is missing"* ]]
}

@test "Bats declarations match the canonical manifest minimum" {
  minimum="$(jq -r '.tools.bats.minimum_version' \
    "$REPO_ROOT/.config/codespace-tools.json")"

  run grep -Rhn '^bats_require_minimum_version ' "$REPO_ROOT/scripts/tests" --include='*.bats'

  [ "$status" -eq 0 ]
  while IFS= read -r declaration; do
    [ "${declaration##* }" = "$minimum" ]
  done <<<"$output"
}

@test "default install profile includes core and agent tools without changing explicit profiles" {
  run jq -e '
    (.profiles.core | index("opencode") | not) and
    (.profiles.agents | index("shfmt")) and
    (.profiles.agents | index("opencode")) and
    (.profiles.default == .profiles.agents)
  ' "$REPO_ROOT/.config/codespace-tools.json"
  [ "$status" -eq 0 ]
}

@test "locked npm project installs once and then verifies without reinstalling" {
  mkdir -p "$TEST_ROOT/runtime"
  printf '%s\n' '{"name":"test-runtime","private":true}' >"$TEST_ROOT/runtime/package.json"
  printf '%s\n' '{"lockfileVersion":3,"packages":{}}' >"$TEST_ROOT/runtime/package-lock.json"
  jq --arg path "$TEST_ROOT/runtime" '
    .profiles.core = ["agent-runtime"] |
    .tools = {
      "agent-runtime": {
        type: "npm-project",
        command: "node",
        version: "locked",
        path: $path
      }
    }
  ' "$TEST_ROOT/manifest.json" >"$TEST_ROOT/npm-manifest.json"
  mv "$TEST_ROOT/npm-manifest.json" "$TEST_ROOT/manifest.json"
  cat >"$BIN_DIR/npm" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "ls" ]]; then
  [[ -f "$NPM_PROJECT/.installed" ]]
  exit
fi
if [[ "$1" == "ci" ]]; then
  touch "$NPM_PROJECT/.installed"
  printf 'ci\n' >>"$NPM_LOG"
  exit
fi
exit 2
EOF
  chmod +x "$BIN_DIR/npm"

  NPM_PROJECT="$TEST_ROOT/runtime" NPM_LOG="$TEST_ROOT/npm.log" run_installer --profile core
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed agent-runtime from lockfile"* ]]

  NPM_PROJECT="$TEST_ROOT/runtime" NPM_LOG="$TEST_ROOT/npm.log" run_installer --profile core --verify-only
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent-runtime lockfile dependencies already installed"* ]]
  [ "$(wc -l <"$TEST_ROOT/npm.log" | tr -d ' ')" -eq 1 ]
}

@test "apt package installation excludes the unrelated Yarn repository" {
  mkdir -p "$TEST_ROOT/apt-sources"
  printf '%s\n' 'deb https://dl.yarnpkg.com/debian stable main' >"$TEST_ROOT/apt-sources/yarn.list"
  printf '%s\n' 'deb https://packages.microsoft.com/repos/test stable main' >"$TEST_ROOT/apt-sources/microsoft.list"
  jq '
    .apt_packages = [{command: "missing-apt-tool", package: "fake-package"}] |
    .profiles.core = [] |
    .tools = {}
  ' "$TEST_ROOT/manifest.json" >"$TEST_ROOT/apt-manifest.json"
  mv "$TEST_ROOT/apt-manifest.json" "$TEST_ROOT/manifest.json"
  cat >"$BIN_DIR/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sourceparts=""
for argument in "$@"; do
  case "$argument" in
    Dir::Etc::sourceparts=*) sourceparts="${argument#*=}" ;;
  esac
done
if [[ " $* " == *" update "* ]]; then
  [[ -n "$sourceparts" ]]
  [[ ! -e "$sourceparts/yarn.list" ]]
  [[ -e "$sourceparts/microsoft.list" ]]
  printf 'update\n' >>"$APT_LOG"
  exit 0
fi
if [[ " $* " == *" install "* ]]; then
  printf 'install\n' >>"$APT_LOG"
  exit 0
fi
exit 2
EOF
  chmod +x "$BIN_DIR/apt-get"
  cat >"$BIN_DIR/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
  chmod +x "$BIN_DIR/sudo"
  export CODESPACE_APT_SOURCE_PARTS="$TEST_ROOT/apt-sources"
  export APT_LOG="$TEST_ROOT/apt.log"

  run_installer --profile core

  [ "$status" -eq 0 ]
  [ "$(tr '\n' ' ' <"$APT_LOG")" = "update install " ]
}

@test "unknown profile is rejected before installation" {
  run_installer --profile unknown

  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown profile: unknown"* ]]
  [ ! -e "$PREFIX/bin/fake-tool" ]
}

@test "matching binary version is skipped" {
  cp "$TEST_ROOT/artifact/fake-tool" "$PREFIX/bin/fake-tool"
  cp "$TEST_ROOT/artifact/fake-tool-alias" "$PREFIX/bin/fake-tool-alias"

  run_installer --profile core

  [ "$status" -eq 0 ]
  [[ "$output" == *"fake-tool 1.2.3 already installed"* ]]
  [ "$("$PREFIX/bin/fake-tool-alias" --version)" = "fake-tool-alias 1.2.3" ]
}

@test "missing or mismatched binary is replaced by verified artifact" {
  printf '#!/usr/bin/env bash\nprintf "fake-tool 0.1.0\\n"\n' >"$PREFIX/bin/fake-tool"
  chmod +x "$PREFIX/bin/fake-tool"

  run_installer --profile core

  [ "$status" -eq 0 ]
  [[ "$output" == *"installed fake-tool 1.2.3"* ]]
  [ "$("$PREFIX/bin/fake-tool" --version)" = "fake-tool 1.2.3" ]
  [ "$("$PREFIX/bin/fake-tool-alias" --version)" = "fake-tool-alias 1.2.3" ]
}

@test "verify-only rejects a matching binary whose declared companion is missing" {
  cp "$TEST_ROOT/artifact/fake-tool" "$PREFIX/bin/fake-tool"

  run_installer --profile core --verify-only

  [ "$status" -ne 0 ]
  [[ "$output" == *"fake-tool 1.2.3 is missing or mismatched"* ]]
}

@test "install replaces a companion with matching version but wrong identity" {
  cp "$TEST_ROOT/artifact/fake-tool" "$PREFIX/bin/fake-tool"
  cp "$TEST_ROOT/artifact/fake-tool" "$PREFIX/bin/fake-tool-alias"

  run_installer --profile core

  [ "$status" -eq 0 ]
  [[ "$output" == *"installed fake-tool 1.2.3"* ]]
  [ "$("$PREFIX/bin/fake-tool-alias" --version)" = "fake-tool-alias 1.2.3" ]
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

@test "Open Design bootstrap selects its locked Node runtime through NVM" {
  mkdir -p "$TEST_ROOT/repo" "$TEST_ROOT/home"
  lock_path="$TEST_ROOT/open-design.lock"
  bootstrap_path="$TEST_ROOT/open-design-bootstrap.sh"
  lock_relative="$(realpath --relative-to="$REPO_ROOT" "$lock_path")"
  bootstrap_relative="$(realpath --relative-to="$REPO_ROOT" "$bootstrap_path")"

  printf 'node: ~24\npnpm: 10.33.2\n' >"$lock_path"
  cat >"$TEST_ROOT/nvm.sh" <<'EOF'
#!/usr/bin/env bash
nvm() {
  printf '%s\n' "$*" >>"$NVM_LOG"
  case "$1" in
    install | use) touch "$HOME/node24" ;;
  esac
}
EOF
  cat >"$bootstrap_path" <<'EOF'
#!/usr/bin/env bash
printf 'node=%s\n' "$(node --version)" >"$BOOTSTRAP_LOG"
EOF
  cat >"$BIN_DIR/node" <<'EOF'
#!/usr/bin/env bash
if [[ -e "$HOME/node24" ]]; then
  printf 'v24.14.0\n'
else
  printf 'v22.15.0\n'
fi
EOF
  chmod +x "$TEST_ROOT/nvm.sh" "$bootstrap_path" "$BIN_DIR/node"

  jq --arg lock "$lock_relative" --arg bootstrap "$bootstrap_relative" '
    .profiles = {core: ["open-design"], agents: ["open-design"], default: ["open-design"]} |
    .tools = {"open-design": {
      type: "open-design",
      command: "od.mjs",
      version: "commit",
      lock: $lock,
      bootstrap: $bootstrap
    }}
  ' "$TEST_ROOT/manifest.json" >"$TEST_ROOT/open-design-manifest.json"

  run env HOME="$TEST_ROOT/home" NVM_DIR="$TEST_ROOT" NVM_LOG="$TEST_ROOT/nvm.log" \
    BOOTSTRAP_LOG="$TEST_ROOT/bootstrap.log" PATH="$BIN_DIR:$PREFIX/bin:$PATH" \
    bash "$INSTALLER" --manifest "$TEST_ROOT/open-design-manifest.json" --prefix "$PREFIX"

  [ "$status" -eq 0 ]
  run grep -Fx 'install 24' "$TEST_ROOT/nvm.log"
  [ "$status" -eq 0 ]
  run grep -Fx 'alias default 24' "$TEST_ROOT/nvm.log"
  [ "$status" -eq 0 ]
  run grep -Fx 'use 24' "$TEST_ROOT/nvm.log"
  [ "$status" -eq 0 ]
  run grep -Fx 'node=v24.14.0' "$TEST_ROOT/bootstrap.log"
  [ "$status" -eq 0 ]

  rm "$TEST_ROOT/home/node24"
  : >"$TEST_ROOT/nvm.log"
  run env HOME="$TEST_ROOT/home" NVM_DIR="$TEST_ROOT" NVM_LOG="$TEST_ROOT/nvm.log" \
    BOOTSTRAP_LOG="$TEST_ROOT/bootstrap.log" PATH="$BIN_DIR:$PREFIX/bin:$PATH" \
    bash "$INSTALLER" --manifest "$TEST_ROOT/open-design-manifest.json" --prefix "$PREFIX" \
    --verify-only

  [ "$status" -ne 0 ]
  [[ "$output" == *"Open Design requires Node.js 24"* ]]
  [ ! -s "$TEST_ROOT/nvm.log" ]
}
