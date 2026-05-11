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
# (e.g. `top -w` not supported on a stripped image, or `ss` blocked by
# permissions). With `-e`, a single transient failure inside the per-
# sample block would abort the whole sampling loop and lose the rest of
# the snapshot — defeating the script's purpose. (PR #297 Round 9
# ISS-53, declined-with-rationale.)
set -uo pipefail

OUTDIR="${OUTDIR:-/tmp/hang-diag}"
INTERVAL="${INTERVAL:-3}"
MAX_SAMPLES="${MAX_SAMPLES:-200}" # ~10 minutes at INTERVAL=3
SESSION_LOG="${VSCODE_TARGET_SESSION_LOG:-}"

mkdir -p "$OUTDIR"
START_TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUTDIR/run-$START_TS"
mkdir -p "$RUN_DIR"

echo "[diag-hang-snapshot] writing to $RUN_DIR (interval=${INTERVAL}s, max=${MAX_SAMPLES})"
echo "[diag-hang-snapshot] session log: ${SESSION_LOG:-<unset>}"

trap 'echo "[diag-hang-snapshot] stopping"; exit 0' INT TERM

i=0
while ((i < MAX_SAMPLES)); do
  TS="$(date -u +%Y%m%dT%H%M%SZ)"
  {
    echo "===== $TS ====="
    echo "--- free -h ---"
    free -h 2>&1
    echo "--- top (top 20 by CPU) ---"
    top -b -n1 -w200 2>&1 | head -27
    echo "--- ps node/code/gh/copilot ---"
    # shell-conventions:disable=RULE-02 reason: substring match on ps/ss output is intentional — diagnostic filter wants any line containing 'node', 'copilot', etc., not whole-line matches
    ps -eo pid,ppid,pcpu,pmem,rss,etime,cmd --sort=-pcpu 2>&1 \
      | grep -Ei 'node|code-server|gh |copilot|extension' | head -30
    echo "--- ss ESTABLISHED to copilot/github ---"
    ss -tnp \
      | grep -E 'ESTAB' \
      | grep -Ei 'copilot|github|node' | head -20
  } >>"$RUN_DIR/samples.log" 2>&1

  if [[ -n "$SESSION_LOG" && -f "$SESSION_LOG" ]]; then
    {
      echo "===== $TS session-log tail ====="
      tail -n 40 "$SESSION_LOG" 2>&1
    } >>"$RUN_DIR/session-log-tail.log" 2>&1
  fi

  sleep "$INTERVAL"
  i=$((i + 1))
done

echo "[diag-hang-snapshot] reached MAX_SAMPLES=$MAX_SAMPLES, exiting"
