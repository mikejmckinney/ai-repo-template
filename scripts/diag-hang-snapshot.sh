#!/usr/bin/env bash
# diag-hang-snapshot.sh — capture a rolling snapshot of system + Copilot
# Chat session state into /tmp/hang-diag/ so the next session hang can be
# diagnosed after-the-fact instead of guessed at.
#
# Target environment: dev-container Linux (GitHub Codespaces / VS Code
# Remote Containers). The hangs this script diagnoses occur in the
# Copilot Chat extension running inside the container; the diagnostic
# tools below (free, top -w, ps --sort, ss) are Linux-specific by
# design. macOS portability is not in scope for v1 — diagnosing macOS
# hangs would use vm_stat / Activity Monitor / equivalent and is a
# separate workflow. (PR #297 Round 9 ISS-55, declined out-of-scope.)
#
# Usage:
#   scripts/diag-hang-snapshot.sh &           # run in background
#   echo "started, pid=$!"
#   # ... trigger the workload that hangs ...
#   # when it hangs (or after), inspect /tmp/hang-diag/
#
# Stop with: kill <pid>  (or it self-terminates after MAX_SAMPLES).
#
# What it captures every INTERVAL seconds:
#   - top -b -n1 (CPU/RSS per process)
#   - ss -tnp ESTABLISHED (open TCP, esp. *.githubcopilot.com)
#   - ps -eo pid,ppid,pcpu,pmem,rss,etime,cmd (focused on node/code/gh)
#   - free -h
#   - tail of $VSCODE_TARGET_SESSION_LOG if present
#
# Failure mode: `set -uo pipefail` deliberately omits `-e`. A diagnostic
# sampler should keep capturing what it can even when one command fails
# (e.g. `ss` blocked by permissions, or `top` formatting flag absent on a
# stripped image). With `-e`, a single transient failure inside the per-
# sample block would abort the whole sampling loop and lose the rest of
# the snapshot — defeating the script's purpose. (PR #297 Round 9
# ISS-53, declined-with-rationale.)
set -uo pipefail

# Diagnostic samples may include command-line args and session-log tails.
# Restrict /tmp/hang-diag artifacts to the current user (R14 ISS-72).
umask 077

OUTDIR="${OUTDIR:-/tmp/hang-diag-${USER:-$(id -un)}}"
INTERVAL="${INTERVAL:-3}"
MAX_SAMPLES="${MAX_SAMPLES:-200}" # ~10 minutes at INTERVAL=3
# How many process / socket rows to keep per sample. The +1 in the head
# count below preserves the column-header row added by `awk 'NR==1 || ...'`.
PS_ROWS="${PS_ROWS:-30}"
SS_ROWS="${SS_ROWS:-20}"
SESSION_LOG="${VSCODE_TARGET_SESSION_LOG:-}"

# Setup steps fail-fast: a mkdir failure for OUTDIR/RUN_DIR means we have
# nowhere to write samples, so there's nothing useful to do. The per-sample
# loop below intentionally tolerates per-command failure (see header), but
# *setup* failure must abort. (R16 ISS-82.)
mkdir -p "$OUTDIR" || {
  echo "[diag-hang-snapshot] FATAL: cannot create OUTDIR=$OUTDIR" >&2
  exit 1
}
START_TS="$(date -u +%Y%m%dT%H%M%SZ)"
# Include $$ so two concurrent invocations starting in the same second don't
# write into the same run-* directory and interleave samples.log/session-log
# (PR #297 R11 ISS-63).
RUN_DIR="$OUTDIR/run-$START_TS-$$"
mkdir -p "$RUN_DIR" || {
  echo "[diag-hang-snapshot] FATAL: cannot create RUN_DIR=$RUN_DIR" >&2
  exit 1
}

echo "[diag-hang-snapshot] writing to $RUN_DIR (interval=${INTERVAL}s, max=${MAX_SAMPLES})"
echo "[diag-hang-snapshot] session log: ${SESSION_LOG:-<unset>}"

trap 'echo "[diag-hang-snapshot] stopping"; exit 0' INT TERM

i=0
while ((i < MAX_SAMPLES)); do
  TS="$(date -u +%Y%m%dT%H%M%SZ)"
  {
    echo "===== $TS ====="
    echo "--- free -h ---"
    free -h
    echo "--- top (top 20 by CPU) ---"
    top -b -n1 | head -27
    echo "--- ps node/code/gh/copilot ---"
    # shell-conventions:disable=RULE-02 reason: substring match on ps/ss output is intentional — diagnostic filter wants any line containing 'node', 'copilot', etc., not whole-line matches
    # `extension` deliberately stays unanchored so it matches `extensionHost`
    # (the actual VS Code extension-host process name) — anchored-only would
    # miss the primary diagnostic target. (PR #297 R12 ISS-66.)
    # Preserve the column header line via `awk 'NR==1 || /pattern/'` so
    # post-mortem readers see PID/PPID/%CPU/... labels next to the rows.
    # (R14 ISS-73.)
    ps -eo pid,ppid,pcpu,pmem,rss,etime,cmd --sort=-pcpu \
      | awk 'NR==1 || tolower($0) ~ /(^|[^a-z])(node|code-server|gh|copilot)([^a-z]|$)|extension/' | head -n "$((PS_ROWS + 1))"
    echo "--- ss ESTABLISHED to copilot/github ---"
    # shell-conventions:disable=RULE-02 reason: substring match on ss output is intentional — hostnames like *.githubcopilot.com:443 carry dots so word-boundary anchors would miss them
    # (Note on `-p`: showing process info typically requires root. In an
    # unprivileged container `ss` will still print the socket rows but may
    # omit the process column or emit a permission warning — both flow
    # into the per-sample log via the surrounding 2>&1 wrapper. R11 ISS-62.)
    # Preserve the column header line so post-mortem readers see
    # Netid/State/Recv-Q/... labels next to the rows. (R14 ISS-74.)
    ss -tnp \
      | awk 'NR==1 || ($0 ~ /ESTAB/ && tolower($0) ~ /copilot|github|node|extension/)' | head -n "$((SS_ROWS + 1))"
  } >>"$RUN_DIR/samples.log" 2>&1

  if [[ -n "$SESSION_LOG" && -f "$SESSION_LOG" ]]; then
    {
      echo "===== $TS session-log tail ====="
      tail -n 40 "$SESSION_LOG"
    } >>"$RUN_DIR/session-log-tail.log" 2>&1
  fi

  sleep "$INTERVAL"
  i=$((i + 1))
done

echo "[diag-hang-snapshot] reached MAX_SAMPLES=$MAX_SAMPLES, exiting"
