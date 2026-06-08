#!/usr/bin/env bash
# adapters/gemini-cli.sh — Gemini CLI headless mode (Antigravity model substitute).
# Contract: adapter_run WORKDIR MODEL PROMPT_FILE OUTDIR EFFORT EFFORT_MECH
#
# WHY: Antigravity is an IDE extension/agent harness with NO headless CLI of its
# own. The `gemini` command runs the SAME underlying Gemini models and tools
# headlessly, so it stands in. This measures the Gemini CLI harness, NOT
# Antigravity — record agent=gemini-cli.
#
# EFFORT: Gemini 3 series uses `thinkingLevel` with EXACTLY three valid values:
#   "minimal" | "medium" | "high"   (NOTE: there is NO "low"; default is "high")
# Set via project config at <workdir>/.gemini/settings.json (no CLI flag exists;
# gemini-cli#21974/#25122 are open feature requests). This adapter writes that
# config per run. "minimal" is only valid on Flash-class models; on Pro it may
# error or clamp — recorded honestly.
#
# Mapping for the benchmark's low/medium/high effort column:
#   minimal -> thinkingLevel=minimal   (Flash only)
#   low     -> NOT A VALID GEMINI LEVEL -> mapped to "minimal", flagged as remap
#   medium  -> thinkingLevel=medium
#   high    -> thinkingLevel=high
# Because Gemini lacks a true "low", a Stage-2 sweep on Gemini cells uses
# {minimal, medium, high}, not {low, medium, high} — note this in the analysis.
#
# Other flags (verified): --prompt non-interactive; --model pins/aliases;
# --yolo auto-approves tools (safe in isolated worktree); --output-format json
# yields .stats token usage; --session-summary writes metrics JSON.
# Auth: GEMINI_API_KEY / GOOGLE_API_KEY / Vertex env.

set -euo pipefail

_gemini_supports_flag() {
  gemini --help 2>&1 | grep -F -q -- "$1"
}

_gemini_write_alias() { # workdir model LEVEL alias_name
  local workdir="$1" model="$2" lvl="$3" name="$4"
  mkdir -p "${workdir}/.gemini"
  cat >"${workdir}/.gemini/settings.json" <<JSON
{
  "modelConfigs": {
    "customAliases": {
      "${name}": {
        "modelConfig": {
          "model": "${model}",
          "generateContentConfig": { "thinkingConfig": { "thinkingLevel": "${lvl}" } }
        }
      }
    }
  }
}
JSON
}

_gemini_cleanup_runner_state() {
  local workdir="$1"
  rm -f "${workdir}/.gemini/settings.json"
  rmdir "${workdir}/.gemini" 2>/dev/null || true
}

adapter_run() {
  local workdir="$1" model="$2" prompt_file="$3" outdir="$4" effort="${5:-default}"
  mkdir -p "${outdir}/logs"
  local prompt
  prompt="$(cat "${prompt_file}")"

  if ! _gemini_supports_flag --prompt || ! _gemini_supports_flag --model || ! _gemini_supports_flag --yolo; then
    echo "NOT-APPLIED(required gemini headless flag missing)" >"${outdir}/effort-applied.txt"
    echo "gemini adapter: required flag missing (--prompt, --model, or --yolo)" >&2
    return 64
  fi

  local backend_model="${model}"
  if [[ "${model}" == "gemini-3.5-flash" ]]; then
    backend_model="gemini-3-flash-preview"
  fi

  local use_model="${backend_model}" applied="" auto_model="0"
  [[ "${model}" == "auto" ]] && auto_model="1"
  if [[ "${auto_model}" == "1" ]]; then
    use_model=""
    applied="model=default-omitted(auto-requested);runner=gemini-json-primary;effort=fixed(no-cli-control)"
  else
    if [[ "${backend_model}" != "${model}" ]]; then
      applied="model_alias=${model}->${backend_model};"
    fi
    case "${effort}" in
      minimal)
        _gemini_write_alias "${workdir}" "${backend_model}" "minimal" "bench-minimal"
        use_model="bench-minimal"
        applied="${applied}config:thinkingLevel=minimal(flash-only;may-clamp-on-pro)"
        ;;
      medium)
        _gemini_write_alias "${workdir}" "${backend_model}" "medium" "bench-medium"
        use_model="bench-medium"
        applied="${applied}config:thinkingLevel=medium"
        ;;
      high)
        _gemini_write_alias "${workdir}" "${backend_model}" "high" "bench-high"
        use_model="bench-high"
        applied="${applied}config:thinkingLevel=high"
        ;;
      low)
        # Gemini 3 has no "low". Remap to the nearest valid lower level (minimal),
        # and flag it so the analysis doesn't treat it as a true "low".
        _gemini_write_alias "${workdir}" "${backend_model}" "minimal" "bench-lowremap"
        use_model="bench-lowremap"
        applied="${applied}config:thinkingLevel=minimal(REMAPPED-from-low;gemini-has-no-low)"
        ;;
      default | fixed | "") applied="${applied}default(gemini3=high)" ;;
      *) applied="${applied}default(unrecognized:${effort})" ;;
    esac
  fi
  echo "${applied}" >"${outdir}/effort-applied.txt"

  local extra_args=(--yolo)
  if _gemini_supports_flag --skip-trust; then
    extra_args+=(--skip-trust)
  fi
  if ! _gemini_supports_flag --output-format; then
    echo "NOT-APPLIED(required gemini telemetry flag missing: --output-format)" >"${outdir}/effort-applied.txt"
    echo "gemini adapter: required telemetry flag missing (--output-format)" >&2
    return 64
  fi
  extra_args+=(--output-format json)
  if _gemini_supports_flag --session-summary; then
    extra_args+=(--session-summary "${outdir}/session-summary.json")
  fi

  set +e
  local model_args=()
  [[ -n "${use_model}" ]] && model_args=(--model "${use_model}")
  (cd "${workdir}" && GIT_TERMINAL_PROMPT=0 \
    gemini --prompt="${prompt}" \
    "${model_args[@]}" \
    "${extra_args[@]}" \
    >"${outdir}/agent-output.jsonl" 2>"${outdir}/logs/stderr.log")
  local rc=$?
  set -e
  _gemini_cleanup_runner_state "${workdir}"

  if [[ ${rc} -ne 0 && "${auto_model}" == "1" ]] && command -v agy >/dev/null 2>&1; then
    mv "${outdir}/agent-output.jsonl" "${outdir}/agent-output.gemini-failed.jsonl" 2>/dev/null || true
    echo "gemini auto JSON run failed rc=${rc}; falling back to agy without JSON stats" >>"${outdir}/logs/stderr.log"
    echo "${applied};fallback=agy(no-json-stats)" >"${outdir}/effort-applied.txt"
    set +e
    (cd "${workdir}" && GIT_TERMINAL_PROMPT=0 \
      agy -p "${prompt}" --dangerously-skip-permissions --print-timeout 30m \
      >"${outdir}/agent-output.jsonl" 2>>"${outdir}/logs/stderr.log")
    rc=$?
    set -e
    _gemini_cleanup_runner_state "${workdir}"
  fi

  return ${rc}
}
