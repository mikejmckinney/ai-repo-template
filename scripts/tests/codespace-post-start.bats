#!/usr/bin/env bats
#
# scripts/tests/codespace-post-start.bats — codespace-post-start.sh smoke tests.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
  SCRIPT="$REPO_ROOT/scripts/codespace-post-start.sh"
  export SCRIPT
  export CODESPACE_POST_START_PREWARM=/bin/true
  SYNC_SCRIPT="$REPO_ROOT/scripts/codespace-sync-opencode-oauth.sh"
  export SYNC_SCRIPT
}

@test "Codespace lifecycle retries OAuth sync on attach through one entrypoint" {
  [ -x "$SYNC_SCRIPT" ]
  [ "$(jq -r .postAttachCommand "$REPO_ROOT/.devcontainer/devcontainer.json")" = \
    "bash scripts/codespace-sync-opencode-oauth.sh" ]
  grep -q 'codespace-sync-opencode-oauth.sh' "$SCRIPT"
  grep -q -- '--apply --if-changed' "$SYNC_SCRIPT"
}

@test "codespace-post-start owns non-fatal Open Design readiness" {
  grep -q 'mcp-prewarm.sh' "$SCRIPT"
  grep -q -- '--readiness-only' "$SCRIPT"
  grep -q 'MCP readiness check failed' "$SCRIPT"
}

@test "codespace-post-start: exits 0 outside Codespaces" {
  run env -u CODESPACES bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Not a Codespace"* ]]
}

@test "codespace-post-start: adds sandbox remote when missing in Codespaces" {
  local stub_bin tmp_repo
  stub_bin="$(mktemp -d)"
  tmp_repo="$(mktemp -d)"
  git init -q "$tmp_repo"
  git -C "$tmp_repo" remote add origin https://github.com/example/my-repo.git

  cat >"$stub_bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
  echo "Logged in to github.com account testuser (oauth_token)" >&2
  exit 0
fi
if [[ "$1" == "repo" && "$2" == "view" ]]; then
  if [[ "$*" == *"visibility"* ]]; then
    echo "PRIVATE"
    exit 0
  fi
  echo "example"
  exit 0
fi
exit 0
EOF
  chmod +x "$stub_bin/gh"

  run env CODESPACES=true CODESPACE_POST_START_REPO_ROOT="$tmp_repo" PATH="$stub_bin:$PATH" bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Added sandbox git remote 'sandbox'"* ]]
  git -C "$tmp_repo" remote get-url sandbox | grep -qF 'https://github.com/example/my-repo-sandbox.git'
  rm -rf "$stub_bin" "$tmp_repo"
}

@test "codespace-post-start: syncs OAuth after PAT setup without blocking startup" {
  local stub_bin tmp_home tmp_repo future_ms
  stub_bin="$(mktemp -d)"
  tmp_home="$(mktemp -d)"
  tmp_repo="$(mktemp -d)"
  future_ms="$((($(date +%s) + 10800) * 1000))"
  git init -q "$tmp_repo"
  git -C "$tmp_repo" remote add origin https://github.com/example/my-repo.git
  mkdir -p "$tmp_home/.local/share/opencode"
  jq -n --argjson expires "$future_ms" '{openai:{type:"oauth",access:"access-secret",refresh:"refresh-secret",expires:$expires,accountId:"account-test"}}' \
    >"$tmp_home/.local/share/opencode/auth.json"

  cat >"$stub_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "auth" && "$2" == "status" ]]; then
  echo "Logged in to github.com account testuser (oauth_token)" >&2
  exit 0
fi
if [[ "$1" == "repo" && "$2" == "view" ]]; then
  if [[ "$*" == *"visibility"* ]]; then
    echo "PRIVATE"
  elif [[ "$*" == *"nameWithOwner"* ]]; then
    echo "example/my-repo"
  else
    echo "example"
  fi
  exit 0
fi
if [[ "$1" == "secret" && "$2" == "set" ]]; then
  cat >"$SYNC_PAYLOAD"
  exit "${SYNC_EXIT:-0}"
fi
exit 0
EOF
  chmod +x "$stub_bin/gh"

  run env CODESPACES=true HOME="$tmp_home" CODESPACE_POST_START_REPO_ROOT="$tmp_repo" \
    PATH="$stub_bin:$PATH" SYNC_PAYLOAD="$tmp_home/payload.json" \
    bash "$SCRIPT"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OpenCode OAuth synchronization check completed"* ]]
  [[ "$output" != *"access-secret"* ]]
  [[ "$output" != *"refresh-secret"* ]]
  [ "$(jq -r '.openai.refresh' "$tmp_home/payload.json")" = "ci-refresh-disabled" ]

  rm -rf "$stub_bin" "$tmp_home" "$tmp_repo"
}

