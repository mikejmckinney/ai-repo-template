#!/usr/bin/env bats
#
# scripts/tests/verify-env.bats
#
# Inlined from scripts/test-verify-env.sh by issue #280 (un-wrap legacy delegate).
# The legacy script's body lives as the shell function `_legacy_body`
# inside this file; the @test block invokes it via bats `run` so bats'
# subshell wrapping preserves set -e + EXIT-trap semantics. No external
# scripts/test-*.sh delegate file remains.

# Per-test timeout (seconds). Must be set at file-load time, before any
# test runs (codex/cursor P2 review feedback on PR #274).
export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
  # Exported here so the new fix-mode @test blocks can reference it.
  VERIFY_SCRIPT="$REPO_ROOT/scripts/verify-env.sh"
  SETUP_VERIFY_SCRIPT="$REPO_ROOT/scripts/setup/70-verify-env.sh"
  export VERIFY_SCRIPT
  export SETUP_VERIFY_SCRIPT
}

_legacy_body() {
  set -euo pipefail
  cd "$REPO_ROOT"
  # ===== inlined body of scripts/test-verify-env.sh (issue #280) =====
  # Unit tests for scripts/verify-env.sh (issue #229 Phase 1.5a).
  #
  # Proves legacy marker text is inert in verify-env.sh using isolated fixture
  # directories (minimal git repos). Covers empty, bootstrap-like, overlapping,
  # and mixed paths so no filename can restore marker-based onboarding behavior.
  #
  #   FIXTURE-01  empty        — no marker text
  #   FIXTURE-02  bootstrap    — marker in a historical archive path
  #   FIXTURE-03  overlap      — marker in similarly named paths
  #   FIXTURE-04  mixed        — marker in session and ordinary files
  #
  # Every fixture must produce identical marker-independent verification output.
  #
  # Run: bats --tap scripts/tests/verify-env.bats

  VERIFY_SCRIPT="$REPO_ROOT/scripts/verify-env.sh"

  PASS=0
  FAIL=0
  FAILED_NAMES=()

  # ── helpers ──────────────────────────────────────────────────────────────────

  assert_contains() {
    local name="$1" needle="$2" haystack="$3"
    if printf '%s' "$haystack" | grep -qF "$needle"; then
      PASS=$((PASS + 1))
      printf '  ✅ %s\n' "$name"
    else
      FAIL=$((FAIL + 1))
      FAILED_NAMES+=("$name")
      printf '  ❌ %s\n' "$name"
      printf '       expected to contain: %s\n' "$needle"
    fi
  }

  assert_not_contains() {
    local name="$1" needle="$2" haystack="$3"
    if ! printf '%s' "$haystack" | grep -qF "$needle"; then
      PASS=$((PASS + 1))
      printf '  ✅ %s\n' "$name"
    else
      FAIL=$((FAIL + 1))
      FAILED_NAMES+=("$name")
      printf '  ❌ %s\n' "$name"
      printf '       expected NOT to contain: %s\n' "$needle"
    fi
  }

  # Run verify-env.sh inside a temp fixture dir, return its stdout.
  # Exit code is ignored (it exits non-zero in a bare temp dir due to missing
  # files; we only care about the placeholder-section output).
  run_in_fixture() {
    local fixture_dir="$1"
    cd "$fixture_dir" && bash "$VERIFY_SCRIPT" 2>/dev/null || true
  }

  # ── setup ─────────────────────────────────────────────────────────────────────

  TMP_BASE=$(mktemp -d)
  # shellcheck disable=SC2317  # invoked via trap
  cleanup() { rm -rf "$TMP_BASE"; }
  trap cleanup EXIT

  marker="TEMPLATE_PLACEHOLDER"

  make_fixture() {
    local name="$1"
    local dir="$TMP_BASE/$name"
    mkdir -p "$dir"
    # Must be a git repo so verify-env.sh's git checks pass
    git -C "$dir" init -q
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config user.name "test"
    printf '%s' "$dir"
  }

  echo "========================================"
  echo "verify-env.sh fixture tests (issue #229 §1.5a)"
  echo "========================================"
  echo ""

  # ── FIXTURE-01: empty ─────────────────────────────────────────────────────────
  echo "FIXTURE-01: empty tree"
  D=$(make_fixture "empty")
  out=$(run_in_fixture "$D")
  assert_not_contains "empty: no marker scan output" \
    "TEMPLATE_PLACEHOLDER" "$out"
  assert_not_contains "empty: no unexpected-file warning" \
    "files still contain TEMPLATE_PLACEHOLDER" "$out"
  assert_not_contains "empty: no bootstrap warning" \
    "Bootstrap files retain" "$out"
  echo ""

  # ── FIXTURE-02: bootstrap-only ────────────────────────────────────────────────
  echo "FIXTURE-02: only bootstrap files contain marker"
  D=$(make_fixture "bootstrap")
  mkdir -p "$D/.context/sessions"
  printf '%s\n' "# $marker" >"$D/.context/sessions/marker-fixture.md"
  out=$(run_in_fixture "$D")
  assert_not_contains "bootstrap: no marker scan output" \
    "TEMPLATE_PLACEHOLDER" "$out"
  assert_not_contains "bootstrap: no unexpected-file warning" \
    "files still contain TEMPLATE_PLACEHOLDER" "$out"
  assert_not_contains "bootstrap: no bootstrap warning" \
    "Bootstrap files retain TEMPLATE_PLACEHOLDER" "$out"
  echo ""

  # ── FIXTURE-03: substring-overlap filename ────────────────────────────────────
  echo "FIXTURE-03: substring-overlap filename tests \$-anchor"
  D=$(make_fixture "overlap")
  mkdir -p "$D/.context/sessions"
  printf '%s\n' "# $marker" >"$D/.context/sessions/marker-fixture.md"
  printf '%s\n' "# $marker" >"$D/.context/sessions/marker-fixture.md.bak"
  printf '%s\n' "# $marker" >"$D/.context/sessions/marker-fixtureXmd"
  out=$(run_in_fixture "$D")
  assert_not_contains "overlap: no marker pass output" \
    "No unexpected TEMPLATE_PLACEHOLDER markers found" "$out"
  assert_not_contains "overlap: no unexpected-file warning" \
    "files still contain TEMPLATE_PLACEHOLDER" "$out"
  assert_not_contains "overlap: no bootstrap warning" \
    "Bootstrap files retain TEMPLATE_PLACEHOLDER" "$out"
  echo ""

  # ── FIXTURE-03b: literal-dot near-match ─────────────────────────────────────
  echo "FIXTURE-03b: literal-dot near-match stays unexpected"
  D=$(make_fixture "overlap-dot")
  mkdir -p "$D/.context/sessions"
  printf '%s\n' "# $marker" >"$D/.context/sessions/marker-fixture.md"
  printf '%s\n' "# $marker" >"$D/.context/sessions/marker-fixtureXmd"
  out=$(run_in_fixture "$D")
  assert_not_contains "overlap-dot: no marker pass output" \
    "No unexpected TEMPLATE_PLACEHOLDER markers found" "$out"
  assert_not_contains "overlap-dot: no unexpected-file warning" \
    "files still contain TEMPLATE_PLACEHOLDER" "$out"
  assert_not_contains "overlap-dot: no bootstrap warning" \
    "Bootstrap files retain TEMPLATE_PLACEHOLDER" "$out"
  echo ""

  # ── FIXTURE-04: mixed ─────────────────────────────────────────────────────────
  echo "FIXTURE-04: mixed — unexpected file + bootstrap file"
  D=$(make_fixture "mixed")
  mkdir -p "$D/.context/sessions"
  # Bootstrap (excluded → does NOT count as unexpected)
  printf '%s\n' "# $marker" >"$D/.context/sessions/marker-fixture.md"
  # Unexpected (not matched by either exclusion list)
  printf '%s\n' "# $marker" >"$D/some-real-file.md"
  out=$(run_in_fixture "$D")
  assert_not_contains "mixed: no marker pass output" \
    "No unexpected TEMPLATE_PLACEHOLDER markers found" "$out"
  assert_not_contains "mixed: no unexpected-file warning" \
    "files still contain TEMPLATE_PLACEHOLDER" "$out"
  assert_not_contains "mixed: no bootstrap warning" \
    "Bootstrap files retain TEMPLATE_PLACEHOLDER" "$out"
  echo ""

  # ── summary ──────────────────────────────────────────────────────────────────

  echo "========================================"
  echo "Results"
  echo "========================================"
  printf 'Passed: %d\n' "$PASS"
  printf 'Failed: %d\n' "$FAIL"

  if [[ "${#FAILED_NAMES[@]}" -gt 0 ]]; then
    echo ""
    echo "Failed tests:"
    for n in "${FAILED_NAMES[@]}"; do
      printf '  - %s\n' "$n"
    done
  fi

  echo ""
  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
  # ===== end inlined body =====
}

