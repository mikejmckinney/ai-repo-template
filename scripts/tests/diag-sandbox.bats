#!/usr/bin/env bats
#
# scripts/tests/diag-sandbox.bats — fixture tests for scripts/diag-sandbox.sh
# (issue #365).
#
# All tests use stub bins prepended to PATH to mock external commands
# (gh, git, timeout) without making real network calls or mutating state.
#
# Non-mutation contract: verified by asserting no git push / branch -d /
# branch --delete commands appear in any stub invocation log.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
  SCRIPT="$REPO_ROOT/scripts/diag-sandbox.sh"
  export SCRIPT
}

setup() {
  STUB_BIN="$(mktemp -d "${TMPDIR:-/tmp}/check-115.XXXXXX")"
  INVOCATIONS_LOG="$(mktemp "${TMPDIR:-/tmp}/check-115.XXXXXX")"
  export STUB_BIN INVOCATIONS_LOG
}

teardown() {
  rm -rf "$STUB_BIN"
  rm -f "$INVOCATIONS_LOG"
}

# ── Shared stub helpers ────────────────────────────────────────────────────────

# Add an executable stub to STUB_BIN that logs its invocation then runs BODY.
_add_stub() {
  local name="$1" body="$2"
  printf '#!/usr/bin/env bash\nprintf "%%s %%s\n" "%s" "$*" >> "%s"\n%s\n' \
    "$name" "$INVOCATIONS_LOG" "$body" >"$STUB_BIN/$name"
  chmod +x "$STUB_BIN/$name"
}

# Assert that no destructive git commands were logged.
_assert_no_mutations() {
  local log_content=""
  log_content=$(cat "$INVOCATIONS_LOG" 2>/dev/null || true)
  [[ "$log_content" != *"push"* ]]
  [[ "$log_content" != *"branch -d"* ]]
  [[ "$log_content" != *"branch --delete"* ]]
  [[ "$log_content" != *"branch -D"* ]]
  [[ "$log_content" != *"force-push"* ]]
}

# ── Tests ─────────────────────────────────────────────────────────────────────

@test "diag-sandbox: script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "diag-sandbox: passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "diag-sandbox: empty sandbox remote reports no branches found" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       exit 0
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'shift; exec "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES="" \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 0 branch(es) on sandbox remote"* ]]
  [[ "$output" == *"No branches found on sandbox remote"* ]]
}

@test "diag-sandbox: passes shellcheck (no errors)" {
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi
  run shellcheck --severity=error "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "diag-sandbox: missing gh exits 1 with explicit error" {
  _isolated_bin=$(mktemp -d "${TMPDIR:-/tmp}/check-115.XXXXXX")
  for _t in bash dirname; do
    _rp=$(command -v "$_t" 2>/dev/null || true)
    [[ -n "$_rp" ]] && ln -sf "$_rp" "$_isolated_bin/$_t" 2>/dev/null || true
  done

  run env PATH="$_isolated_bin" bash "$SCRIPT" 2>&1
  rm -rf "$_isolated_bin"
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh is required but not installed"* ]]
}

@test "diag-sandbox: missing git exits 1 with explicit error" {
  _isolated_bin=$(mktemp -d "${TMPDIR:-/tmp}/check-115.XXXXXX")
  for _t in bash dirname; do
    _rp=$(command -v "$_t" 2>/dev/null || true)
    [[ -n "$_rp" ]] && ln -sf "$_rp" "$_isolated_bin/$_t" 2>/dev/null || true
  done
  printf '#!/usr/bin/env bash\nexit 0\n' >"$_isolated_bin/gh"
  chmod +x "$_isolated_bin/gh"

  run env PATH="$_isolated_bin" bash "$SCRIPT" 2>&1
  rm -rf "$_isolated_bin"
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 1 ]
  [[ "$output" == *"git is required but not installed"* ]]
}

@test "diag-sandbox: Codespaces GITHUB_TOKEN auth-source detected and warns" {
  # Mock gh to report GITHUB_TOKEN auth source.
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (GITHUB_TOKEN)"; exit 0
     fi
     exit 0'
  # Mock git: remote get-url succeeds; ls-remote returns a branch list.
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       printf "abc123\trefs/heads/main\n"; exit 0
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'shift; exec "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES=true \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [[ "$output" == *"GITHUB_TOKEN"* ]]
  [[ "$output" == *"may lack sandbox"* ]]
}

