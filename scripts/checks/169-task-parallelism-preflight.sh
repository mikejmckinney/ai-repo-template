#!/usr/bin/env bash
# scripts/checks/169-task-parallelism-preflight.sh — task-parallelism preparation checks.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking task-parallelism Phase 0A and Phase 0B preparation apparatus..."

  TASK_PARALLELISM_PROTOCOL=".context/benchmarks/model-roi/task-parallelism"
  TASK_PARALLELISM_RUNNER="scripts/benchmark/task-parallelism"
  required=(
    "${TASK_PARALLELISM_PROTOCOL}/README.md"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0a.json"
    "${TASK_PARALLELISM_PROTOCOL}/asset-manifest.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/assets/manifest.json"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.preparation.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-preparation.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-candidate-result.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-candidate-report.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-execution.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-pilot-summary.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.execution.json"
    "${TASK_PARALLELISM_PROTOCOL}/candidate-base.gitignore"
    "${TASK_PARALLELISM_PROTOCOL}/scaffold/package-lock.json"
    "${TASK_PARALLELISM_PROTOCOL}/tasks/vector-siege.md"
    "${TASK_PARALLELISM_PROTOCOL}/tasks/vector-siege-stage-1-candidate.md"
    "${TASK_PARALLELISM_RUNNER}/Makefile"
    "${TASK_PARALLELISM_RUNNER}/requirements.txt"
    "${TASK_PARALLELISM_RUNNER}/run-preflight.sh"
    "${TASK_PARALLELISM_RUNNER}/preflight_launcher.py"
    "${TASK_PARALLELISM_RUNNER}/preflight.py"
    "${TASK_PARALLELISM_RUNNER}/generate-placeholder-assets.py"
    "${TASK_PARALLELISM_RUNNER}/prepare-phase-0b.py"
    "${TASK_PARALLELISM_RUNNER}/run-phase-0b.py"
    "scripts/tests/task-parallelism-preflight.bats"
    "scripts/tests/task-parallelism-phase-0b.bats"
    "scripts/tests/task-parallelism-phase-0b-execution.bats"
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
    "${TASK_PARALLELISM_PROTOCOL}/assets/manifest.json" \
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.preparation.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-preparation.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-candidate-result.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-candidate-report.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-execution.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.execution.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-pilot-summary.schema.json"; do
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

  if PYTHONDONTWRITEBYTECODE=1 python3 "${TASK_PARALLELISM_RUNNER}/preflight.py" >/dev/null; then
    pass "tracked Phase 0A campaign and assets validate"
  else
    fail "tracked Phase 0A campaign or assets are invalid"
  fi

  if PYTHONDONTWRITEBYTECODE=1 python3 "${TASK_PARALLELISM_RUNNER}/prepare-phase-0b.py" --validate >/dev/null; then
    pass "tracked Phase 0B preparation validates and remains blocked"
  else
    fail "tracked Phase 0B preparation is invalid"
  fi

  if PYTHONDONTWRITEBYTECODE=1 python3 "${TASK_PARALLELISM_RUNNER}/run-phase-0b.py" --validate-state >/dev/null; then
    pass "tracked Phase 0B execution state validates"
  else
    fail "tracked Phase 0B execution state is invalid"
  fi

  echo ""
fi
