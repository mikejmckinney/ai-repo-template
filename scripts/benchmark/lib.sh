#!/usr/bin/env bash
# lib.sh — shared helpers for the model-ROI benchmark runner.
# Sourced by run-candidate.sh and run-suite.sh. No side effects on source.

set -euo pipefail

# ---- paths -----------------------------------------------------------------
# RUNNER_DIR is the directory containing this file.
RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_DIR is the repository under test. Prefer git's own repo-root discovery
# so the runner still works if this subtree is relocated or invoked via symlink.
infer_repo_dir() {
  if git -C "${RUNNER_DIR}" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "${RUNNER_DIR}" rev-parse --show-toplevel
  else
    cd "${RUNNER_DIR}/../.." && pwd
  fi
}
REPO_DIR="${REPO_DIR:-$(infer_repo_dir)}"
# Where run artifacts land (gitignored).
RUNS_DIR="${RUNS_DIR:-${RUNNER_DIR}/runs}"
# Where transient worktrees land (gitignored).
WORKTREES_DIR="${WORKTREES_DIR:-${RUNNER_DIR}/worktrees}"
# The sealed alias->model manifest (gitignored — this is the blind-grading seal).
MANIFEST="${MANIFEST:-${RUNNER_DIR}/candidates.tsv}"
# The task-agnostic candidate prompt, committed in the repo.
PROMPT_FILE="${PROMPT_FILE:-${REPO_DIR}/.github/prompts/model-roi-benchmark-candidate.md}"

# ---- logging ---------------------------------------------------------------
_ts()   { date -u +%Y-%m-%dT%H:%M:%SZ; }
log()   { printf '[%s] %s\n' "$(_ts)" "$*" >&2; }
die()   { printf '[%s] ERROR: %s\n' "$(_ts)" "$*" >&2; exit 1; }

# ---- json helpers ----------------------------------------------------------
have_jq() { command -v jq >/dev/null 2>&1; }
# json_escape STR -> JSON string literal (no surrounding work needed).
json_escape() {
  if have_jq; then jq -Rn --arg s "$1" '$s'; else
    # crude fallback: escape backslash and double-quote, wrap in quotes
    local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '"%s"' "$s"
  fi
}
json_or_null() {
  if [[ -n "${1:-}" ]]; then
    json_escape "$1"
  else
    printf 'null'
  fi
}

# ---- preflight guards ------------------------------------------------------
# Refuse to run unless the environment is sane. Cheap insurance against
# corrupting the frozen base or operating on the wrong branch.
preflight() {
  command -v git >/dev/null 2>&1 || die "git not found"
  [[ -d "${REPO_DIR}/.git" ]] || die "REPO_DIR is not a git repo: ${REPO_DIR}"
  [[ -f "${PROMPT_FILE}" ]]   || die "candidate prompt not found: ${PROMPT_FILE}"
  [[ -f "${MANIFEST}" ]]      || die "manifest not found: ${MANIFEST} (see candidates.tsv.example)"
  mkdir -p "${RUNS_DIR}" "${WORKTREES_DIR}"
}
require_stage() {
  local stage="${1:-}"
  [[ -n "${stage}" ]] || die "set STAGE=1 (Phase A refuses an empty stage)"
}

# require_clean_base BASE_SHA — verify the SHA exists and is reachable.
require_base() {
  local base_sha="$1"
  git -C "${REPO_DIR}" cat-file -e "${base_sha}^{commit}" 2>/dev/null \
    || die "base SHA not found in repo: ${base_sha} (did you run 'make base' and fetch?)"
}

# ---- manifest --------------------------------------------------------------
# Manifest is TSV: alias  platform  model  agent  stage  effort  effort_mechanism
#   effort           : requested level (minimal|low|medium|high|xhigh) or "default"
#                      (legacy "fixed" is still accepted as "default" for backward compat)
#   effort_mechanism : how the adapter must apply it, since the 5 harnesses differ:
#                        flag       -> a real CLI flag/override sets it (Codex)
#                        config     -> set via a config-file alias the adapter writes (Gemini CLI)
#                        prompt     -> injected as thinking-keyword text into the prompt (Claude Code)
#                        suffix     -> encoded as a model-name suffix (Cursor; UNRELIABLE)
#                        none       -> harness exposes no per-run control (Copilot)
# Trailing columns are optional for backward compat: if absent, effort=default, mechanism=none.
# Lines starting with # and blank lines are ignored.
# manifest_lookup ALIAS -> echoes "platform\tmodel\tagent\tstage\teffort\teffort_mechanism" or fails.
manifest_lookup() {
  local want="$1" a p m g s e em
  while IFS=$'\t' read -r a p m g s e em; do
    [[ "${a}" =~ ^#.*$ || -z "${a}" ]] && continue
    if [[ "${a}" == "${want}" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${p}" "${m}" "${g}" "${s}" "${e:-default}" "${em:-none}"
      return 0
    fi
  done < "${MANIFEST}"
  return 1
}

# manifest_aliases [STAGE] -> list aliases, optionally filtered by stage column.
manifest_aliases() {
  local filter_stage="${1:-}" a p m g s e em
  while IFS=$'\t' read -r a p m g s e em; do
    [[ "${a}" =~ ^#.*$ || -z "${a}" ]] && continue
    if [[ -z "${filter_stage}" || "${s}" == "${filter_stage}" ]]; then printf '%s\n' "${a}"; fi
  done < "${MANIFEST}"
}

# adapter_path PLATFORM -> the adapter script for that platform.
adapter_path() { printf '%s/adapters/%s.sh' "${RUNNER_DIR}" "$1"; }

# run_outdir TASK ALIAS RUN_INDEX -> the artifact directory for one run.
run_outdir() { printf '%s/%s/%s/r%s' "${RUNS_DIR}" "$1" "$2" "$3"; }

# result_file_path TASK ALIAS RUN_INDEX -> the terminal-state contract file.
result_file_path() { printf '%s/result.json' "$(run_outdir "$1" "$2" "$3")"; }

# derive_effort_status REQUESTED MECHANISM APPLIED_DESC -> neutral blind token.
derive_effort_status() {
  local effort="${1:-default}" mech="${2:-none}" applied="${3:-}"
  local status
  case "${effort}" in
    default|fixed|none|"") status="default";;
    *)
      case "${mech}" in
        flag|config) status="applied";;
        prompt)
          case "${applied}" in
            *inline-directive*) status="requested";;
            *)                  status="approximated";;
          esac
          ;;
        none)   status="not-applied";;
        suffix) status="requested";;
        *)      status="unknown";;
      esac
      ;;
  esac
  case "${applied}" in
    *NOT-APPLIED*) status="not-applied";;
  esac
  printf '%s' "${status}"
}

