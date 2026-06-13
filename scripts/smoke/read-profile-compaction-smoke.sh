#!/usr/bin/env bash
# Read-profile compaction smoke — AGENTS.md v25 (Phases A–C via cursor-agent headless).
#
# Usage:
#   ./scripts/smoke/read-profile-compaction-smoke.sh [--phase A|B|C|all] [--model MODEL] [--outdir DIR]
#
# Requires: cursor-agent on PATH; CURSOR_API_KEY or cursor-agent login.
# Prompt spec: .github/prompts/read-profile-compaction-smoke.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT_SPEC="$REPO_ROOT/.github/prompts/read-profile-compaction-smoke.md"

PHASE="all"
MODEL="${READ_PROFILE_SMOKE_MODEL:-composer-2.5}"
OUTDIR=""
TIMEOUT_SEC="${READ_PROFILE_SMOKE_TIMEOUT:-600}"
RUNNER_LABEL="${READ_PROFILE_SMOKE_RUNNER:-local}"

usage() {
  echo "Usage: read-profile-compaction-smoke.sh [--phase A|B|C|all] [--model MODEL] [--outdir DIR] [--runner LABEL]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase) PHASE="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --outdir) OUTDIR="$2"; shift 2 ;;
    --runner) RUNNER_LABEL="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

if [[ -z "$OUTDIR" ]]; then
  OUTDIR="$(mktemp -d)/read-profile-smoke-${RUNNER_LABEL}-$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$OUTDIR"

if ! command -v cursor-agent >/dev/null 2>&1 && ! command -v agent >/dev/null 2>&1; then
  echo "::error::cursor-agent/agent not found on PATH" >&2
  exit 127
fi
if [[ -z "${CURSOR_API_KEY:-}" ]] && ! cursor-agent status >/dev/null 2>&1 && ! agent status >/dev/null 2>&1; then
  echo "::error::Not authenticated — set CURSOR_API_KEY or run cursor-agent login" >&2
  exit 78
fi

cursor_agent_cmd() {
  if command -v cursor-agent >/dev/null 2>&1; then
    cursor-agent "$@"
  else
    agent "$@"
  fi
}

agents_md_version="$(grep -oE 'AGENTS_MD_VERSION: [0-9]+' "$REPO_ROOT/AGENTS.md" | head -1 | grep -oE '[0-9]+' || echo 25)"

build_prompt() {
  local phase="$1"
  local strict="${2:-}"
  local fmt=""
  if [[ -n "$strict" ]]; then
    fmt="CRITICAL: Line 1 MUST be exactly \"Session handshake v${agents_md_version}\" with NO characters before it. Violations fail the smoke test."
  else
    fmt="OUTPUT RULE: Line 1 MUST be \"Session handshake v${agents_md_version}\" with NO preamble."
  fi
  case "$phase" in
    A)
      cat <<EOF
${fmt}

Read-profile compaction smoke — Phase A only. DO NOT edit any files.

Follow AGENTS.md startup (read process_session_start.md and .context/rules/README.md from disk).

Answer: What named read profile should an agent use for a non-editing repo architecture question?

Requirements:
- NO text before Session handshake — Session handshake v${agents_md_version} must be the LITERAL FIRST LINE of your response
- Handshake table with Read profile = startup-min
- ## Session context receipt listing files Read from disk for this boundary
EOF
      ;;
    B)
      cat <<EOF
${fmt}

Read-profile compaction smoke — Phase B. DO NOT edit any files.

[Conversation summary — prior session compacted]
- Phase A answered a read-only repo question using read profile startup-min.
- Prior handshake: Session handshake v${agents_md_version}, Read profile startup-min.
- Prior rule file contents may no longer be in context.

Treat the summary above as context compaction per AGENTS.md § "After context compaction".
Re-run startup before answering.

