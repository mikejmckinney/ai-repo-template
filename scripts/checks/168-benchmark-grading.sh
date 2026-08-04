#!/usr/bin/env bash
# scripts/checks/168-benchmark-grading.sh — non-metered benchmark grading pipeline smoke.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking benchmark grading apparatus..."

  GRADING_DIR=".context/benchmarks/model-roi/grading"
  RUNNER="scripts/benchmark"
  FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bench-grade-smoke.XXXXXX")"
  trap 'rm -rf "${FIXTURE_ROOT}"' EXIT

  required=(
    "${GRADING_DIR}/README.md"
    "${GRADING_DIR}/rubric.v1.json"
    "${GRADING_DIR}/objective-grade.schema.json"
    "${GRADING_DIR}/subjective-grade.schema.json"
    "${GRADING_DIR}/final-grade.schema.json"
    "${GRADING_DIR}/grade-set.schema.json"
    "${GRADING_DIR}/tasks/opfit-281-class-a-premerge.json"
    "${GRADING_DIR}/tasks/opfit-326-class-b-premerge.json"
    ".github/prompts/model-roi-grader-v1.md"
    ".github/prompts/model-roi-pairwise-grader-v1.md"
    ".github/prompts/model-roi-adjudicator-v1.md"
    "${RUNNER}/prepare-grade-bundle.sh"
    "${RUNNER}/grade-objective.py"
    "${RUNNER}/render-subjective-grade-prompt.py"
    "${RUNNER}/record-subjective-grade.py"
    "${RUNNER}/compile-final-grades.py"
    "${RUNNER}/compare-grade-sets.py"
    "${RUNNER}/adjudicate-grades.py"
    "${RUNNER}/grading_lib.py"
  )
  canonical_results_consumers=(
    "${RUNNER}/regrade-stage-lib.sh"
    "${RUNNER}/regrade_results_lib.py"
    "${RUNNER}/update-all-benchmark-roi.py"
    "${RUNNER}/update-benchmark-results.py"
    "${RUNNER}/update-results-canonical-scores.py"
    "${RUNNER}/update-stage-1-pipeline-roi.py"
    "${RUNNER}/update-stage-1-roi.py"
    "${RUNNER}/update-stage-1c-roi.py"
    "${RUNNER}/update-stage-1d-roi.py"
    "${RUNNER}/update-stage-1e-roi.py"
  )

  for f in "${required[@]}"; do
    if [[ -f "${f}" ]]; then
      pass "${f} exists"
    else
      fail "${f} is missing"
    fi
  done

  for path in "${canonical_results_consumers[@]}"; do
    if grep -Fq 'docs/benchmarks/agent-roi-benchmark-results.md' "${path}"; then
      pass "${path} targets the canonical benchmark results"
    else
      fail "${path} targets a retired benchmark results path"
    fi
  done

  if command -v jq >/dev/null 2>&1; then
    for j in "${GRADING_DIR}"/*.json "${GRADING_DIR}"/tasks/*.json; do
      [[ -f "${j}" ]] || continue
      if jq -e . "${j}" >/dev/null 2>&1; then
        pass "valid JSON: ${j}"
      else
        fail "invalid JSON: ${j}"
      fi
    done
  else
    warn "jq not available; skipping JSON validation"
  fi

  if bash -n "${RUNNER}/prepare-grade-bundle.sh" 2>/dev/null; then
    pass "bash -n ${RUNNER}/prepare-grade-bundle.sh"
  else
    fail "bash -n ${RUNNER}/prepare-grade-bundle.sh"
  fi

  for py in "${RUNNER}"/grade-objective.py "${RUNNER}"/grading_lib.py; do
    if python3 -m py_compile "${py}" 2>/dev/null; then
      pass "py_compile ${py}"
    else
      fail "py_compile ${py}"
    fi
  done

  # Synthetic bundle fixture (no paid model / no live benchmark runs)
  BUNDLE="${FIXTURE_ROOT}/eval-001"
  mkdir -p "${BUNDLE}/verification"
  cat >"${BUNDLE}/meta-blind-sanitized.json" <<'EOF'
{
  "eval_candidate_id": "eval-001",
  "task_id": "opfit-281-class-a-premerge",
  "stage": "1",
  "context_condition": "cond-001",
  "base_sha": "0000000000000000000000000000000000000000",
  "wall_clock_seconds": 120,
  "adapter_exit_code": 0,
  "diff_files_changed": 1,
  "work_produced": true
}
EOF

  cat >"${BUNDLE}/objective-input.json" <<'EOF'
{
  "score_set_id": "fixture-smoke-v1",
  "eval_candidate_id": "eval-001",
  "task_id": "opfit-281-class-a-premerge",
  "context_condition": "cond-001"
}
EOF

  cat >"${BUNDLE}/files-changed.txt" <<'EOF'
scripts/checks/055-script-syntax.sh
EOF

  cat >"${BUNDLE}/diff.patch" <<'EOF'
diff --git a/scripts/checks/055-script-syntax.sh b/scripts/checks/055-script-syntax.sh
index 1111111..2222222 100644
--- a/scripts/checks/055-script-syntax.sh
+++ b/scripts/checks/055-script-syntax.sh
@@ -28,6 +28,7 @@ SYNTAX_CHECK_GLOBS=(
   scripts/*.sh
   scripts/checks/*.sh
   scripts/setup/*.sh
+  scripts/benchmark/*.sh
   scripts/lib/*.sh
 )
EOF

  printf '# Fixture candidate\n\nSee diff.\n' >"${BUNDLE}/candidate.md"

  if python3 "${RUNNER}/grade-objective.py" --bundle "${BUNDLE}"; then
    pass "grade-objective.py on fixture bundle"
  else
    fail "grade-objective.py on fixture bundle"
  fi

  PROMPT_OUT="${FIXTURE_ROOT}/subjective-prompt.md"
  if python3 "${RUNNER}/render-subjective-grade-prompt.py" \
    --bundle "${BUNDLE}" --out "${PROMPT_OUT}"; then
    pass "render-subjective-grade-prompt.py"
  else
    fail "render-subjective-grade-prompt.py"
  fi

  cat >"${FIXTURE_ROOT}/subjective-response.json" <<'EOF'
{
  "schema_version": "benchmark-subjective-grade.v1",
  "score_set_id": "fixture-smoke-v1",
  "eval_candidate_id": "eval-001",
  "grader_id": "fixture-grader",
  "grader_prompt_id": "model-roi-grader-v1",
  "rubric_id": "rubric.v1",
  "categories": {
    "correctness": {"subjective_points": 8, "max_subjective_points": 10, "rationale": "Fixture diff matches task.", "uncertain": false},
    "quality": {"subjective_points": 12, "max_subjective_points": 15, "rationale": "Clear change.", "uncertain": false},
    "process": {"subjective_points": 4, "max_subjective_points": 5, "rationale": "Focused diff.", "uncertain": false},
    "reliability": {"subjective_points": 4, "max_subjective_points": 5, "rationale": "Check module present.", "uncertain": false}
  },
  "subjective_total": 28,
  "uncertainty_notes": [],
  "citations": [{"bundle_ref": "diff.patch", "claim": "Expands SYNTAX_CHECK_GLOBS"}],
  "graded_at": "2026-06-06T00:00:00Z"
}
EOF

  if python3 "${RUNNER}/record-subjective-grade.py" \
    --bundle "${BUNDLE}" \
    --response "${FIXTURE_ROOT}/subjective-response.json" \
    --grader-id fixture-grader; then
    pass "record-subjective-grade.py"
  else
    fail "record-subjective-grade.py"
  fi

  ROOT="${FIXTURE_ROOT}/grade-set-root"
  mkdir -p "${ROOT}"
  cp -a "${BUNDLE}" "${ROOT}/eval-001"
  if python3 "${RUNNER}/compile-final-grades.py" \
    --bundle-root "${ROOT}" --grader-id fixture-grader; then
    pass "compile-final-grades.py"
  else
    fail "compile-final-grades.py"
  fi

  if [[ -f "${ROOT}/final-grades.json" && -f "${ROOT}/final-grades.tsv" ]]; then
    pass "final-grades.json and final-grades.tsv produced"
  else
    fail "final grade outputs missing"
  fi

  if ! grep -q 'context_variant' "${BUNDLE}/candidate.md" 2>/dev/null \
    && ! grep -q 'pack:' "${BUNDLE}/meta-blind-sanitized.json" 2>/dev/null; then
    pass "fixture bundle has no context_variant / pack leakage"
  else
    fail "fixture bundle leaks context variant"
  fi

  echo ""
fi