@test "codespace-post-start: OAuth sync failure is non-fatal" {
  local stub_bin tmp_home tmp_repo future_ms
  stub_bin="$(mktemp -d)"
  tmp_home="$(mktemp -d)"
  tmp_repo="$(mktemp -d)"
  future_ms="$((($(date +%s) + 10800) * 1000))"
  git init -q "$tmp_repo"
  git -C "$tmp_repo" remote add origin https://github.com/example/my-repo.git
  mkdir -p "$tmp_home/.local/share/opencode"
  jq -n --argjson expires "$future_ms" '{openai:{type:"oauth",access:"access-secret",refresh:"refresh-secret",expires:$expires,accountId:"account-test"}}' \
    >"$tmp_home/.local/share/opencode/auth.json"

  cat >"$stub_bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then exit 0; fi
if [[ "$1" == "repo" && "$2" == "view" ]]; then
  if [[ "$*" == *"visibility"* ]]; then echo "PRIVATE"; else echo "example/my-repo"; fi
  exit 0
fi
if [[ "$1" == "secret" && "$2" == "set" ]]; then cat >/dev/null; exit 1; fi
exit 0
EOF
  chmod +x "$stub_bin/gh"

  run env CODESPACES=true HOME="$tmp_home" CODESPACE_POST_START_REPO_ROOT="$tmp_repo" \
    PATH="$stub_bin:$PATH" bash "$SCRIPT"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OAuth access synchronization failed"* ]]

  rm -rf "$stub_bin" "$tmp_home" "$tmp_repo"
}

@test "codespace-post-start: skips automatic OAuth sync for public repositories" {
  local stub_bin tmp_home tmp_repo future_ms
  stub_bin="$(mktemp -d)"
  tmp_home="$(mktemp -d)"
  tmp_repo="$(mktemp -d)"
  future_ms="$((($(date +%s) + 10800) * 1000))"
  git init -q "$tmp_repo"
  git -C "$tmp_repo" remote add origin https://github.com/example/public-repo.git
  mkdir -p "$tmp_home/.local/share/opencode"
  jq -n --argjson expires "$future_ms" '{openai:{type:"oauth",access:"access-secret",refresh:"refresh-secret",expires:$expires,accountId:"account-test"}}' \
    >"$tmp_home/.local/share/opencode/auth.json"

  cat >"$stub_bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then exit 0; fi
if [[ "$1" == "repo" && "$2" == "view" ]]; then
  if [[ "$*" == *"visibility"* ]]; then echo "PUBLIC"; else echo "example/public-repo"; fi
  exit 0
fi
if [[ "$1" == "secret" && "$2" == "set" ]]; then echo called >"$SYNC_CALLED"; exit 0; fi
exit 0
EOF
  chmod +x "$stub_bin/gh"

  run env CODESPACES=true HOME="$tmp_home" CODESPACE_POST_START_REPO_ROOT="$tmp_repo" \
    PATH="$stub_bin:$PATH" SYNC_CALLED="$tmp_home/sync-called" bash "$SCRIPT"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"not private; skipping automatic OpenCode OAuth synchronization"* ]]
  [ ! -e "$tmp_home/sync-called" ]
  [[ "$output" != *"access-secret"* ]]
  [[ "$output" != *"refresh-secret"* ]]

  rm -rf "$stub_bin" "$tmp_home" "$tmp_repo"
}
