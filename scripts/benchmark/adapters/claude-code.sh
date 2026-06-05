#!/usr/bin/env bash
# adapters/claude-code.sh — Claude Code CLI headless (print) mode.
# Contract: adapter_run WORKDIR MODEL PROMPT_FILE OUTDIR EFFORT EFFORT_MECH
#
# EFFORT: Current Claude Code exposes --effort (low, medium, high, xhigh, max).
# Older builds did not, so we still keep prompt-keyword phrasing as a fallback.
# Record which mechanism actually applied for benchmark cost/performance caveats.
#
# Mapping (approximate, tune to taste):
#   minimal -> no thinking keyword, budget ~0
#   low     -> "think"            ~4k
#   medium  -> "think hard"       ~10k
#   high    -> "ultrathink"       ~32k
#
# Other flags (verified): -p/--print non-interactive; prompt can be passed on
# stdin, which avoids option parsing bugs when the prompt begins with markdown
# frontmatter (`---`) or injected thinking text. --model pins; --output-format json
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

  local kw="" effort_arg="" applied=""
  case "${effort}" in
    minimal) kw="";           effort_arg="low";    applied="flag:--effort=low(minimal fallback)";;
    low)     kw="think";      effort_arg="low";    applied="flag:--effort=low";;
    medium)  kw="think hard"; effort_arg="medium"; applied="flag:--effort=medium";;
    high)    kw="ultrathink"; effort_arg="high";   applied="flag:--effort=high";;
    xhigh)   kw="ultrathink"; effort_arg="xhigh";  applied="flag:--effort=xhigh";;
    default|fixed|"") kw="";  effort_arg="";       applied="default(no-keyword)";;
    *)       kw="think hard"; effort_arg="medium"; applied="flag:--effort=medium(fallback)";;
  esac
  # Prepend the thinking directive so it governs the whole run.
  [[ -n "${kw}" ]] && prompt="(${kw} about this task before acting)

${prompt}"
  echo "${applied}" > "${outdir}/effort-applied.txt"

  local extra=()
  if [[ -n "${effort_arg}" ]] && claude --help 2>/dev/null | grep -q -- '--effort'; then
    extra=(--effort "${effort_arg}")
  elif [[ -n "${effort_arg}" ]]; then
    echo "prompt:${kw// /-}(${effort};flag-unavailable)" > "${outdir}/effort-applied.txt"
  fi

  local model_args=()
  if [[ "${model}" == "auto" ]]; then
    model_args=()
    echo "$(cat "${outdir}/effort-applied.txt");model=default-omitted(auto-requested)" > "${outdir}/effort-applied.txt"
  else
    model_args=(--model "${model}")
  fi

  set +e
  ( cd "${workdir}" && GIT_TERMINAL_PROMPT=0 \
    printf '%s\n' "${prompt}" | claude --print \
      "${model_args[@]}" \
      --output-format json \
      --dangerously-skip-permissions \
      "${extra[@]}" \
      > "${outdir}/agent-output.jsonl" 2> "${outdir}/logs/stderr.log" )
  local rc=$?
  set -e
  return ${rc}
}
