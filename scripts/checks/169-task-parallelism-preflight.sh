#!/usr/bin/env bash
# scripts/checks/169-task-parallelism-preflight.sh — task-parallelism preparation checks.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking task-parallelism Phase 0A, Phase 0B, and Phase 0C apparatus..."

  TASK_PARALLELISM_PROTOCOL=".context/benchmarks/model-roi/task-parallelism"
  TASK_PARALLELISM_RUNNER="scripts/benchmark/task-parallelism"
  required=(
    "${TASK_PARALLELISM_PROTOCOL}/README.md"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0a.json"
    "${TASK_PARALLELISM_PROTOCOL}/asset-manifest.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/assets/manifest.json"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.preparation.json"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.revision.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-preparation.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision-execution.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision-candidate-report.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision-candidate-result.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision-evaluator-result.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision-summary.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-diagnostic-summary.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/results/phase-0b-candidate-reports.json"
    "${TASK_PARALLELISM_PROTOCOL}/results/phase-0b-diagnostic-summary.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-candidate-result.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-candidate-report.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-execution.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-pilot-summary.schema.json"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.execution.json"
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.revision.execution.json"
    "${TASK_PARALLELISM_PROTOCOL}/candidate-base.gitignore"
    "${TASK_PARALLELISM_PROTOCOL}/scaffold/package-lock.json"
    "${TASK_PARALLELISM_PROTOCOL}/tasks/vector-siege.md"
    "${TASK_PARALLELISM_PROTOCOL}/tasks/vector-siege-stage-1-candidate.md"
    "${TASK_PARALLELISM_PROTOCOL}/prompts/arm-c-prompt-gated.md"
    "${TASK_PARALLELISM_RUNNER}/Makefile"
    "${TASK_PARALLELISM_RUNNER}/requirements.txt"
    "${TASK_PARALLELISM_RUNNER}/run-preflight.sh"
    "${TASK_PARALLELISM_RUNNER}/preflight_launcher.py"
    "${TASK_PARALLELISM_RUNNER}/preflight.py"
    "${TASK_PARALLELISM_RUNNER}/generate-placeholder-assets.py"
    "${TASK_PARALLELISM_RUNNER}/prepare-phase-0b.py"
    "${TASK_PARALLELISM_RUNNER}/diagnose-phase-0b.py"
    "${TASK_PARALLELISM_RUNNER}/run-phase-0b.py"
    "${TASK_PARALLELISM_RUNNER}/run-phase-0b-revision.py"
    "scripts/tests/task-parallelism-preflight.bats"
    "scripts/tests/task-parallelism-phase-0b.bats"
    "scripts/tests/task-parallelism-phase-0b-execution.bats"
    "scripts/tests/task-parallelism-phase-0b-revision-execution.bats"
  )

  phase_0c_manifest="${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/manifest.json"
  if [[ -f "${phase_0c_manifest}" ]]; then
    required+=(
      "${phase_0c_manifest}"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/manifest.schema.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-graph.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-graph.schema.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-gate-report.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-gate-report.schema.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/event.schema.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/ledger.schema.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-treatments.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-treatments.schema.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight.schema.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/canonical-event-fixture.schema.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/fixtures/canonical-payload-events.json"
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/prompts/preflight-fixture-shared.md"
      "${TASK_PARALLELISM_RUNNER}/requirements.in"
      "${TASK_PARALLELISM_RUNNER}/phase_0c_gate.py"
      "${TASK_PARALLELISM_RUNNER}/phase_0c_freeze.py"
      "${TASK_PARALLELISM_RUNNER}/phase_0c_transport.py"
      "${TASK_PARALLELISM_RUNNER}/phase_0c_a2a_server.py"
      "${TASK_PARALLELISM_RUNNER}/phase-0c-preflight.py"
      "scripts/tests/task-parallelism-phase-0c-gate.bats"
      "scripts/tests/task-parallelism-phase-0c-transport.bats"
    )
  fi

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
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.revision.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-preparation.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision-execution.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision-candidate-report.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision-candidate-result.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision-evaluator-result.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-revision-summary.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-diagnostic-summary.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/results/phase-0b-candidate-reports.json" \
    "${TASK_PARALLELISM_PROTOCOL}/results/phase-0b-diagnostic-summary.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-candidate-result.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-candidate-report.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-execution.schema.json" \
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.execution.json" \
    "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.revision.execution.json" \
    "${TASK_PARALLELISM_PROTOCOL}/phase-0b-pilot-summary.schema.json"; do
    if jq -e . "${path}" >/dev/null 2>&1; then
      pass "valid JSON: ${path}"
    else
      fail "invalid JSON: ${path}"
    fi
  done

  if [[ -f "${phase_0c_manifest}" ]]; then
    for path in \
      "${phase_0c_manifest}" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/manifest.schema.json" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-graph.json" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-graph.schema.json" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-gate-report.json" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-gate-report.schema.json" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/event.schema.json" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/ledger.schema.json" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-treatments.json" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight-fixture-treatments.schema.json" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/preflight.schema.json" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/canonical-event-fixture.schema.json" \
      "${TASK_PARALLELISM_PROTOCOL}/phase-0c-transport/fixtures/canonical-payload-events.json"; do
      if jq -e . "${path}" >/dev/null 2>&1; then
        pass "valid JSON: ${path}"
      else
        fail "invalid JSON: ${path}"
      fi
    done
  fi

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

  if PYTHONDONTWRITEBYTECODE=1 python3 "${TASK_PARALLELISM_RUNNER}/run-phase-0b.py" \
    --validate-state --offline >/dev/null; then
    pass "tracked Phase 0B structural execution state validates offline"
  else
    fail "tracked Phase 0B execution state is invalid"
  fi

  if PYTHONDONTWRITEBYTECODE=1 python3 "${TASK_PARALLELISM_RUNNER}/prepare-phase-0b.py" \
    --validate --manifest "${TASK_PARALLELISM_PROTOCOL}/campaign.phase-0b.revision.json" >/dev/null; then
    pass "revised Phase 0B two-assignment plan validates and remains blocked"
  else
    fail "revised Phase 0B two-assignment plan is invalid"
  fi

  if PYTHONDONTWRITEBYTECODE=1 python3 "${TASK_PARALLELISM_RUNNER}/diagnose-phase-0b.py" \
    --validate "${TASK_PARALLELISM_PROTOCOL}/results/phase-0b-diagnostic-summary.json" >/dev/null; then
    pass "retained Phase 0B branch diagnostics validate"
  else
    fail "retained Phase 0B branch diagnostics are invalid"
  fi

  if PYTHONDONTWRITEBYTECODE=1 python3 "${TASK_PARALLELISM_RUNNER}/run-phase-0b-revision.py" \
    --validate-state --offline >/dev/null; then
    pass "approved Phase 0B revision execution state validates offline"
  else
    fail "approved Phase 0B revision execution state is invalid"
  fi

  if [[ -f "${phase_0c_manifest}" ]]; then
    if PYTHONDONTWRITEBYTECODE=1 python3 "${TASK_PARALLELISM_RUNNER}/phase-0c-preflight.py" \
      --validate-only \
      --manifest "${phase_0c_manifest}" >/dev/null; then
      pass "frozen Phase 0C transport apparatus validates and remains blocked"
    else
      fail "frozen Phase 0C transport apparatus is invalid"
    fi
  fi

  echo ""
fi
