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
  ANNOUNCED="$(printf '%s\n' "$output" | sed -n 's|^\[diag-hang-snapshot\] writing to \([^ ]*\).*|\1|p' | head -1)"
  [ -n "$ANNOUNCED" ]
  case "$ANNOUNCED" in
    "$TMP_OUTDIR"/*) : ;;
    *) false ;;
  esac
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
