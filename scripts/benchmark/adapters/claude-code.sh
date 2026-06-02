#!/usr/bin/env bash
# adapters/claude-code.sh — Claude Code CLI headless (print) mode.
# Contract: adapter_run WORKDIR MODEL PROMPT_FILE OUTDIR EFFORT EFFORT_MECH
#
# EFFORT: Claude has NO named low/med/high enum. Reasoning is an extended-thinking
# TOKEN BUDGET. The documented lever in the CLI is thinking-keyword phrasing in the
# prompt ("think" < "think hard" < "think harder" < "ultrathink", increasing budget),
# optionally `--max-thinking-tokens N` on versions that expose it. So we map levels
# to keywords AND pass a max-thinking-tokens hint. This is an APPROXIMATION, not a
# clean enum — record it honestly. VERIFY `claude --help` for --max-thinking-tokens
# on your version; if absent, the keyword still applies and the flag is ignored.
#
# Mapping (approximate, tune to taste):
#   minimal -> no thinking keyword, budget ~0
#   low     -> "think"            ~4k
#   medium  -> "think hard"       ~10k
#   high    -> "ultrathink"       ~32k
#
# Other flags (verified): -p non-interactive; --model pins; --output-format json
# gives token counts + cost; --dangerously-skip-permissions REQUIRED headless
# (safe in the isolated worktree). KNOWN BUG: writes under .claude/skills|agents|
# commands may be silently denied (anthropics/claude-code#54850) — a stall there
# is a tooling bug, not a model quality miss.
# Auth: subscription, or ANTHROPIC_API_KEY for sustained parallel runs.

set -euo pipefail

adapter_run() {
  local workdir="$1" model="$2" prompt_file="$3" outdir="$4" effort="${5:-default}"
  mkdir -p "${outdir}/logs"
  local prompt; prompt="$(cat "${prompt_file}")"

  local kw="" budget="" applied=""
  case "${effort}" in
    minimal) kw="";              budget="";      applied="prompt:none(minimal)";;
    low)     kw="think";         budget="4096";  applied="prompt:think(low)";;
    medium)  kw="think hard";    budget="10000"; applied="prompt:think-hard(medium)";;
    high)    kw="ultrathink";    budget="32000"; applied="prompt:ultrathink(high)";;
    xhigh)   kw="ultrathink";    budget="48000"; applied="prompt:ultrathink(xhigh~capped)";;
    default|fixed|"") kw="";     budget="";      applied="default(no-keyword)";;
    *)       kw="think hard";    budget="10000"; applied="prompt:think-hard(fallback)";;
  esac
  # Prepend the thinking directive so it governs the whole run.
  [[ -n "${kw}" ]] && prompt="(${kw} about this task before acting)

${prompt}"
  echo "${applied}" > "${outdir}/effort-applied.txt"

  local extra=()
  if [[ -n "${budget}" ]] && claude --help 2>/dev/null | grep -q -- '--max-thinking-tokens'; then
    extra=(--max-thinking-tokens "${budget}")
    echo "${applied}+max-thinking-tokens=${budget}" > "${outdir}/effort-applied.txt"
  fi

  set +e
  ( cd "${workdir}" && GIT_TERMINAL_PROMPT=0 \
    claude -p "${prompt}" \
      --model "${model}" \
      --output-format json \
      --dangerously-skip-permissions \
      "${extra[@]}" \
      > "${outdir}/agent-output.jsonl" 2> "${outdir}/logs/stderr.log" )
  local rc=$?
  set -e
  return ${rc}
}
