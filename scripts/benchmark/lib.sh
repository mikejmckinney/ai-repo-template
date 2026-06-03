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
# Candidate-safe injected task specs. Each benchmark TASK must have one file
# named <task-id>.md unless TASK_FILE is explicitly supplied.
TASKS_DIR="${TASKS_DIR:-${REPO_DIR}/.context/benchmarks/model-roi/tasks}"
TASK_FILE="${TASK_FILE:-}"

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
  [[ "${stage}" == "1" ]] || die "Phase A for issue #374 is Stage-1-only; set STAGE=1"
}

task_file_path() {
  local task="$1"
  if [[ -n "${TASK_FILE}" ]]; then
    printf '%s' "${TASK_FILE}"
  else
    printf '%s/%s.md' "${TASKS_DIR}" "${task}"
  fi
}

task_meta_value() {
  local file="$1" key="$2"
  awk -F ': *' -v key="${key}" '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { exit }
    in_fm && $1 == key { print $2; exit }
  ' "${file}"
}

task_candidate_body() {
  local file="$1"
  awk '
    /^## Candidate task$/ { emit = 1; next }
    /^## Reference solution/ { emit = 0 }
    emit { print }
  ' "${file}"
}

require_task_file() {
  local task="$1" file class body
  file="$(task_file_path "${task}")"
  [[ -f "${file}" ]] || die "task file not found for TASK=${task}: ${file}"
  class="$(task_meta_value "${file}" task_class)"
  [[ "${class}" == "A-operational" || "${class}" == "B-reasoning" ]] \
    || die "task file ${file} must set task_class: A-operational or B-reasoning"
  body="$(task_candidate_body "${file}")"
  [[ -n "${body//[[:space:]]/}" ]] || die "task file ${file} has no ## Candidate task body"
  if grep -F -q 'INJECTED PER ROUND' <<<"${body}"; then
    die "task file ${file} still contains benchmark placeholder text"
  fi
}

