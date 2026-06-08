#!/usr/bin/env bash
# scripts/checks/167-context-pack-manifests.sh — validate Stage 1E context-pack manifests
# and run a non-metered apply/restore smoke for pack:core-min.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking context-pack manifests..."

  PACKS_DIR=".context/benchmarks/model-roi/context-packs"
  REQUIRED_PACKS=(core-min class-a-process class-b-implementation workflow-risk adr-docs)

  if [[ -f "${PACKS_DIR}/README.md" ]]; then
    pass "${PACKS_DIR}/README.md exists"
  else
    fail "${PACKS_DIR}/README.md is missing"
  fi

  for pack in "${REQUIRED_PACKS[@]}"; do
    manifest="${PACKS_DIR}/${pack}.tsv"
    if [[ -f "${manifest}" ]]; then
      pass "context pack manifest exists: ${manifest}"
    else
      fail "context pack manifest missing: ${manifest}"
      continue
    fi

    if [[ ! "${pack}" =~ ^[A-Za-z0-9._-]+$ ]]; then
      fail "invalid pack id: ${pack}"
    fi

    while IFS=$'\t' read -r path _reason; do
      [[ "${path}" =~ ^#.*$ || -z "${path}" ]] && continue
      case "${path}" in
        /*)
          fail "absolute path in ${manifest}: ${path}"
          continue
          ;;
        *..*)
          fail "path traversal in ${manifest}: ${path}"
          continue
          ;;
        AGENTS.md | CLAUDE.md)
          fail "${manifest} must not reference ${path}"
          continue
          ;;
        .git | .git/*)
          fail "${manifest} must not reference .git: ${path}"
          continue
          ;;
        scripts/benchmark/runs/* | scripts/benchmark/worktrees/*)
          fail "${manifest} must not reference benchmark artifacts: ${path}"
          continue
          ;;
      esac
      if [[ -f "${path}" ]]; then
        pass "pack ${pack} path exists: ${path}"
      else
        fail "pack ${pack} missing file: ${path}"
      fi
    done <"${manifest}"
  done

  for example in \
    .context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example \
    .context/benchmarks/model-roi/stage-1e-pack-robustness-candidates.tsv.example; do
    if [[ -f "${example}" ]]; then
      pass "example candidate manifest exists: ${example}"
    else
      fail "example candidate manifest missing: ${example}"
    fi
  done

  if command -v jq >/dev/null 2>&1; then
    if (
      set -euo pipefail
      # shellcheck source=/dev/null
      source scripts/benchmark/lib.sh

      fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/pack-smoke.XXXXXX")"
      trap 'rm -rf "${fixture_root}"' EXIT

      fixture_wt="${fixture_root}/wt"
      mkdir -p "${fixture_wt}/.context/rules" "${fixture_wt}/.context/sessions" \
        "${fixture_root}/out"
      git -C "${fixture_wt}" init -q
      printf '# AGENTS\n' >"${fixture_wt}/AGENTS.md"
      printf '# CLAUDE\n' >"${fixture_wt}/CLAUDE.md"
      cp .context/00_INDEX.md "${fixture_wt}/.context/00_INDEX.md"
      cp .context/rules/agent_ownership.md "${fixture_wt}/.context/rules/agent_ownership.md"
      cp .context/sessions/latest_summary.md "${fixture_wt}/.context/sessions/latest_summary.md"
      git -C "${fixture_wt}" add -A

      apply_context_variant "${fixture_wt}" "${fixture_root}/out" "pack:core-min"
      jq -e . "${fixture_root}/out/context-injection.json" >/dev/null
    ); then
      pass "pack:core-min apply produces valid context-injection.json"
    else
      fail "pack:core-min apply smoke failed"
    fi

    if (
      set -euo pipefail
      # shellcheck source=/dev/null
      source scripts/benchmark/lib.sh

      fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/pack-restore.XXXXXX")"
      trap 'rm -rf "${fixture_root}"' EXIT

      fixture_wt="${fixture_root}/wt"
      mkdir -p "${fixture_wt}/.context/rules" "${fixture_wt}/.context/sessions" \
        "${fixture_root}/out"
      git -C "${fixture_wt}" init -q
      printf '# AGENTS\n' >"${fixture_wt}/AGENTS.md"
      printf '# CLAUDE\n' >"${fixture_wt}/CLAUDE.md"
      cp .context/00_INDEX.md "${fixture_wt}/.context/00_INDEX.md"
      cp .context/rules/agent_ownership.md "${fixture_wt}/.context/rules/agent_ownership.md"
      cp .context/sessions/latest_summary.md "${fixture_wt}/.context/sessions/latest_summary.md"
      git -C "${fixture_wt}" add -A

      apply_context_variant "${fixture_wt}" "${fixture_root}/out" "pack:core-min"
      grep -q "BENCHMARK_CONTEXT_PACK_START" "${fixture_wt}/AGENTS.md"
      restore_context_variant "${fixture_wt}" "${fixture_root}/out" "pack:core-min"
      if grep -q "BENCHMARK_CONTEXT_PACK_START" "${fixture_wt}/AGENTS.md"; then
        echo "AGENTS.md still contains injected pack after restore" >&2
        exit 1
      fi
    ); then
      pass "pack:core-min restore removes injected content from AGENTS.md"
    else
      fail "pack:core-min restore smoke failed"
    fi
  else
    warn "jq missing; skipping pack injection smoke tests"
  fi

  echo ""
  return 0
fi

echo "167-context-pack-manifests.sh is sourced by test.sh only" >&2
exit 1
