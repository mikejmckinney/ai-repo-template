#!/usr/bin/env bash
# scripts/checks/169-task-parallelism-preflight.sh — structural Phase 0A checks.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking task-parallelism Phase 0A apparatus..."

  TASK_PARALLELISM_PROTOCOL=".context/benchmarks/model-roi/task-parallelism"
  TASK_PARALLELISM_RUNNER="scripts/benchmark/task-parallelism"
  required=(
    "${TASK_PARALLELISM_PROTOCOL}/README.md"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0a.json"
    "${TASK_PARALLELISM_PROTOCOL}/asset-manifest.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/assets/manifest.json"
    "${TASK_PARALLELISM_PROTOCOL}/tasks/vector-siege.md"
    "${TASK_PARALLELISM_RUNNER}/Makefile"
    "${TASK_PARALLELISM_RUNNER}/requirements.txt"
    "${TASK_PARALLELISM_RUNNER}/run-preflight.sh"
    "${TASK_PARALLELISM_RUNNER}/preflight_launcher.py"
    "${TASK_PARALLELISM_RUNNER}/preflight.py"
    "${TASK_PARALLELISM_RUNNER}/generate-placeholder-assets.py"
    "scripts/tests/task-parallelism-preflight.bats"
  )

  for path in "${required[@]}"; do
    if [[ -f "${path}" ]]; then
      pass "${path} exists"
    else
      fail "${path} is missing"
    fi
  done

  for path in \
    "${TASK_PARALLELISM_PROTOCOL}/campaign.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0a.json" \
    "${TASK_PARALLELISM_PROTOCOL}/asset-manifest.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/assets/manifest.json"; do
    if jq -e . "${path}" >/dev/null 2>&1; then
      pass "valid JSON: ${path}"
    else
      fail "invalid JSON: ${path}"
    fi
  done

  if bash -n "${TASK_PARALLELISM_RUNNER}/run-preflight.sh"; then
    pass "bash -n ${TASK_PARALLELISM_RUNNER}/run-preflight.sh"
  else
    fail "bash -n ${TASK_PARALLELISM_RUNNER}/run-preflight.sh"
  fi

  if PYTHONDONTWRITEBYTECODE=1 python3 "${TASK_PARALLELISM_RUNNER}/preflight.py" --validate-structure >/dev/null; then
    pass "tracked Phase 0A campaign and assets validate"
  else
    fail "tracked Phase 0A campaign or assets are invalid"
  fi

  echo ""
fi
