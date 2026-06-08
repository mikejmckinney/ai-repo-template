#!/usr/bin/env bash
# adapters/codex.sh — OpenAI Codex CLI headless (exec) mode.
# Contract: adapter_run WORKDIR MODEL PROMPT_FILE OUTDIR EFFORT EFFORT_MECH
#
# EFFORT: Codex has CLEAN per-run reasoning control (verified, developers.openai.com
# + config docs): `-c model_reasoning_effort="minimal|low|medium|high|xhigh"`,
# default medium. Unsupported levels are coerced to the nearest valid one by Codex.
# This is the gold-standard case — effort is a real, settable parameter.
#
# Other flags (verified): `codex exec` non-interactive; `--model`/-m pins model;
# `--sandbox workspace-write` REQUIRED for edits (default is read-only);
# `--json` streams JSONL events incl. token counts; `-o`/`--output-last-message`
# writes final message; `-C`/`--cd` pins the working root.
# Auth: `codex login` or CODEX_API_KEY (exec-only).

set -euo pipefail

adapter_run() {
  local workdir="$1" model="$2" prompt_file="$3" outdir="$4" effort="${5:-default}"
  mkdir -p "${outdir}/logs"
  local prompt
  prompt="$(cat "${prompt_file}")"

  # Build effort override only when a concrete level is requested.
  local effort_args=()
  case "${effort}" in
    minimal | low | medium | high | xhigh)
      effort_args=(-c "model_reasoning_effort=${effort}")
      echo "flag:model_reasoning_effort=${effort}" >"${outdir}/effort-applied.txt"
      ;;
    default | "" | fixed)
      echo "default(codex=medium)" >"${outdir}/effort-applied.txt"
      ;;
    *)
      effort_args=(-c "model_reasoning_effort=${effort}")
      echo "flag:model_reasoning_effort=${effort}(nonstandard,coerced-by-codex)" >"${outdir}/effort-applied.txt"
      ;;
  esac

  local model_args=()
  if [[ "${model}" == "auto" ]]; then
    echo "$(cat "${outdir}/effort-applied.txt");model=default-omitted(auto-requested)" >"${outdir}/effort-applied.txt"
  else
    model_args=(--model "${model}")
  fi

  set +e
  (cd "${workdir}" && GIT_TERMINAL_PROMPT=0 \
    printf '%s' "${prompt}" | codex exec \
    "${model_args[@]}" \
    "${effort_args[@]}" \
    --sandbox workspace-write \
    --json \
    -C "${workdir}" \
    --output-last-message "${outdir}/final-message.txt" \
    - \
    >"${outdir}/agent-output.jsonl" 2>"${outdir}/logs/stderr.log")
  local rc=$?
  set -e
  return ${rc}
}
