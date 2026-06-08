#!/usr/bin/env bash
# Run remaining Stage 1E CP-1 pack screen suites (issue #378).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

CLASS_A_BASE=6946d04b3fd17014e32d9da5ea947acf6df14360
CLASS_B_BASE=cff89bffe7e15e155bd740b6c7a0f158a6f2bad6
PACK_SCREEN_MANIFEST="${REPO_ROOT}/.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example"

run_suite() {
  local run_group="$1" task="$2" base="$3" variant="$4"
  echo "========== RUN_GROUP=${run_group} TASK=${task} VARIANT=${variant} =========="
  RUN_GROUP="${run_group}" \
    MANIFEST="${PACK_SCREEN_MANIFEST}" \
    make -C scripts/benchmark suite \
    TASK="${task}" \
    BASE="${base}" \
    STAGE=1 \
    CONTEXT_VARIANT="${variant}"
}

# Skip ctx-a-baseline if already completed
run_suite ctx-a-core-min opfit-281-class-a-premerge "${CLASS_A_BASE}" pack:core-min
run_suite ctx-a-class-a-process opfit-281-class-a-premerge "${CLASS_A_BASE}" pack:class-a-process
run_suite ctx-a-full-rules opfit-281-class-a-premerge "${CLASS_A_BASE}" full-rules-injected
run_suite ctx-b-baseline opfit-326-class-b-premerge "${CLASS_B_BASE}" baseline
run_suite ctx-b-core-min opfit-326-class-b-premerge "${CLASS_B_BASE}" pack:core-min
run_suite ctx-b-class-b-implementation opfit-326-class-b-premerge "${CLASS_B_BASE}" pack:class-b-implementation
run_suite ctx-b-full-rules opfit-326-class-b-premerge "${CLASS_B_BASE}" full-rules-injected

echo "========== CP-1 suites complete =========="
