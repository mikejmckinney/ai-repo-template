#!/usr/bin/env bash
# doctor.sh — pre-spend readiness gate for the model-ROI benchmark runner.
#
# Usage:
#   ./doctor.sh --stage 1 [--base <BASE_SHA>]
#   ./doctor.sh --alias cand-01 [--base <BASE_SHA>]
#
# The goal is to fail cheaply before any metered run starts. Checks are mostly
# heuristics, not live auth probes: binary presence, likely auth readiness,
# writable run/config paths, prompt/manifest presence, and local base/remote
# prerequisites for the frozen-branch workflow.

set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

STAGE="" ALIAS="" BASE_SHA=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage) STAGE="$2"; shift 2;;
    --alias) ALIAS="$2"; shift 2;;
    --base)  BASE_SHA="$2"; shift 2;;
    *) die "unknown arg: $1";;
  esac
done

[[ -n "${ALIAS}" || -n "${STAGE}" ]] \
  || die "usage: --stage <N> [--base <sha>] | --alias <cand-NN> [--base <sha>]"

pass_count=0
warn_count=0
fail_count=0

pass_note() { log "PASS: $*"; pass_count=$((pass_count + 1)); }
warn_note() { log "WARN: $*"; warn_count=$((warn_count + 1)); }
fail_note() { log "FAIL: $*"; fail_count=$((fail_count + 1)); }

have_flag() {
  local bin="$1" flag="$2"
  "${bin}" --help 2>&1 | grep -F -q -- "${flag}"
}

write_probe() {
  local target="$1"
  mkdir -p "$(dirname "${target}")"
  : > "${target}"
  rm -f "${target}"
}

check_remote_readiness() {
  local origin_url=""
  origin_url="$(git -C "${REPO_DIR}" remote get-url origin 2>/dev/null || true)"
  if [[ -n "${origin_url}" ]]; then
    pass_note "origin remote configured"
  else
    fail_note "origin remote not configured"
  fi

  if git -C "${REPO_DIR}" rev-parse --verify main >/dev/null 2>&1; then
    pass_note "local main branch exists"
  elif git -C "${REPO_DIR}" rev-parse --verify refs/remotes/origin/main >/dev/null 2>&1; then
    pass_note "origin/main is available locally"
  else
    fail_note "neither local main nor origin/main is available to freeze a base"
  fi

  if [[ -n "${BASE_SHA}" ]]; then
    require_base "${BASE_SHA}"
    pass_note "base SHA is present locally"
  else
    warn_note "BASE not supplied; exact base SHA validation skipped"
  fi
}

check_auth_hint() {
  local label="$1"
  shift
  local var
  for var in "$@"; do
    if [[ -n "${!var:-}" ]]; then
      pass_note "${label} auth heuristic satisfied by ${var}"
      return 0
    fi
  done
  return 1
}