@test "verify-env: inlined test-verify-env.sh body passes" {
  run _legacy_body
  # Emit captured output as TAP `# ...` comments so the
  # per-assertion ✅/PASS [...] markers from the inlined
  # legacy body remain visible (and grep-able by
  # run_bats_check) even on the success path. (#280 round 3)
  printf '%s
' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Fix-mode test infrastructure (issue #365)
# ---------------------------------------------------------------------------
# The helpers below use stub bins (fully-isolated directories used as PATH)
# to control which tools appear installed and to mock platform commands.

# Create a temp stub bin directory; prints path.
_make_stub_bin() {
  mktemp -d "${TMPDIR:-/tmp}/check-115.XXXXXX"
}

# Write an executable stub into a dir.
# Usage: _add_stub DIR NAME SCRIPT_BODY
_add_stub() {
  local dir="$1" name="$2" body="$3"
  printf '#!/usr/bin/env bash\n%s\n' "$body" >"$dir/$name"
  chmod +x "$dir/$name"
}

# Build a fully-isolated stub bin for fix-mode tests.
# Symlinks every tool verify-env.sh needs to run, EXCEPT those named in
# the remaining arguments (which should appear absent during the test).
# The resulting directory is intended to be used as PATH="$stub_bin" (alone)
# so that /bin and /usr/bin are not in PATH and real rg/sudo cannot be found.
# Usage: _build_fix_env STUB_BIN [tool_to_exclude ...]
_build_fix_env() {
  local stub_bin="$1"
  shift
  # Full list of tools verify-env.sh (and its lib/ helpers) need:
  #   dirname — SCRIPT_DIR computation in verify-env.sh, lib/logging.sh, lib/assertions.sh
  #   chmod   — used inside apt-get/brew stub bodies to make the created rg stub executable
  #   git, head — git checks
  #   grep — command availability checks
  #   python3, pip, pip3 — python checks
  #   shellcheck, jq, uvx, bats — required-tool checks
  local needed=(bash dirname chmod git head grep python3 pip pip3 shellcheck jq uvx bats apt-get)
  local excl=("$@")
  for t in "${needed[@]}"; do
    local skip=false
    for e in "${excl[@]}"; do [[ "$t" == "$e" ]] && skip=true && break; done
    [[ "$skip" == "true" ]] && continue
    local rp
    rp=$(command -v "$t" 2>/dev/null || true)
    [[ -n "$rp" ]] && ln -sf "$rp" "$stub_bin/$t" 2>/dev/null || true
  done
}

@test "verify-env: missing uvx reports the managed uv prerequisite" {
  stub_bin=$(_make_stub_bin)
  _build_fix_env "$stub_bin" uvx

  run env PATH="$stub_bin" bash "$VERIFY_SCRIPT" 2>&1

  rm -rf "$stub_bin"
  [[ "$output" == *"uvx is not installed; install the pinned uv tool profile"* ]]
  [ "$status" -ne 0 ]
}

@test "verify-env: Bats below the canonical floor reports required and observed versions" {
  stub_bin=$(_make_stub_bin)
  _build_fix_env "$stub_bin" bats
  _add_stub "$stub_bin" "bats" 'printf "Bats 1.6.0\n"'

  run env PATH="$stub_bin" bash "$VERIFY_SCRIPT" 2>&1

  rm -rf "$stub_bin"
  [[ "$output" == *"bats 1.6.0 is below required version 1.7.0"* ]]
  [ "$status" -ne 0 ]
}

@test "verify-env: --fix: non-allowlisted tool rejected with advisory and non-zero exit" {
  stub_bin=$(_make_stub_bin)
  # faketool-xyz-365 is guaranteed absent from any real PATH and absent from
  # FIX_ALLOWLIST — triggers the rejection branch.
  run env PATH="$stub_bin:$PATH" \
    _VERIFY_ENV_EXTRA_REQUIRED_TOOLS="faketool-xyz-365" \
    bash "$VERIFY_SCRIPT" --fix 2>&1
  rm -rf "$stub_bin"
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [[ "$output" == *"faketool-xyz-365 is not on the fix allowlist"* ]]
  [ "$status" -ne 0 ]
}

@test "verify-env: --fix: Linux privilege failure (no root, no sudo) prints advisory" {
  stub_bin=$(_make_stub_bin)
  # Build isolated env: all needed tools except rg and sudo.
  _build_fix_env "$stub_bin" rg sudo
  # id stub: non-root; uname stub: Linux.  No sudo, no rg in stub_bin.
  _add_stub "$stub_bin" "id" 'echo "1001"'
  _add_stub "$stub_bin" "uname" 'if [[ "$1" == "-s" ]]; then echo "Linux"; else /usr/bin/uname "$@"; fi'
  # Fully isolated PATH: real sudo at /bin/sudo and /usr/bin/sudo are hidden.
  run env PATH="$stub_bin" bash "$VERIFY_SCRIPT" --fix 2>&1
  rm -rf "$stub_bin"
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [[ "$output" == *"root or sudo required"* ]]
  [ "$status" -ne 0 ]
}

@test "verify-env: --fix: earlier failures suppress package-manager installs" {
  stub_bin=$(_make_stub_bin)
  install_log=$(mktemp "${TMPDIR:-/tmp}/check-115.XXXXXX")
  _build_fix_env "$stub_bin" git rg apt-get
  _add_stub "$stub_bin" "git" \
    'if [[ "$1" == "--version" ]]; then
       echo "git version 2.53.0"; exit 0
     fi
     if [[ "$1" == "rev-parse" ]]; then
       echo "fatal: not a git repository" >&2; exit 128
     fi
     exit 0'
  _add_stub "$stub_bin" "id" 'echo "0"'
  _add_stub "$stub_bin" "uname" 'if [[ "$1" == "-s" ]]; then echo "Linux"; else /usr/bin/uname "$@"; fi'
  _add_stub "$stub_bin" "apt-get" \
    'printf "[fix-stub] apt-get called: %s\n" "$*" >> "$INSTALL_LOG"; exit 0'

  run env PATH="$stub_bin" INSTALL_LOG="$install_log" bash "$VERIFY_SCRIPT" --fix 2>&1
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [[ "$output" == *"Current directory is not a git repository"* ]]
  [[ "$output" == *"rg is not installed"* ]]
  [[ "$output" != *"Installing rg via"* ]]
  [ ! -s "$install_log" ]
  [ "$status" -ne 0 ]

  rm -f "$install_log"
  rm -rf "$stub_bin"
}

@test "verify-env: --fix: Linux root path invokes apt-get directly for rg" {
  stub_bin=$(_make_stub_bin)
  # Build isolated env: all needed tools except rg (apt-get stub will create it).
  _build_fix_env "$stub_bin" rg apt-get
  _add_stub "$stub_bin" "id" 'echo "0"'
  _add_stub "$stub_bin" "uname" 'if [[ "$1" == "-s" ]]; then echo "Linux"; else /usr/bin/uname "$@"; fi'
  # apt-get stub: log invocation and create the rg stub so post-install check passes.
  _add_stub "$stub_bin" "apt-get" \
    'printf "[fix-stub] apt-get called: %s\n" "$*"; self_dir=$(dirname "$0"); printf "#!/bin/bash\nexit 0\n" > "$self_dir/rg"; chmod +x "$self_dir/rg"'
  run env PATH="$stub_bin" bash "$VERIFY_SCRIPT" --fix 2>&1
  rm -rf "$stub_bin"
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [[ "$output" == *"apt-get install -y ripgrep (root)"* ]]
  [ "$status" -eq 0 ]
}

@test "verify-env: --fix: Linux sudo path invokes sudo apt-get for rg" {
  stub_bin=$(_make_stub_bin)
  # Build isolated env: all needed tools except rg.
  _build_fix_env "$stub_bin" rg apt-get
  _add_stub "$stub_bin" "id" 'echo "1001"'
  _add_stub "$stub_bin" "uname" 'if [[ "$1" == "-s" ]]; then echo "Linux"; else /usr/bin/uname "$@"; fi'
  # sudo stub: delegate to the actual command (apt-get in stub_bin).
  _add_stub "$stub_bin" "sudo" 'exec "$@"'
  # apt-get stub: log and create rg stub.
  _add_stub "$stub_bin" "apt-get" \
    'printf "[fix-stub] apt-get called: %s\n" "$*"; self_dir=$(dirname "$0"); printf "#!/bin/bash\nexit 0\n" > "$self_dir/rg"; chmod +x "$self_dir/rg"'
  run env PATH="$stub_bin" bash "$VERIFY_SCRIPT" --fix 2>&1
  rm -rf "$stub_bin"
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [[ "$output" == *"sudo apt-get install -y ripgrep"* ]]
  [ "$status" -eq 0 ]
}

@test "verify-env: --fix: macOS path invokes brew install for rg" {
  stub_bin=$(_make_stub_bin)
  # Build isolated env: all needed tools except rg (brew stub will create it).
  _build_fix_env "$stub_bin" rg
  _add_stub "$stub_bin" "uname" 'if [[ "$1" == "-s" ]]; then echo "Darwin"; else /usr/bin/uname "$@"; fi'
  # brew stub: log and create rg stub so post-install check passes.
  _add_stub "$stub_bin" "brew" \
    'printf "[fix-stub] brew called: %s\n" "$*"; self_dir=$(dirname "$0"); printf "#!/bin/bash\nexit 0\n" > "$self_dir/rg"; chmod +x "$self_dir/rg"'
  run env PATH="$stub_bin" bash "$VERIFY_SCRIPT" --fix 2>&1
  rm -rf "$stub_bin"
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [[ "$output" == *"brew install ripgrep"* ]]
  [ "$status" -eq 0 ]
}

@test "verify-env: --fix: macOS without brew prints advisory" {
  stub_bin=$(_make_stub_bin)
  _build_fix_env "$stub_bin" rg brew
  _add_stub "$stub_bin" "uname" 'if [[ "$1" == "-s" ]]; then echo "Darwin"; else /usr/bin/uname "$@"; fi'
  run env PATH="$stub_bin" bash "$VERIFY_SCRIPT" --fix 2>&1
  rm -rf "$stub_bin"
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [[ "$output" == *"brew is required on macOS"* ]]
  [ "$status" -ne 0 ]
}

@test "verify-env: --fix: Linux without apt-get prints advisory" {
  stub_bin=$(_make_stub_bin)
  _build_fix_env "$stub_bin" rg apt-get
  _add_stub "$stub_bin" "id" 'echo "0"'
  _add_stub "$stub_bin" "uname" 'if [[ "$1" == "-s" ]]; then echo "Linux"; else /usr/bin/uname "$@"; fi'
  run env PATH="$stub_bin" bash "$VERIFY_SCRIPT" --fix 2>&1
  rm -rf "$stub_bin"
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [[ "$output" == *"apt-get is required on this Linux system"* ]]
  [ "$status" -ne 0 ]
}

@test "verify-env: uname OS-branch: Darwin branch taken when uname returns Darwin" {
  stub_bin=$(_make_stub_bin)
  # Build isolated env: all needed tools except rg.
  _build_fix_env "$stub_bin" rg
  _add_stub "$stub_bin" "uname" 'if [[ "$1" == "-s" ]]; then echo "Darwin"; else /usr/bin/uname "$@"; fi'
  _add_stub "$stub_bin" "brew" \
    'printf "[fix-stub] brew called: %s\n" "$*"; self_dir=$(dirname "$0"); printf "#!/bin/bash\nexit 0\n" > "$self_dir/rg"; chmod +x "$self_dir/rg"'
  run env PATH="$stub_bin" bash "$VERIFY_SCRIPT" --fix 2>&1
  rm -rf "$stub_bin"
  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  # Verify Linux apt-get path was NOT taken.
  [[ "$output" != *"apt-get"* ]]
  [[ "$output" == *"brew install"* ]]
}

@test "setup 70-verify-env invokes verify-env with --fix" {
  temp_repo=$(mktemp -d "${TMPDIR:-/tmp}/check-115.XXXXXX")
  mkdir -p "$temp_repo/scripts/setup"
  cp "$SETUP_VERIFY_SCRIPT" "$temp_repo/scripts/setup/70-verify-env.sh"

  args_file="$temp_repo/verify-env-args.log"
  cat >"$temp_repo/scripts/verify-env.sh" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" > "$VERIFY_ENV_ARGS_FILE"
exit 0
EOF
  chmod +x "$temp_repo/scripts/verify-env.sh"

  run env VERIFY_ENV_ARGS_FILE="$args_file" bash -lc '
    log_step() { :; }
    log_warn() { :; }
    cd "$1"
    source scripts/setup/70-verify-env.sh
  ' bash "$temp_repo"

  printf '%s\n' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 0 ]
  [ -f "$args_file" ]
  [[ "$(cat "$args_file")" == "--fix" ]]

  rm -rf "$temp_repo"
}
