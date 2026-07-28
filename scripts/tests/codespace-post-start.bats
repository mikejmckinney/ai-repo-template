#!/usr/bin/env bats
#
# scripts/tests/codespace-post-start.bats — codespace-post-start.sh smoke tests.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
  SCRIPT="$REPO_ROOT/scripts/codespace-post-start.sh"
  export SCRIPT
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
  if [[ "$*" == *"nameWithOwner"* ]]; then
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
  [[ "$output" == *"OpenCode OAuth access synchronized"* ]]
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
if [[ "$1" == "repo" && "$2" == "view" ]]; then echo "example/my-repo"; exit 0; fi
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