check_alias() {
  local alias="$1"
  local row platform stage
  row="$(manifest_lookup "${alias}")" || {
    fail_note "manifest entry missing for ${alias}"
    return
  }
  IFS=$'\t' read -r -a fields <<<"${row}"
  platform="${fields[0]}"
  stage="${fields[3]}"

  if [[ -n "${STAGE}" && "${stage}" != "${STAGE}" ]]; then
    fail_note "${alias} is stage ${stage}, not requested stage ${STAGE}"
    return
  fi

  case "${platform}" in
    codex)
      if command -v codex >/dev/null 2>&1; then
        pass_note "${alias}: codex binary present"
      else
        fail_note "${alias}: codex binary missing"
        return
      fi
      if check_auth_hint "${alias}: codex" CODEX_API_KEY OPENAI_API_KEY; then
        :
      elif [[ -d "${HOME}/.codex" ]]; then
        pass_note "${alias}: codex auth heuristic satisfied by \$HOME/.codex"
      else
        fail_note "${alias}: codex auth heuristic missing (CODEX_API_KEY/OPENAI_API_KEY or \$HOME/.codex)"
      fi
      ;;
    copilot)
      if command -v copilot >/dev/null 2>&1; then
        pass_note "${alias}: copilot binary present"
      else
        fail_note "${alias}: copilot binary missing"
        return
      fi
      if check_auth_hint "${alias}: copilot" COPILOT_GITHUB_TOKEN GH_TOKEN GITHUB_TOKEN; then
        :
      else
        fail_note "${alias}: copilot auth heuristic missing (COPILOT_GITHUB_TOKEN/GH_TOKEN/GITHUB_TOKEN)"
      fi
      ;;
    cursor)
      if command -v cursor-agent >/dev/null 2>&1; then
        pass_note "${alias}: cursor-agent binary present"
      else
        fail_note "${alias}: cursor-agent binary missing"
        return
      fi
      if [[ -n "${CURSOR_API_KEY:-}" ]]; then
        pass_note "${alias}: cursor auth heuristic satisfied by CURSOR_API_KEY"
      else
        fail_note "${alias}: cursor auth heuristic missing (CURSOR_API_KEY)"
      fi
      ;;
    claude-code)
      if command -v claude >/dev/null 2>&1; then
        pass_note "${alias}: claude binary present"
      else
        fail_note "${alias}: claude binary missing"
        return
      fi
      if check_auth_hint "${alias}: claude" ANTHROPIC_API_KEY; then
        :
      elif [[ -d "${HOME}/.claude" || -d "${HOME}/.config/claude" ]]; then
        pass_note "${alias}: claude auth heuristic satisfied by local config"
      else
        fail_note "${alias}: claude auth heuristic missing (ANTHROPIC_API_KEY or local config)"
      fi
      ;;
    gemini-cli)
      if command -v gemini >/dev/null 2>&1; then
        pass_note "${alias}: gemini binary present"
      else
        fail_note "${alias}: gemini binary missing"
        return
      fi
      if check_auth_hint "${alias}: gemini" GEMINI_API_KEY GOOGLE_API_KEY GOOGLE_GENAI_USE_VERTEXAI GOOGLE_APPLICATION_CREDENTIALS; then
        :
      elif [[ -d "${HOME}/.gemini" ]]; then
        pass_note "${alias}: gemini auth heuristic satisfied by \$HOME/.gemini"
      else
        fail_note "${alias}: gemini auth heuristic missing (env var or \$HOME/.gemini)"
      fi

      if have_flag gemini --prompt && have_flag gemini --model && have_flag gemini --yolo; then
        pass_note "${alias}: required gemini headless flags are available"
      else
        fail_note "${alias}: required gemini flags missing (--prompt, --model, or --yolo)"
      fi
      if have_flag gemini --output-format; then
        pass_note "${alias}: gemini supports --output-format"
      else
        warn_note "${alias}: gemini lacks --output-format; output capture will be less structured"
      fi
      if have_flag gemini --session-summary; then
        pass_note "${alias}: gemini supports --session-summary"
      else
        warn_note "${alias}: gemini lacks --session-summary; telemetry sidecar will be skipped"
      fi
      ;;
    *)
      fail_note "${alias}: unsupported platform '${platform}'"
      ;;
  esac
}

preflight
pass_note "candidate prompt present"
pass_note "sealed manifest present"
pass_note "repo root resolved to ${REPO_DIR}"

check_remote_readiness

scratch="${WORKTREES_DIR}/.doctor-$$"
trap 'rm -rf "${scratch}"' EXIT
write_probe "${RUNS_DIR}/.doctor-write-test"
pass_note "runs directory is writable"
write_probe "${WORKTREES_DIR}/.doctor-write-test"
pass_note "worktrees directory is writable"
write_probe "${scratch}/.gemini/settings.json"
pass_note "scratch config directory is writable"

declare -a aliases=()
if [[ -n "${ALIAS}" ]]; then
  aliases=("${ALIAS}")
else
  require_stage "${STAGE}"
  mapfile -t aliases < <(manifest_aliases "${STAGE}")
fi

if [[ ${#aliases[@]} -eq 0 ]]; then
  fail_note "no manifest aliases found for stage '${STAGE}'"
else
  pass_note "candidate set resolved (${#aliases[@]} alias(es))"
fi

for alias in "${aliases[@]}"; do
  check_alias "${alias}"
done

log "doctor summary: pass=${pass_count} warn=${warn_count} fail=${fail_count}"
[[ ${fail_count} -eq 0 ]] || exit 1
