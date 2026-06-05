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
BENCHMARK_SUBISSUE="${BENCHMARK_SUBISSUE:-#374}"
# Candidate-safe injected task specs. Each benchmark TASK must have one file
# named <task-id>.md unless TASK_FILE is explicitly supplied.
TASKS_DIR="${TASKS_DIR:-${REPO_DIR}/.context/benchmarks/model-roi/tasks}"
TASK_FILE="${TASK_FILE:-}"
# Context variant for experiments. The default preserves current behavior.
# "agents-import-only" leaves AGENTS.md unchanged but adds @AGENTS.md to
# CLAUDE.md, isolating whether Claude Code reads the default AGENTS.md.
# "full-rules-injected" appends .context/rules/*.md into AGENTS.md in the
# candidate worktree for the duration of the agent run only.
CONTEXT_VARIANT="${CONTEXT_VARIANT:-baseline}"
ORCHESTRATION_VARIANT="${ORCHESTRATION_VARIANT:-none}"

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
      print "subissue: " subissue
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
  ' subissue="${BENCHMARK_SUBISSUE}" "${PROMPT_FILE}" > "${prompt_out}"

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

context_variant_slug() {
  local variant="${1:-baseline}"
  case "${variant}" in
    baseline|"") printf 'baseline';;
    agents-import-only) printf 'agents-import-only';;
    full-rules-injected) printf 'full-rules-injected';;
    *) die "unknown context variant: ${variant}";;
  esac
}

orchestration_variant_slug() {
  local variant="${1:-none}"
  case "${variant}" in
    none|"") printf 'none';;
    pipeline-existing-overlays) printf 'pipeline-existing-overlays';;
    pipeline-same-model) printf 'pipeline-same-model';;
    *) die "unknown orchestration variant: ${variant}";;
  esac
}

orchestration_metadata_path() {
  printf '%s/orchestration-overlay.json' "$1"
}

_frontmatter_set_model() {
  local file="$1" model_line="$2"
  awk -v replacement="${model_line}" '
    BEGIN { in_fm = 0; replaced = 0 }
    NR == 1 && $0 == "---" { in_fm = 1; print; next }
    in_fm && $0 == "---" {
      if (!replaced) print replacement
      in_fm = 0
      print
      next
    }
    in_fm && $0 ~ /^model:/ {
      if (!replaced) {
        print replacement
        replaced = 1
      }
      next
    }
    { print }
  ' "${file}" > "${file}.bench.tmp"
  mv "${file}.bench.tmp" "${file}"
}

_toml_set_key() {
  local file="$1" key="$2" value="$3"
  awk -v key="${key}" -v replacement="${key} = \"" value "\"" '
    BEGIN { replaced = 0 }
    $0 ~ "^" key " = " {
      if (!replaced) {
        print replacement
        replaced = 1
      }
      next
    }
    { print }
    END {
      if (!replaced) print replacement
    }
  ' "${file}" > "${file}.bench.tmp"
  mv "${file}.bench.tmp" "${file}"
}

_overlay_model_for_platform() {
  local platform="$1" model="$2"
  case "${platform}" in
    cursor)
      if [[ "${model}" == "auto" ]]; then
        printf 'inherit'
      else
        printf '%s' "${model}"
      fi
      ;;
    gemini-cli)
      # Gemini subagent overlays inherit the parent model when model is omitted.
      printf '%s' "${model}"
      ;;
    *)
      printf '%s' "${model}"
      ;;
  esac
}

