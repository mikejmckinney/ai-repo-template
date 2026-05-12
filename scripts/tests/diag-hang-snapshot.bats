#!/usr/bin/env bats
#
# scripts/tests/diag-hang-snapshot.bats
#
# Smoke tests for scripts/diag-hang-snapshot.sh — added to satisfy the
# diff-coupling gate for `scripts/*.sh` files that introduce or modify
# `pipefail` logic (issue #229 Phase 1.5).
#
# The script is a long-running diagnostic sampler that writes a rolling
# snapshot of system + Copilot Chat session state into $OUTDIR every
# $INTERVAL seconds, up to $MAX_SAMPLES samples. We exercise it with
# MAX_SAMPLES=1 INTERVAL=0 and a temp $OUTDIR so the test completes in
# under a second and leaves no residue under /tmp/hang-diag/.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-60}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
  SCRIPT="$REPO_ROOT/scripts/diag-hang-snapshot.sh"
  export SCRIPT
}

setup() {
  TMP_OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/diag-hang-test-XXXXXX")"
  export TMP_OUTDIR
}

teardown() {
  rm -rf "$TMP_OUTDIR"
}

@test "diag-hang-snapshot: script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "diag-hang-snapshot: passes shellcheck (no warnings or errors)" {
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi
  # --severity=warning ignores informational findings (e.g. SC2009 — the
  # script intentionally greps `ps` output because it needs the full cmd
  # column for diagnostic context, which `pgrep` does not provide).
  run shellcheck --severity=warning "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "diag-hang-snapshot: sets pipefail (diff-coupling gate witness)" {
  # The diff-coupling gate exists because pipefail changes failure semantics;
  # this test asserts the script still declares it, so a future edit that
  # removes pipefail without updating this test will fail review.
  run grep -E '^set -[a-z]*o[[:space:]]+pipefail|^set [^#]*pipefail' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "diag-hang-snapshot: MAX_SAMPLES=1 run exits 0 and writes one sample" {
  # Smoke run: one sample, zero interval, isolated outdir. The script's
  # while-loop should run exactly once and exit cleanly.
  run env OUTDIR="$TMP_OUTDIR" INTERVAL=0 MAX_SAMPLES=1 \
    bash "$SCRIPT"
  [ "$status" -eq 0 ]
  # The script creates a per-run subdirectory under $OUTDIR.
  run find "$TMP_OUTDIR" -mindepth 1 -maxdepth 1 -type d -name 'run-*'
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  # And at least one sample file inside it.
  RUN_DIR="$output"
  run find "$RUN_DIR" -mindepth 1 -type f
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "diag-hang-snapshot: respects custom OUTDIR (does not write to /tmp/hang-diag)" {
  # Regression guard: a previous draft hard-coded /tmp/hang-diag. The OUTDIR
  # env var must be honored. We assert this *deterministically and immune to
  # parallel writers* by parsing the script's announced RUN_DIR from its own
  # stdout (the script logs `[diag-hang-snapshot] writing to <RUN_DIR>`) and
  # checking that path lives under our isolated $TMP_OUTDIR. A regression
  # where the script ignored OUTDIR would announce a path under /tmp/hang-diag
  # and fail this assertion. (Earlier rounds tried mtime-based polling of
  # /tmp/hang-diag, but that approach is inherently racy in shared CI/dev
  # environments where unrelated diag-hang processes may also be running —
  # see R11 ISS-64 / R15 ISS-78.)
  run env OUTDIR="$TMP_OUTDIR" INTERVAL=0 MAX_SAMPLES=1 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  ANNOUNCED="$(printf '%s\n' "$output" | sed -n 's|^\[diag-hang-snapshot\] writing to \([^ ]*\).*|\1|p' | head -1)"
  [ -n "$ANNOUNCED" ]
  case "$ANNOUNCED" in
    "$TMP_OUTDIR"/*) : ;;  # ok — inside our isolated outdir
    *)
      echo "diag-hang-snapshot announced RUN_DIR=$ANNOUNCED outside TMP_OUTDIR=$TMP_OUTDIR" >&2
      false
      ;;
  esac
  # And confirm something was actually written there.
  [ -n "$(find "$ANNOUNCED" -mindepth 1 -type f -print -quit)" ]
}