render_prompt_for_run() {
  local task="$1" alias="$2" platform="$3" model="$4" agent="$5" base_sha="$6" run_index="$7" outdir="$8"
  local task_file task_class base_branch candidate_branch prompt_out task_body
  task_file="$(task_file_path "${task}")"
  require_task_file "${task}"
  task_class="$(task_meta_value "${task_file}" task_class)"
  base_branch="$(task_meta_value "${task_file}" base_branch)"
  [[ -n "${base_branch}" ]] || base_branch="benchmark/model-roi/base-${task}-YYYYMMDD"
  candidate_branch="$(branch_name "${task}" "${alias}")-r${run_index}"
  prompt_out="${outdir}/prompt-rendered.md"
  task_body="$(task_candidate_body "${task_file}")"

  awk -v alias="${alias}" \
      -v platform="${platform}" \
      -v model="${model}" \
      -v agent="${agent}" \
      -v task="${task}" \
      -v task_class="${task_class}" \
      -v base_branch="${base_branch}" \
      -v base_sha="${base_sha}" \
      -v run_index="${run_index}" \
      -v candidate_branch="${candidate_branch}" \
      -v task_body="${task_body}" '
    BEGIN { in_meta = 0; in_task = 0 }
    /^candidate_alias:/ {
      print "candidate_alias: " alias
      print "candidate_platform: " platform
      print "candidate_model: " model
      print "candidate_agent: " agent
      print "task_id: " task
      print "task_class: " task_class
      print "base_branch: " base_branch
      print "base_sha: " base_sha
      print "run_index: " run_index
      print "candidate_branch: " candidate_branch
      print "subissue: #374"
      in_meta = 1
      next
    }
    in_meta && /^```$/ { print; in_meta = 0; next }
    in_meta { next }
    /^## Task$/ {
      print
      print ""
      print task_body
      in_task = 1
      next
    }
    in_task && /^## Required implementation plan$/ {
      print
      in_task = 0
      next
    }
    in_task { next }
    { print }
  ' "${PROMPT_FILE}" > "${prompt_out}"

  if grep -F -q 'INJECTED PER ROUND' "${prompt_out}" || grep -F -q 'cand-<NN>' "${prompt_out}"; then
    die "rendered prompt still contains benchmark placeholder text: ${prompt_out}"
  fi
  printf '%s' "${prompt_out}"
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
#                        flag       -> a real CLI flag/override sets it (Codex, Copilot)
#                        config     -> set via a config-file alias the adapter writes (Gemini CLI)
#                        prompt     -> injected or approximated in prompt text (Claude Code, Cursor)
#                        none       -> harness exposes no per-run control
# Trailing columns are optional for backward compat: if absent, effort=default, mechanism=none.
# Lines starting with # and blank lines are ignored.
# manifest_lookup ALIAS -> echoes "platform\tmodel\tagent\tstage\teffort\teffort_mechanism" or fails.
manifest_lookup() {
  manifest_lookup_in "${MANIFEST}" "$1"
}

# manifest_lookup_in FILE ALIAS -> echoes
# "platform\tmodel\tagent\tstage\teffort\teffort_mechanism" or fails.
manifest_lookup_in() {
  local manifest_file="$1" want="$2" a p m g s e em
  [[ -f "${manifest_file}" ]] || return 1
  while IFS=$'\t' read -r a p m g s e em; do
    [[ "${a}" =~ ^#.*$ || -z "${a}" ]] && continue
    if [[ "${a}" == "${want}" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${p}" "${m}" "${g}" "${s}" "${e:-default}" "${em:-none}"
      return 0
    fi
  done < "${manifest_file}"
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

alias_stage_from_row() {
  local row="$1" _p _m _g stage _e _em
  IFS=$'\t' read -r _p _m _g stage _e _em <<<"${row}"
  printf '%s' "${stage}"
}

require_alias_stage_one() {
  local alias="$1" row="$2" stage
  stage="$(alias_stage_from_row "${row}")"
  [[ "${stage}" == "1" ]] || {
    printf '[%s] ERROR: Phase A for issue #374 is Stage-1-only; %s resolves to stage %s\n' \
      "$(_ts)" "${alias}" "${stage}" >&2
    return 1
  }
}

# adapter_path PLATFORM -> the adapter script for that platform.
adapter_path() { printf '%s/adapters/%s.sh' "${RUNNER_DIR}" "$1"; }

# run_outdir TASK ALIAS RUN_INDEX -> the artifact directory for one run.
run_outdir() { printf '%s/%s/%s/r%s' "${RUNS_DIR}" "$1" "$2" "$3"; }

# result_file_path TASK ALIAS RUN_INDEX -> the terminal-state contract file.
result_file_path() { printf '%s/result.json' "$(run_outdir "$1" "$2" "$3")"; }

# suite_alias_set_path TASK STAGE -> durable record of the alias set a suite executed.
suite_alias_set_path() { printf '%s/%s/stage-%s-aliases.txt' "${RUNS_DIR}" "$1" "$2"; }

# suite_manifest_snapshot_path TASK STAGE -> frozen sealed manifest used by a suite.
suite_manifest_snapshot_path() { printf '%s/%s/stage-%s-manifest.tsv' "${RUNS_DIR}" "$1" "$2"; }

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

# ---- git push containment --------------------------------------------------
# Run the agent with push disabled so an over-eager agent (we pass --yolo-style
# flags) cannot push to a shared branch. The runner pushes deliberately later.
# This installs a per-run git wrapper at the front of PATH. Ordinary git
# commands still work; `git push` fails fast without touching global git config.
prepare_git_push_guard() {
  local outdir="$1"
  local real_git
  real_git="$(command -v git)" || die "git not found"

  local guard_dir="${outdir}/git-guard-bin"
  mkdir -p "${guard_dir}"
  cat > "${guard_dir}/git" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

cmd=""
args=("$@")
i=0
while [[ ${i} -lt ${#args[@]} ]]; do
  arg="${args[${i}]}"
  case "${arg}" in
    -C|-c|--git-dir|--work-tree|--namespace)
      i=$((i + 2))
      continue
      ;;
    --git-dir=*|--work-tree=*|--namespace=*)
      i=$((i + 1))
      continue
      ;;
    --*)
      i=$((i + 1))
      continue
      ;;
    -*)
      i=$((i + 1))
      continue
      ;;
    *)
      cmd="${arg}"
      break
      ;;
  esac
done

if [[ "${cmd}" == "push" ]]; then
  printf 'benchmark git guard: git push is disabled inside candidate runs; use make push from the runner\n' >&2
  exit 126
fi

exec "${BENCHMARK_REAL_GIT:?}" "$@"
SH
  chmod +x "${guard_dir}/git"

  export BENCHMARK_REAL_GIT="${real_git}"
  export GIT_TERMINAL_PROMPT=0
  export PATH="${guard_dir}:${PATH}"
  printf '%s\n' "${guard_dir}" > "${outdir}/git-guard-path.txt"
}
