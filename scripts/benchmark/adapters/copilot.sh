#!/usr/bin/env bash
# adapters/copilot.sh — GitHub Copilot CLI headless agent loop.
# Contract: adapter_run WORKDIR MODEL PROMPT_FILE OUTDIR EFFORT EFFORT_MECH
#
# EFFORT: CLEAN flag control (verified, github/copilot-cli docs + community
# discussion #184487): `--effort=LEVEL` is a shorthand alias for
# `--reasoning-effort=LEVEL` for supported reasoning models (gpt-5.x, etc.).
# Levels: low|medium|high|xhigh (minimal where the model supports it). Non-reasoning
# models ignore it. There is also a COPILOT_MODEL_EFFORT env var for BYOK setups.
# default is the model/platform default (medium for gpt-5.x).
#
# Other flags (verified, docs.github.com): -p programmatic one-shot;
# --model pins; --allow-all-tools REQUIRED headless; --output-format json (do NOT
# add --silent, it drops usage stats); --log-dir captures logs.
# Auth: COPILOT_GITHUB_TOKEN / GH_TOKEN / GITHUB_TOKEN (fine-grained PAT w/ Copilot
# Requests permission). HARNESS NOTE: this is the LOCAL CLI loop, not the cloud agent.

set -euo pipefail

adapter_run() {
  local model="$2" prompt_file="$3" outdir="$4" effort="${5:-default}"
  mkdir -p "${outdir}/logs"
  [[ -n "${COPILOT_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}" ]] \
    || { echo "copilot adapter: no token in COPILOT_GITHUB_TOKEN/GH_TOKEN/GITHUB_TOKEN" >&2; return 78; }
  local prompt; prompt="$(cat "${prompt_file}")"

  local effort_args=()
  case "${effort}" in
    minimal|low|medium|high|xhigh)
      effort_args=(--effort "${effort}")
      echo "flag:--effort=${effort}" > "${outdir}/effort-applied.txt" ;;
    default|fixed|none|"")
      echo "default(copilot=model-default)" > "${outdir}/effort-applied.txt" ;;
    *)
      effort_args=(--effort "${effort}")
      echo "flag:--effort=${effort}(nonstandard)" > "${outdir}/effort-applied.txt" ;;
  esac

  set +e
  GIT_TERMINAL_PROMPT=0 \
  copilot -p "${prompt}" --model "${model}" "${effort_args[@]}" --allow-all-tools \
    --output-format json --no-color --log-dir "${outdir}/logs" \
    > "${outdir}/agent-output.jsonl" 2> "${outdir}/logs/stderr.log"
  local rc=$?
  set -e
  return ${rc}
}