@test "diag-sandbox: Codespaces PAT variable probe — GH_PAT found first" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (GITHUB_TOKEN)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       printf "abc123\trefs/heads/main\n"; exit 0
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'shift; exec "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES=true \
    GH_PAT=fake-pat-value \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  # Should report GH_PAT as the found variable.
  [[ "$output" == *"GH_PAT"* ]]
  [[ "$output" == *"PAT upgrade available"* ]]
}

@test "diag-sandbox: Codespaces PAT probe — falls back to GITHUB_PAT when GH_PAT unset" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (GITHUB_TOKEN)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       printf "abc123\trefs/heads/main\n"; exit 0
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'shift; exec "$@"'

  # Unset PAT variables that rank above GITHUB_PAT in the probe list so the
  # fallback to GITHUB_PAT is actually tested (GH_PAT may be set in Codespaces).
  run env -u GH_PAT -u GH_TOKEN_PAT -u CODESPACES_GH_PAT \
    PATH="$STUB_BIN:$PATH" \
    CODESPACES=true \
    GITHUB_PAT=fake-github-pat \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [[ "$output" == *"GITHUB_PAT"* ]]
  [[ "$output" == *"PAT upgrade available"* ]]
}

@test "diag-sandbox: Codespaces with non-GITHUB_TOKEN auth reports active identity" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       printf "abc123\trefs/heads/main\n"; exit 0
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'shift; exec "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES=true \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [[ "$output" == *"gh auth active (non-GITHUB_TOKEN): Logged in to github.com"* ]]
}

@test "diag-sandbox: Codespaces without gh auth warns explicitly" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "You are not logged into any GitHub hosts. Run gh auth login to authenticate." >&2; exit 1
     fi
     exit 1'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       printf "abc123\trefs/heads/main\n"; exit 0
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'shift; exec "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES=true \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh auth status failed"* ]]
  [[ "$output" == *"Run: gh auth login"* ]]
}

@test "diag-sandbox: non-Codespaces reports active identity" {
  # Outside Codespaces: gh auth status returns a normal identity.
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       printf "abc123\trefs/heads/main\n"; exit 0
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'shift; exec "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES="" \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [[ "$output" == *"Not running in Codespaces"* ]]
  [[ "$output" == *"Logged in to github.com"* ]]
}

@test "diag-sandbox: auth-error exits 1 before reachability checks" {
  # gh auth status fails (not logged in); the doctor should stop before remote probes.
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "You are not logged into any GitHub hosts."; exit 1
     fi
     exit 1'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       echo "ERROR: authentication required"; exit 128
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'shift; exec "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES="" \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh auth status failed"* ]]
  [[ "$output" == *"Run: gh auth login"* ]]
  log_content=$(cat "$INVOCATIONS_LOG" 2>/dev/null || true)
  [[ "$log_content" != *"git remote get-url"* ]]
  [[ "$log_content" != *"git ls-remote"* ]]
}

@test "diag-sandbox: timeout path (exit 124) warns and exits 2" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     /usr/bin/git "$@"'
  # timeout stub returns 124 for ls-remote calls.
  _add_stub "timeout" 'exit 124'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES="" \
    SANDBOX_REMOTE=sandbox \
    DIAG_GIT_TIMEOUT=10 \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [ "$status" -eq 2 ]
  [[ "$output" == *"timed out after"* ]]
}

@test "diag-sandbox: DIAG_GIT_TIMEOUT=0 bypasses timeout wrapper" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       printf "abc123\trefs/heads/main\n"; exit 0
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'echo "timeout wrapper should not run" >&2; exit 99'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES="" \
    SANDBOX_REMOTE=sandbox \
    DIAG_GIT_TIMEOUT=0 \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [ "$status" -eq 0 ]
  ! grep -q '^timeout ' "$INVOCATIONS_LOG"
}

@test "diag-sandbox: DIAG_GIT_TIMEOUT=0 redacts transport errors" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://x-access-token:supersecret@github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       echo "fatal: could not read from https://x-access-token:supersecret@github.com/test/test-sandbox.git" >&2; exit 128
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'echo "timeout wrapper should not run" >&2; exit 99'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES="" \
    SANDBOX_REMOTE=sandbox \
    DIAG_GIT_TIMEOUT=0 \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [ "$status" -eq 2 ]
  ! grep -q '^timeout ' "$INVOCATIONS_LOG"
  [[ "$output" == *"https://***@github.com/test/test-sandbox.git"* ]]
  [[ "$output" != *"supersecret"* ]]
}

