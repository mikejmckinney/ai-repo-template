#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sandbox-sync-test.XXXXXX")"
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/repo"
  GIT_LOG="$TEST_ROOT/git-args"
  ASKPASS_PATH_LOG="$TEST_ROOT/askpass-path"
  ASKPASS_MODE_LOG="$TEST_ROOT/askpass-mode"
  REMOTE_RESET_LOG="$TEST_ROOT/remote-reset"
  export GIT_LOG ASKPASS_PATH_LOG ASKPASS_MODE_LOG REMOTE_RESET_LOG
  cat >"$TEST_ROOT/bin/git" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GIT_LOG"
case "$*" in
  *"rev-parse --is-inside-work-tree"*) printf '%s\n' true ;;
  *"remote get-url origin"*) printf '%s\n' 'https://github.com/acme/project.git' ;;
  *"remote get-url sandbox"*)
    if [[ "${TOKEN_REMOTE:-false}" == true && ! -f "$REMOTE_RESET_LOG" ]]; then
      printf '%s\n' 'https://x-access-token:sentinel-secret@github.com/acme/project-sandbox.git'
    else
      printf '%s\n' 'https://github.com/acme/project-sandbox.git'
    fi
    ;;
  *"remote set-url sandbox"*) : >"$REMOTE_RESET_LOG" ;;
  *"push "*)
    printf '%s\n' "$GIT_ASKPASS" >"$ASKPASS_PATH_LOG"
    stat -c '%a' "$GIT_ASKPASS" >"$ASKPASS_MODE_LOG"
    [ "$("$GIT_ASKPASS" 'Username for https://github.com')" = x-access-token ]
    [ "$("$GIT_ASKPASS" 'Password for https://github.com')" = sentinel-secret ]
    [[ "${FAIL_PUSH:-false}" != true ]] || exit 23
    ;;
esac
EOF
  cat >"$TEST_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "repo view") printf '%s\n' acme ;;
  "pr list") printf '%s\n' '' ;;
  "pr create") printf '%s\n' 'https://github.com/acme/project-sandbox/pull/1' ;;
esac
EOF
  chmod +x "$TEST_ROOT/bin/git" "$TEST_ROOT/bin/gh"
}

@test "sandbox sync redacts a configured token remote and cleans up after push failure" {
  export PATH="$TEST_ROOT/bin:$PATH"
  export FIX_JOB_SANDBOX_VERIFY=true
  export GITHUB_REPOSITORY=acme/project
  export SANDBOX_BOOTSTRAP_TOKEN=sentinel-secret
  export TOKEN_REMOTE=true
  export FAIL_PUSH=true
  printf '%s\n' body >"$TEST_ROOT/body.md"
  source "$REPO_ROOT/scripts/workflows/lib/sandbox-sync-fix-branch.sh"

  run --separate-stderr sandbox_sync_fix_branch \
    "$TEST_ROOT/repo" test/fix-branch title "$TEST_ROOT/body.md"

  [ "$status" -ne 0 ]
  [[ "$output$stderr" != *"sentinel-secret"* ]]
  [[ "$(cat "$GIT_LOG")" != *"sentinel-secret"* ]]
  [ -f "$REMOTE_RESET_LOG" ]
  [ ! -e "$(cat "$ASKPASS_PATH_LOG")" ]
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "sandbox sync keeps token out of git argv and removes askpass helper" {
  old_gh_token=caller-token
  export GH_TOKEN="$old_gh_token"
  export PATH="$TEST_ROOT/bin:$PATH"
  export FIX_JOB_SANDBOX_VERIFY=true
  export GITHUB_REPOSITORY=acme/project
  export SANDBOX_BOOTSTRAP_TOKEN=sentinel-secret
  printf '%s\n' body >"$TEST_ROOT/body.md"
  source "$REPO_ROOT/scripts/workflows/lib/sandbox-sync-fix-branch.sh"

  run --separate-stderr sandbox_sync_fix_branch \
    "$TEST_ROOT/repo" test/fix-branch title "$TEST_ROOT/body.md"

  [ "$status" -eq 0 ]
  [ "$output" = 'https://github.com/acme/project-sandbox/pull/1' ]
  [[ "$output$stderr" != *"sentinel-secret"* ]]
  [[ "$(cat "$GIT_LOG")" != *"sentinel-secret"* ]]
  [[ "$(cat "$GIT_LOG")" != *"x-access-token:"* ]]
  [ "$(cat "$ASKPASS_MODE_LOG")" = 700 ]
  [ ! -e "$(cat "$ASKPASS_PATH_LOG")" ]
  [ "$GH_TOKEN" = "$old_gh_token" ]
}