# write_result_file OUTDIR ALIAS TASK RUN_INDEX STAGE STATE HEAD_SHA RC MANUAL_OK BLIND SEALED DIFF
write_result_file() {
  local outdir="$1" alias="$2" task="$3" run_index="$4" stage="$5" state="$6"
  local head_sha="${7:-}" adapter_rc="${8:-}" manual_ok="${9:-false}"
  local blind_rel="${10:-}" sealed_rel="${11:-}" diff_rel="${12:-}"

  {
    printf '{\n'
    printf '  "schema_version": "benchmark-result.v1",\n'
    printf '  "alias": %s,\n' "$(json_escape "${alias}")"
    printf '  "task_id": %s,\n' "$(json_escape "${task}")"
    printf '  "run_index": %s,\n' "${run_index}"
    printf '  "stage": %s,\n' "$(json_escape "${stage}")"
    printf '  "terminal_state": %s,\n' "$(json_escape "${state}")"
    printf '  "recorded_at": %s,\n' "$(json_escape "$(_ts)")"
    printf '  "head_sha": %s,\n' "$(json_or_null "${head_sha}")"
    printf '  "adapter_exit_code": %s,\n' "${adapter_rc:-null}"
    printf '  "manual_fallback_allowed": %s,\n' "${manual_ok}"
    printf '  "artifacts": {\n'
    printf '    "blind_metadata": %s,\n' "$(json_or_null "${blind_rel}")"
    printf '    "sealed_metadata": %s,\n' "$(json_or_null "${sealed_rel}")"
    printf '    "diff_patch": %s\n' "$(json_or_null "${diff_rel}")"
    printf '  }\n'
    printf '}\n'
  } > "${outdir}/result.json"
}

# ---- worktree lifecycle ----------------------------------------------------
# branch_name TASK ALIAS -> the aliased candidate branch (no model identity).
branch_name() { printf 'benchmark/model-roi/%s-%s' "$1" "$2"; }

# worktree_path TASK ALIAS RUN_INDEX
worktree_path() { printf '%s/%s-%s-r%s' "${WORKTREES_DIR}" "$1" "$2" "$3"; }

# make_worktree TASK ALIAS RUN_INDEX BASE_SHA -> echoes the worktree path.
# Creates a fresh worktree checked out at BASE_SHA on a per-run branch.
make_worktree() {
  local task="$1" alias="$2" ri="$3" base_sha="$4"
  local wt; wt="$(worktree_path "${task}" "${alias}" "${ri}")"
  local br; br="$(branch_name "${task}" "${alias}")-r${ri}"
  if git -C "${REPO_DIR}" worktree list --porcelain | grep -qx "worktree ${wt}"; then
    log "worktree already exists, reusing: ${wt}"
  else
    rm -rf "${wt}"
    # -B resets the branch to base_sha if it already existed from a prior aborted run.
    git -C "${REPO_DIR}" worktree add -B "${br}" "${wt}" "${base_sha}" >&2
  fi
  printf '%s' "${wt}"
}

# drop_worktree TASK ALIAS RUN_INDEX — remove the worktree (keeps the branch).
drop_worktree() {
  local wt; wt="$(worktree_path "$1" "$2" "$3")"
  git -C "${REPO_DIR}" worktree remove --force "${wt}" 2>/dev/null || rm -rf "${wt}"
}

# ---- git credential containment -------------------------------------------
# Run the agent with push disabled so an over-eager agent (we pass --yolo-style
# flags) cannot push to a shared branch. The runner pushes deliberately later.
# This sets a per-invocation env that points git at a credential helper that
# always fails, without touching the user's global git config.
deny_push_env() {
  # GIT_TERMINAL_PROMPT=0 stops interactive credential prompts from hanging.
  printf 'GIT_TERMINAL_PROMPT=0'
}