@test "diag-sandbox: timeout-absent fallback — warns and proceeds with bare git ls-remote" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       printf "abc123\trefs/heads/main\n"; exit 0
     fi
     /usr/bin/git "$@"'
  # Do NOT add a timeout stub — it must be absent so the fallback path triggers.
  # timeout is at /bin/timeout AND /usr/bin/timeout, so PATH stripping alone is
  # insufficient.  Build an isolated stub_bin that has all tools the script needs
  # (dirname, grep, wc, tr, head, bash) but NOT timeout, then use PATH=stub_bin only.
  _isolated_bin=$(mktemp -d "${TMPDIR:-/tmp}/check-115.XXXXXX")
  for _t in bash dirname grep sed wc tr head; do
    _rp=$(command -v "$_t" 2>/dev/null || true)
    [[ -n "$_rp" ]] && ln -sf "$_rp" "$_isolated_bin/$_t" 2>/dev/null || true
  done
  # Copy the gh and git stubs from STUB_BIN into the isolated bin.
  cp "$STUB_BIN/gh" "$_isolated_bin/gh"
  cp "$STUB_BIN/git" "$_isolated_bin/git"

  run env PATH="$_isolated_bin" \
    CODESPACES="" \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  rm -rf "$_isolated_bin"
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [[ "$output" == *"timeout command unavailable"* ]]
  # Fallback should have proceeded and not exited 2 (reachable with bare git).
  [ "$status" -eq 0 ]
}

@test "diag-sandbox: missing sandbox remote prints advisory and exits 2" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  # git stub: remote get-url fails (no such remote).
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "error: No such remote: nonexistent-remote-xyz" >&2; exit 2
     fi
     /usr/bin/git "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES="" \
    SANDBOX_REMOTE=nonexistent-remote-xyz \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [ "$status" -eq 2 ]
  [[ "$output" == *"not configured"* ]]
  [[ "$output" == *"Advisory"* ]]
}

@test "diag-sandbox: redacts credentials in logged remote URLs and transport errors" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://x-access-token:supersecret@github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       echo "fatal: could not read from https://x-access-token:supersecret@github.com/test/test-sandbox.git" >&2; exit 128
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'shift; exec "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES="" \
    SANDBOX_REMOTE=sandbox \
    DIAG_GIT_TIMEOUT=10 \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [ "$status" -eq 2 ]
  [[ "$output" == *"https://***@github.com/test/test-sandbox.git"* ]]
  [[ "$output" != *"supersecret"* ]]
}

@test "diag-sandbox: outside git repo exits 1 instead of misreporting missing remote" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "rev-parse" && "$2" == "--git-dir" ]]; then
       echo "fatal: not a git repository" >&2; exit 128
     fi
     if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     /usr/bin/git "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES="" \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [ "$status" -eq 1 ]
  [[ "$output" == *"Current directory is not a git repository"* ]]
  [[ "$output" != *"not configured"* ]]
  log_content=$(cat "$INVOCATIONS_LOG" 2>/dev/null || true)
  [[ "$log_content" == *"git rev-parse --git-dir"* ]]
  [[ "$log_content" != *"git remote get-url"* ]]
}

@test "diag-sandbox: non-mutation contract — no git push or branch -d in any stub log" {
  # Run a happy-path scenario and confirm the invocation log has no mutations.
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       printf "abc123\trefs/heads/main\nabc456\trefs/heads/feature/old-test\n"; exit 0
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'shift; exec "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES="" \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 0 ]
  _assert_no_mutations
  # Stale branch reported in output (non-destructive).
  [[ "$output" == *"feature/old-test"* ]] || [[ "$output" == *"Non-main branches"* ]]
}

@test "diag-sandbox: stale branch reporting mock — non-main branches listed as warning" {
  _add_stub "gh" \
    'if [[ "$*" == *"auth status"* ]]; then
       echo "Logged in to github.com account testuser (oauth_token)"; exit 0
     fi
     exit 0'
  _add_stub "git" \
    'if [[ "$1" == "remote" && "$2" == "get-url" ]]; then
       echo "https://github.com/test/test-sandbox.git"; exit 0
     fi
     if [[ "$1" == "ls-remote" ]]; then
       printf "abc123\trefs/heads/main\nabc456\trefs/heads/test/stale-branch\n"; exit 0
     fi
     /usr/bin/git "$@"'
  _add_stub "timeout" 'shift; exec "$@"'

  run env PATH="$STUB_BIN:$PATH" \
    CODESPACES="" \
    SANDBOX_REMOTE=sandbox \
    bash "$SCRIPT" 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  _assert_no_mutations
  [ "$status" -eq 0 ]
  [[ "$output" == *"Non-main branches found"* ]]
  [[ "$output" == *"test/stale-branch"* ]] || [[ "$output" == *"stale-branch"* ]]
}