Task (implementation-class, planning only): Describe the exact one-line comment you would add to scripts/checks/052-postmerge-retro-invariants.sh documenting read-profile compaction smoke. Do not modify files.

Requirements:
- NO text before Session handshake — Session handshake v${agents_md_version} must be the LITERAL FIRST LINE
- New Session handshake + Read profile = implementation
- ## Session context receipt with implementation-profile files Read from disk (e.g. process_gates.md)
EOF
      ;;
    C)
      cat <<EOF
${fmt}

Read-profile compaction smoke — Phase C. DO NOT edit any files.

[Conversation summary — prior session compacted]
You previously learned that process_gates.md says:
"The Analyst pre-flight gate fires only when issues carry the bug label."

Treat this as compaction. Re-run AGENTS.md startup. Read profile: implementation or policy-adr.

Task:
1. Read .context/rules/process_gates.md from disk.
2. Quote trigger 1 under "## Analyst pre-flight gate" verbatim or near-verbatim.
3. State whether the summary claim was wrong.
4. Emit Session handshake (FIRST LINE, no preamble) + ## Session context receipt.
EOF
      ;;
    *) echo "Unknown phase $phase" >&2; return 1 ;;
  esac
}

run_phase() {
  local phase="$1"
  local attempt strict=""
  for attempt in 1 2; do
    if [[ "$attempt" -eq 2 ]]; then
      strict=1
      echo "== Phase ${phase} retry (${RUNNER_LABEL}) with strict first-line rule"
    fi
    local prompt_file="$OUTDIR/phase-${phase}-prompt.txt"
    local json_file="$OUTDIR/phase-${phase}-agent.json"
    local text_file="$OUTDIR/phase-${phase}-output.txt"
    local log_file="$OUTDIR/phase-${phase}-stderr.log"
    [[ "$attempt" -eq 2 ]] && text_file="$OUTDIR/phase-${phase}-output-retry.txt"

    build_prompt "$phase" "$strict" >"$prompt_file"
    echo "== Phase ${phase} (${RUNNER_LABEL}) attempt ${attempt} → $text_file"

    set +e
    timeout "$TIMEOUT_SEC" cursor_agent_cmd -p \
      --model "$MODEL" \
      --force \
      --trust \
      --output-format json \
      "$(cat "$prompt_file")" \
      >"$json_file" 2>"$log_file"
    local rc=$?
    set -e

    if [[ "$rc" -eq 124 ]]; then
      echo "::error::Phase ${phase} timed out after ${TIMEOUT_SEC}s" >&2
      return 124
    fi
    if [[ "$rc" -ne 0 ]]; then
      echo "::error::Phase ${phase} cursor-agent exit ${rc}" >&2
      tail -20 "$log_file" >&2 || true
      return "$rc"
    fi

    python3 "$SCRIPT_DIR/extract-cursor-agent-text.py" "$json_file" >"$text_file"
    if bash "$SCRIPT_DIR/validate-read-profile-compaction-smoke.sh" "$phase" "$text_file" | tee "$OUTDIR/phase-${phase}-validation-attempt${attempt}.log"; then
      return 0
    fi
    if [[ "$attempt" -eq 2 ]]; then
      return 1
    fi
  done
}

cp "$PROMPT_SPEC" "$OUTDIR/prompt-spec.md"
echo "runner=${RUNNER_LABEL}" >"$OUTDIR/meta.txt"
echo "model=${MODEL}" >>"$OUTDIR/meta.txt"
echo "repo=${REPO_ROOT}" >>"$OUTDIR/meta.txt"
date -u +%Y-%m-%dT%H:%M:%SZ >>"$OUTDIR/meta.txt"

run_all() {
  local phases=(A B C)
  if [[ "$PHASE" != "all" ]]; then
    phases=("$PHASE")
  fi
  for p in "${phases[@]}"; do
    run_phase "$p"
  done
  echo "All requested phases passed. Artifacts: $OUTDIR"
}

run_all
