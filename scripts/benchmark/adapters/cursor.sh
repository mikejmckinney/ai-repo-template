#!/usr/bin/env bash
# adapters/cursor.sh — Cursor CLI agent headless (print) mode.
# Contract: adapter_run WORKDIR MODEL PROMPT_FILE OUTDIR EFFORT EFFORT_MECH
#
# EFFORT: Cursor has NO reasoning-effort flag, and the model-name-suffix approach
# (e.g. "sonnet-4-thinking") is unreliable — a reported CLI bug drops the suffix
# (forum.cursor.com/.../159748). WORKAROUND (per user): inject the effort as an
# inline natural-language directive at the top of the prompt, e.g.
#   "Using claude-opus-4-8 with medium thinking effort: <task>"
# This is a REQUEST the model may or may not honor, and there is NO telemetry
# confirming it took effect. So effort_status for Cursor is recorded as
# "requested-in-prompt" (a weaker tier than a real flag), NOT "applied".
#
# Other flags (verified): cursor-agent -p non-interactive; --model pins model;
# --force REQUIRED in print mode or edits are only proposed (no diff);
# --output-format json = single result object. KNOWN: -p can hang on some
# 2026.01.x builds — wrap in `timeout` if needed. Auth: CURSOR_API_KEY or
# stored `cursor-agent login`.
#
# Composer 2.5 billing (headless): --model composer-2.5 may still bill as
# composer-2.5-fast in the dashboard; bracket syntax is unconfirmed. GHA
# pipelines use @cursor/sdk via run-advisory-cursor.mjs instead. See
# docs/guides/agent-pipeline.md § "Composer 2.5 standard vs fast".

set -euo pipefail

adapter_run() {
  local workdir="$1" model="$2" prompt_file="$3" outdir="$4" effort="${5:-default}"
  mkdir -p "${outdir}/logs"
  if [[ -z "${CURSOR_API_KEY:-}" ]] && ! cursor-agent status >/dev/null 2>&1; then
    echo "cursor adapter: not authenticated (set CURSOR_API_KEY or run cursor-agent login)" >&2
    return 78
  fi
  local prompt
  prompt="$(cat "${prompt_file}")"

  local model_args=()
  if [[ "${model}" == "auto" ]]; then
    prompt="Use Cursor Auto model routing for this task. Do not pin a specific model unless the CLI/runtime requires it.

${prompt}"
    model_args=(--model auto)
  else
    model_args=(--model "${model}")
  fi

  # Inline-directive workaround: prepend a thinking-effort instruction naming the
  # model + level. Honored at the model's discretion; unverifiable.
  case "${effort}" in
    minimal | low | medium | high | xhigh)
      if [[ "${model}" == "auto" ]]; then
        prompt="Using Cursor Auto routing with ${effort} thinking effort requested for this task:

${prompt}"
        echo "model:auto(applied);effort=prompt:inline-directive(${effort}-thinking;unverified)" >"${outdir}/effort-applied.txt"
      else
        prompt="Using ${model} with ${effort} thinking effort for this task:

${prompt}"
        echo "prompt:inline-directive(${model}+${effort}-thinking;unverified)" >"${outdir}/effort-applied.txt"
      fi
      ;;
    fixed | default | none | "")
      if [[ "${model}" == "auto" ]]; then
        echo "model:auto(applied);effort=default(no inline directive)" >"${outdir}/effort-applied.txt"
      else
        echo "default(no inline directive; model default)" >"${outdir}/effort-applied.txt"
      fi
      ;;
    *)
      prompt="Using ${model} with ${effort} thinking effort for this task:

${prompt}"
      echo "prompt:inline-directive(${model}+${effort};nonstandard;unverified)" >"${outdir}/effort-applied.txt"
      ;;
  esac

  set +e
  (cd "${workdir}" && GIT_TERMINAL_PROMPT=0 \
    cursor-agent -p "${model_args[@]}" --force --output-format json "${prompt}" \
    >"${outdir}/agent-output.jsonl" 2>"${outdir}/logs/stderr.log")
  local rc=$?
  set -e
  return ${rc}
}
