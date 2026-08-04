#!/usr/bin/env bats
#
# scripts/tests/checkout-fix-branch.bats — checkout-fix-branch.sh fixture tests.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
  HELPER="$REPO_ROOT/scripts/workflows/lib/checkout-fix-branch.sh"
  export HELPER
}

setup() {
  WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/checkout-fix-branch.XXXXXX")"
  STUB_BIN="$(mktemp -d "${TMPDIR:-/tmp}/checkout-fix-branch-stub.XXXXXX")"
  export WORKDIR STUB_BIN

  git init -q -b main "$WORKDIR/repo"
  git init -q --bare "$WORKDIR/bare.git"
  git -C "$WORKDIR/repo" config user.email "test@example.com"
  git -C "$WORKDIR/repo" config user.name "Test User"
  git -C "$WORKDIR/repo" remote add origin "$WORKDIR/bare.git"
  printf 'main\n' >"$WORKDIR/repo/README.md"
  git -C "$WORKDIR/repo" add README.md
  git -C "$WORKDIR/repo" commit -qm "init main"
  git -C "$WORKDIR/repo" push -u origin main

  cat >"$STUB_BIN/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "list" ]]; then
  state="" head="" jq_filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --state) state="$2"; shift 2 ;;
      --head) head="$2"; shift 2 ;;
      --jq) jq_filter="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  number=""
  case "${state}:${head}" in
    open:retro/fix-open) number="42" ;;
    closed:retro/fix-closed) number="99" ;;
  esac
  if [[ -n "$jq_filter" ]]; then
    [[ -n "$number" ]] && echo "$number"
    exit 0
  fi
  if [[ -n "$number" ]]; then
    echo "[{\"number\":${number}}]"
  else
    echo '[]'
  fi
  exit 0
fi
exit 0
EOF
  chmod +x "$STUB_BIN/gh"
}

teardown() {
  rm -rf "$WORKDIR" "$STUB_BIN"
}

_run_checkout() {
  local branch="$1"
  (
    cd "$WORKDIR/repo"
    # shellcheck source=/dev/null
    source "$HELPER"
    checkout_fix_branch "example/test" "$branch"
  )
}

@test "checkout-fix-branch: fresh branch checks out from main" {
  _run_checkout "retro/fix-fresh"
  local main_sha branch_sha
  main_sha="$(git -C "$WORKDIR/repo" rev-parse origin/main)"
  branch_sha="$(git -C "$WORKDIR/repo" rev-parse HEAD)"
  [[ "$main_sha" == "$branch_sha" ]]
  [[ "$(git -C "$WORKDIR/repo" branch --show-current)" == "retro/fix-fresh" ]]
}

@test "checkout-fix-branch: open draft PR continues branch and merges main" {
  git -C "$WORKDIR/repo" checkout -q -b retro/fix-open
  printf 'fix\n' >"$WORKDIR/repo/fix-branch.txt"
  git -C "$WORKDIR/repo" add fix-branch.txt
  git -C "$WORKDIR/repo" commit -qam "prior fix"
  git -C "$WORKDIR/repo" push -q origin retro/fix-open
  git -C "$WORKDIR/repo" checkout -q main
  printf 'mainline\n' >"$WORKDIR/repo/main-advance.txt"
  git -C "$WORKDIR/repo" add main-advance.txt
  git -C "$WORKDIR/repo" commit -qam "advance main"
  git -C "$WORKDIR/repo" push -q origin main

  run env PATH="$STUB_BIN:$PATH" bash -c '
    cd "$0"
    source "$1"
    checkout_fix_branch "example/test" "retro/fix-open"
  ' "$WORKDIR/repo" "$HELPER"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Continuing existing draft PR #42"* ]]
  [[ -f "$WORKDIR/repo/fix-branch.txt" ]]
  [[ -f "$WORKDIR/repo/main-advance.txt" ]]
  [[ "$(git -C "$WORKDIR/repo" branch --show-current)" == "retro/fix-open" ]]
}

@test "checkout-fix-branch: closed PR with lingering branch fails clearly" {
  git -C "$WORKDIR/repo" checkout -q -b retro/fix-closed
  printf 'stale\n' >>"$WORKDIR/repo/README.md"
  git -C "$WORKDIR/repo" commit -qam "stale fix"
  git -C "$WORKDIR/repo" push -q origin retro/fix-closed
  git -C "$WORKDIR/repo" checkout -q main

  run env PATH="$STUB_BIN:$PATH" bash -c '
    cd "$0"
    source "$1"
    checkout_fix_branch "example/test" "retro/fix-closed"
  ' "$WORKDIR/repo" "$HELPER"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"draft PR #99 is closed"* ]]
}

@test "checkout-fix-branch: remote branch without open PR continues and merges main" {
  git -C "$WORKDIR/repo" checkout -q -b retro/fix-orphan
  printf 'orphan\n' >"$WORKDIR/repo/orphan-fix.txt"
  git -C "$WORKDIR/repo" add orphan-fix.txt
  git -C "$WORKDIR/repo" commit -qam "orphan fix"
  git -C "$WORKDIR/repo" push -q origin retro/fix-orphan
  git -C "$WORKDIR/repo" checkout -q main
  printf 'mainline\n' >"$WORKDIR/repo/main-advance.txt"
  git -C "$WORKDIR/repo" add main-advance.txt
  git -C "$WORKDIR/repo" commit -qam "advance main"
  git -C "$WORKDIR/repo" push -q origin main

  run env PATH="$STUB_BIN:$PATH" bash -c '
    cd "$0"
    source "$1"
    checkout_fix_branch "example/test" "retro/fix-orphan"
  ' "$WORKDIR/repo" "$HELPER"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Continuing existing fix branch retro/fix-orphan (no open draft PR yet)"* ]]
  [[ -f "$WORKDIR/repo/orphan-fix.txt" ]]
  [[ -f "$WORKDIR/repo/main-advance.txt" ]]
  [[ "$(git -C "$WORKDIR/repo" branch --show-current)" == "retro/fix-orphan" ]]
}