_write_gemini_agent_overlays() {
  local wt="$1" outdir="$2"
  local src_dir="${wt}/.agents" dest_dir="${wt}/.gemini/agents"
  if [[ ! -d "${src_dir}" && -d "${REPO_DIR}/.agents" ]]; then
    src_dir="${REPO_DIR}/.agents"
  fi
  [[ -d "${src_dir}" ]] || die "cannot create Gemini overlays: missing ${src_dir}"
  mkdir -p "${dest_dir}"
  local role name desc
  while IFS= read -r role; do
    name="$(basename "${role}" .md)"
    desc="$(awk -F ': *' 'NR == 1 && $0 == "---" { in_fm = 1; next } in_fm && $1 == "description" { print substr($0, index($0,$2)); exit }' "${role}")"
    {
      printf -- '---\n'
      printf 'name: %s\n' "${name}"
      printf 'description: %s\n' "${desc}"
      printf 'kind: local\n'
      printf -- '---\n\n'
      printf '# %s (Gemini CLI benchmark overlay)\n\n' "${name}"
      printf 'See canonical role definition: ../../.agents/%s.md\n' "${name}"
    } > "${dest_dir}/${name}.md"
  done < <(find "${src_dir}" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' ! -name '_TEMPLATE.md' | sort)
  cp -R "${dest_dir}" "${outdir}/gemini-agents.after-orchestration-overlay"
}

_seed_missing_overlay_dir() {
  local wt="$1" outdir="$2" rel_dir="$3"
  local target="${wt}/${rel_dir}" source="${REPO_DIR}/${rel_dir}"
  [[ -d "${target}" ]] && return 1
  [[ -d "${source}" ]] || die "missing overlay seed source: ${source}"
  mkdir -p "$(dirname "${target}")"
  cp -R "${source}" "${target}"
  printf '%s\n' "${rel_dir}" >> "${outdir}/orchestration-generated-dirs.txt"
  return 0
}

apply_orchestration_variant() {
  local wt="$1" outdir="$2" variant="$3" platform="$4" model="$5" effort="$6"
  variant="$(orchestration_variant_slug "${variant}")"
  printf '%s\n' "${variant}" > "${outdir}/orchestration-variant.txt"

  if [[ "${variant}" == "none" || "${variant}" == "pipeline-existing-overlays" ]]; then
    {
      printf '{\n'
      printf '  "orchestration_variant": %s,\n' "$(json_escape "${variant}")"
      printf '  "overlays_modified": false,\n'
      printf '  "strategy": %s\n' "$(json_escape "$([[ "${variant}" == "pipeline-existing-overlays" ]] && printf 'use committed platform overlays unchanged' || printf 'monolithic/no pipeline overlay')")"
      printf '}\n'
    } > "$(orchestration_metadata_path "${outdir}")"
    return 0
  fi

  local overlay_model
  overlay_model="$(_overlay_model_for_platform "${platform}" "${model}")"
  local changed_count=0 created_count=0 overlay_dir="" suffix="" rel file

  case "${platform}" in
    copilot)
      overlay_dir="${wt}/.github/agents"; suffix=".agent.md" ;;
    claude-code)
      overlay_dir="${wt}/.claude/agents"; suffix=".md" ;;
    cursor)
      overlay_dir="${wt}/.cursor/agents"; suffix=".md" ;;
    codex)
      overlay_dir="${wt}/.codex/agents"; suffix=".toml" ;;
    gemini-cli)
      _write_gemini_agent_overlays "${wt}" "${outdir}"
      created_count="$(find "${wt}/.gemini/agents" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
      ;;
    *)
      die "orchestration overlay variant does not know platform: ${platform}" ;;
  esac

  if [[ -n "${overlay_dir}" ]]; then
    local rel_overlay_dir="${overlay_dir#${wt}/}"
    _seed_missing_overlay_dir "${wt}" "${outdir}" "${rel_overlay_dir}" && created_count="$(find "${overlay_dir}" -maxdepth 1 -type f -name "*${suffix}" | wc -l | tr -d ' ')"
    [[ -d "${overlay_dir}" ]] || die "missing platform overlay directory: ${overlay_dir}"
    mkdir -p "${outdir}/orchestration-overlays-before"
    while IFS= read -r file; do
      rel="${file#${wt}/}"
      mkdir -p "${outdir}/orchestration-overlays-before/$(dirname "${rel}")"
      cp "${file}" "${outdir}/orchestration-overlays-before/${rel}"
      case "${platform}" in
        codex)
          _toml_set_key "${file}" "model" "${overlay_model}"
          if [[ "${effort}" =~ ^(minimal|low|medium|high|xhigh)$ ]]; then
            _toml_set_key "${file}" "model_reasoning_effort" "${effort}"
          fi
          ;;
        copilot)
          _frontmatter_set_model "${file}" "model: '${overlay_model}'" ;;
        *)
          _frontmatter_set_model "${file}" "model: ${overlay_model}" ;;
      esac
      git -C "${wt}" update-index --skip-worktree "${rel}" 2>/dev/null || true
      changed_count=$((changed_count + 1))
    done < <(find "${overlay_dir}" -maxdepth 1 -type f -name "*${suffix}" | sort)
  fi

  local sha_src="${outdir}/orchestration-overlays.after.tar"
  tar -C "${wt}" -cf "${sha_src}" .github/agents .claude/agents .cursor/agents .codex/agents .gemini/agents 2>/dev/null || true
  {
    printf '{\n'
    printf '  "orchestration_variant": %s,\n' "$(json_escape "${variant}")"
    printf '  "overlays_modified": true,\n'
    printf '  "strategy": "patch candidate worktree overlays so every role uses the candidate model where the platform supports overlays",\n'
    printf '  "platform": %s,\n' "$(json_escape "${platform}")"
    printf '  "model_policy": %s,\n' "$(json_escape "same-model:${overlay_model}")"
    printf '  "effort_policy": %s,\n' "$(json_escape "same-effort:${effort}")"
    printf '  "tracked_overlay_files_modified": %s,\n' "${changed_count}"
    printf '  "generated_overlay_files": %s,\n' "${created_count}"
    printf '  "artifact_sha256": %s\n' "$(json_escape "$(sha256sum "${sha_src}" | awk '{print $1}')")"
    printf '}\n'
  } > "$(orchestration_metadata_path "${outdir}")"
}

