# Model ROI benchmark grading

Standardized, auditable grading for model-ROI benchmark runs. Scores are comparable
**only within the same `score_set_id`**.

## Score set contract

A **score set** fixes:

| Locked element | Example |
|---|---|
| Rubric version | `rubric.v1.json` |
| Objective grading script | `scripts/benchmark/grade-objective.py` |
| Subjective grader prompt | `.github/prompts/model-roi-grader-v1.md` |
| Subjective response schema | `subjective-grade.schema.json` |
| Evidence bundle construction | `scripts/benchmark/prepare-grade-bundle.sh` |
| Blinded-field policy | No platform/model/context pack/run-group in bundles |

Exploratory regrades by another agent or model are **separate score sets**. Use them
for inter-rater reliability (`compare-grade-sets.py`), not as canonical truth averaged
into routing decisions.

## Workflow

```text
candidate artifacts (runs/<task>/…)
  → prepare-grade-bundle.sh
  → grade-objective.py
  → render-subjective-grade-prompt.py  (+ human/LLM grader)
  → record-subjective-grade.py
  → compile-final-grades.py
  → compare-grade-sets.py / adjudicate-grades.py (optional)
```

Artifacts live under:

```text
scripts/benchmark/grade-bundles/<task>/<score_set_id>/
  eval-001/
    candidate.md
    meta-blind-sanitized.json
    objective-input.json
    objective-grade.json
    subjective-grade.<grader-id>.json   # after recording
    files-changed.txt
    diff.patch
  sealed-eval-map.tsv                   # SEALED — not for graders
  grade-set.json
  final-grades.tsv / final-grades.json  # after compile
```

## Blinding policy

Grading bundles must **not** reveal:

- platform, model, or agent runtime
- real `context_variant` or context pack id (`pack:*`)
- descriptive `RUN_GROUP` names (e.g. `ctx-a-core-min`)
- prior scores or grader comments

Sealed maps (`sealed-eval-map.tsv`, `meta-sealed.json` on disk) retain enough data
to unseal after grading is locked.

Future runs write `context_condition` (e.g. `cond-001`) in blind metadata instead of
`context_variant`. Historical `meta-blind.json` files may still contain
`context_variant`; `prepare-grade-bundle.sh` sanitizes them.

## Objective vs subjective split (`rubric.v1.json`)

| Category | Total | Objective | Subjective |
|---|---:|---:|---:|
| Correctness / acceptance | 30 | 20 | 10 |
| Code / doc quality | 25 | 10 | 15 |
| Repo-process adherence | 20 | 15 | 5 |
| Reliability / verification | 15 | 10 | 5 |
| Latency | 10 | 10 | 0 |

Objective points are authoritative. Subjective graders fill **only** subjective
residual points and must cite bundle evidence.

## Tie-band and adjudication

**Tie band:** scores within **3 points** are ties unless objective acceptance or ROI
materially differs.

**ROI review:** scores within **5 points** require ROI/variance review before
changing routing policy.

**Adjudication triggers** (see `adjudicate-grades.py`):

- absolute score delta ≥ 8 between score sets for the same candidate
- rank winner changes between score sets
- top two within 3 points with different ROI ordering
- subjective claim conflicts with objective evidence
- subjective spread ≥ 10 across graders on the same bundle

## Pipeline rubric (`rubric.pipeline.v1.json`)

Issue #376 pipeline score sets use a six-category rubric (includes **coordination**
/10 subjective). Task specs:
`grading/tasks/opfit-*-premerge-pipeline.json`. Subjective graders must set
`rubric_id: rubric.pipeline.v1` and score the coordination category.

## Regrading extended stages (1C / 1D / pipeline / 1E)

| Stage | Operator script | Results sync |
|---|---|---|
| 1 / 1c / 1d / pipeline | `regrade-stage.sh <stage> {prepare\|grade\|record\|compile}` | `update-benchmark-results.py all` |
| 1E CP-1 | `regrade-stage-1e.sh` | (included in `all`) |

Shared libraries: `canonical_scores_lib.py`, `regrade_results_lib.py`,
`roi_format_lib.py`, `results_table_sort.py`. Thin wrappers (`regrade-stage-1c.sh`,
etc.) exec `regrade-stage.sh`. Per-stage ROI modules remain importable; prefer
`update-benchmark-results.py scores|roi|sort|all`.

Marginal ROI lookup uses `lookup_marginal_score(task_class, alias)`; pipeline
table sync uses `lookup_pipeline_score(task_class, alias, run)` so Class A and
Class B rows for the same alias (e.g. `cand-05-pipe` at `r2`) do not collide.

## Regrading Stage 1E under a canonical score set

**Recommended:** `scripts/benchmark/regrade-stage-1e.sh` (documented in
[`benchmark-runbook.md`](../benchmark-runbook.md) § "Regrade Stage 1E (CP-1)").

```bash
./scripts/benchmark/regrade-stage-1e.sh prepare
./scripts/benchmark/regrade-stage-1e.sh record <grader-id> ./stage-1e-responses
./scripts/benchmark/regrade-stage-1e.sh compile <grader-id>
```

Manual per-`RUN_GROUP` alternative:

1. Pick a `score_set_id` per group: `stage-1e-canonical-v1-<run_group>`.
2. `grade-bundles` → `grade-objective` → `grade-subjective-prompts` with `RUN_GROUP` set.
3. Record subjective JSON grades and `grade-compile` with the same `GRADER_ID`.
4. Cite `score_set_id`, rubric version, and grader prompt version in results docs.
5. Do **not** average exploratory Cursor/Codex regrades into the canonical row.

## True LLM blind grading (Stage 1 / 1C / 1D / pipeline)

Heuristic `blind_grade_heuristic.py` is **not** the canonical procedure. Use the
Cursor agent in ask mode to grade each bundle's `subjective-prompt.md` with the
locked `model-roi-grader-v1` prompt:

```bash
# Per bundle
python3 scripts/benchmark/llm_grade_subjective.py \
  --bundle scripts/benchmark/grade-bundles/<task>/<score-set>/eval-NNN \
  --grader-id cursor-llm-blind-v1 \
  --out scripts/benchmark/stage-llm-responses-v1/<task>/eval-NNN.json

# Batch (stage 1 | 1c | 1d | pipeline)
./scripts/benchmark/regrade-stage.sh 1 grade cursor-llm-blind-v1   # → stage-1-llm-responses-v1/
./scripts/benchmark/regrade-stage.sh 1c grade cursor-llm-blind-v1
./scripts/benchmark/regrade-stage.sh 1c record cursor-llm-blind-v1 scripts/benchmark/stage-llm-responses-v1
bash ./scripts/benchmark/regrade-stage.sh 1c compile cursor-llm-blind-v1
python3 scripts/benchmark/update-benchmark-results.py all
```

`--heuristic` on `blind_grade_bundle.py` retains the offline evidence scorer for
fixtures only.

## Cost accounting

Separate **benchmark execution cost** (candidate run telemetry) from **grading cost**
(subjective LLM grader invocations). ROI tables should label which cost bucket each
USD figure belongs to.

## Calibration

See [`calibration/README.md`](./calibration/README.md) for anchor-run manifests used
to validate graders before trusting a new score set.