restore_orchestration_variant() {
  local wt="$1" outdir="$2" variant="$3"
  variant="$(orchestration_variant_slug "${variant}")"
  [[ "${variant}" == "none" || "${variant}" == "pipeline-existing-overlays" ]] && return 0

  if [[ -d "${outdir}/orchestration-overlays-before" ]]; then
    local before rel
    while IFS= read -r before; do
      rel="${before#${outdir}/orchestration-overlays-before/}"
      mkdir -p "${wt}/$(dirname "${rel}")"
      cp "${before}" "${wt}/${rel}"
      git -C "${wt}" update-index --no-skip-worktree "${rel}" 2>/dev/null || true
    done < <(find "${outdir}/orchestration-overlays-before" -type f | sort)
  fi
  if [[ -d "${wt}/.gemini/agents" ]]; then
    rm -rf "${wt}/.gemini/agents"
    rmdir "${wt}/.gemini" 2>/dev/null || true
  fi
  if [[ -f "${outdir}/orchestration-generated-dirs.txt" ]]; then
    local generated
    while IFS= read -r generated; do
      [[ -n "${generated}" ]] || continue
      rm -rf "${wt}/${generated}"
      rmdir "${wt}/$(dirname "${generated}")" 2>/dev/null || true
    done < "${outdir}/orchestration-generated-dirs.txt"
  fi
}

context_injection_metadata_path() {
  printf '%s/context-injection.json' "$1"
}

apply_context_variant() {
  local wt="$1" outdir="$2" variant="$3"
  variant="$(context_variant_slug "${variant}")"
  printf '%s\n' "${variant}" > "${outdir}/context-variant.txt"

  if [[ "${variant}" == "baseline" ]]; then
    {
      printf '{\n'
      printf '  "context_variant": "baseline",\n'
      printf '  "injected": false\n'
      printf '}\n'
    } > "$(context_injection_metadata_path "${outdir}")"
    return 0
  fi

  if [[ "${variant}" == "agents-import-only" ]]; then
    local agents="${wt}/AGENTS.md"
    local claude="${wt}/CLAUDE.md"
    [[ -f "${agents}" ]] || die "cannot import AGENTS.md: missing ${agents}"
    [[ -f "${claude}" ]] || die "cannot add Claude AGENTS import: missing ${claude}"

    cp "${claude}" "${outdir}/CLAUDE.md.before-context-injection"
    local changed=false
    if ! grep -Fxq '@AGENTS.md' "${claude}"; then
      {
        printf '\n\n## Benchmark context import\n\n'
        printf '@AGENTS.md\n'
      } >> "${claude}"
      changed=true
    fi
    git -C "${wt}" update-index --skip-worktree CLAUDE.md

    {
      printf '{\n'
      printf '  "context_variant": %s,\n' "$(json_escape "${variant}")"
      printf '  "injected": false,\n'
      printf '  "agents_unchanged": true,\n'
      printf '  "claude_agents_import": true,\n'
      printf '  "claude_changed": %s,\n' "${changed}"
      printf '  "artifacts": {\n'
      printf '    "claude_before": "CLAUDE.md.before-context-injection"\n'
      printf '  }\n'
      printf '}\n'
    } > "$(context_injection_metadata_path "${outdir}")"
    return 0
  fi

  local agents="${wt}/AGENTS.md"
  local claude="${wt}/CLAUDE.md"
  local rules_dir="${wt}/.context/rules"
  [[ -f "${agents}" ]] || die "cannot inject context: missing ${agents}"
  [[ -d "${rules_dir}" ]] || die "cannot inject context: missing ${rules_dir}"

  cp "${agents}" "${outdir}/AGENTS.md.before-context-injection"
  if [[ -f "${claude}" ]]; then
    cp "${claude}" "${outdir}/CLAUDE.md.before-context-injection"
  fi

  local injected="${outdir}/AGENTS.md.full-rules-injected"
  cp "${agents}" "${injected}"
  {
    printf '\n\n<!-- BENCHMARK_CONTEXT_INJECTION_START -->\n'
    printf '\n## Benchmark Context Injection: Full `.context/rules/*.md`\n\n'
    printf 'This section is injected by the model-ROI benchmark harness for the Stage 1C context-injection variant. Treat these rule-file contents as canonical project instructions for this run.\n'
  } >> "${injected}"

  local rule count=0
  while IFS= read -r rule; do
    count=$((count + 1))
    {
      printf '\n\n### Begin `%s`\n\n' "${rule#${wt}/}"
      sed -n '1,$p' "${rule}"
      printf '\n\n### End `%s`\n' "${rule#${wt}/}"
    } >> "${injected}"
  done < <(find "${rules_dir}" -maxdepth 1 -type f -name '*.md' | sort)

  {
    printf '\n<!-- BENCHMARK_CONTEXT_INJECTION_END -->\n'
  } >> "${injected}"

  cp "${injected}" "${agents}"
  if [[ -f "${claude}" ]] && ! grep -Fxq '@AGENTS.md' "${claude}"; then
    {
      printf '\n\n## Benchmark context import\n\n'
      printf '@AGENTS.md\n'
    } >> "${claude}"
  fi
  git -C "${wt}" update-index --skip-worktree AGENTS.md
  if [[ -f "${claude}" ]]; then
    git -C "${wt}" update-index --skip-worktree CLAUDE.md
  fi

  local bytes sha
  bytes="$(wc -c < "${injected}" | tr -d ' ')"
  sha="$(sha256sum "${injected}" | awk '{print $1}')"
  {
    printf '{\n'
    printf '  "context_variant": %s,\n' "$(json_escape "${variant}")"
    printf '  "injected": true,\n'
    printf '  "source_glob": ".context/rules/*.md",\n'
    printf '  "rule_file_count": %s,\n' "${count}"
    printf '  "injected_agents_bytes": %s,\n' "${bytes}"
    printf '  "injected_agents_sha256": %s,\n' "$(json_escape "${sha}")"
    printf '  "artifacts": {\n'
    printf '    "agents_before": "AGENTS.md.before-context-injection",\n'
    printf '    "agents_injected": "AGENTS.md.full-rules-injected"'
    if [[ -f "${outdir}/CLAUDE.md.before-context-injection" ]]; then
      printf ',\n    "claude_before": "CLAUDE.md.before-context-injection"'
    fi
    printf '\n  }\n'
    printf '}\n'
  } > "$(context_injection_metadata_path "${outdir}")"
}

restore_context_variant() {
  local wt="$1" outdir="$2" variant="$3"
  variant="$(context_variant_slug "${variant}")"
  [[ "${variant}" == "baseline" ]] && return 0

  if [[ -f "${outdir}/AGENTS.md.before-context-injection" ]]; then
    cp "${outdir}/AGENTS.md.before-context-injection" "${wt}/AGENTS.md"
    git -C "${wt}" update-index --no-skip-worktree AGENTS.md 2>/dev/null || true
  fi
  if [[ -f "${outdir}/CLAUDE.md.before-context-injection" ]]; then
    cp "${outdir}/CLAUDE.md.before-context-injection" "${wt}/CLAUDE.md"
    git -C "${wt}" update-index --no-skip-worktree CLAUDE.md 2>/dev/null || true
  fi
}

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
