# Prompt: Implement standardized model-ROI benchmark grading

You are implementing a repo-local benchmark grading standardization pass for `ai-repo-template`.

Target branch: `feature/op-374-model-roi-benchmark-phase-a`
Latest reviewed branch head before this prompt was written: `f08a8a743a427b650181af48d62f086cc92a194b`.

## Background

The model-ROI benchmark runner now supports Stage 1E targeted context-pack runs. The latest branch already includes:

- `RUN_GROUP` support in `scripts/benchmark/Makefile` and `scripts/benchmark/lib.sh`.
- `CONTEXT_VARIANT=pack:<pack-id>` support in `scripts/benchmark/lib.sh`.
- Context pack manifests under `.context/benchmarks/model-roi/context-packs/`.
- Stage 1E candidate manifest examples.
- Context pack manifest validation in `scripts/checks/167-context-pack-manifests.sh`.
- Four implementation/validation/run/result prompt files under `.github/prompts/01-*` through `.github/prompts/04-*`.

The problem to fix now is **grading variance**. Exploratory regrades by different agents/sessions produced materially different scores, including large Class B swings. Scores from different graders/sessions are not comparable unless the evaluation protocol is locked.

The goal is to turn benchmark grading into a deterministic, auditable, script-first workflow:

```text
candidate artifacts
  -> deterministic evidence collection
  -> objective grading script
  -> blinded subjective evidence bundle
  -> locked subjective grader prompt / schema
  -> validated subjective score import
  -> final score compilation
  -> grade-set comparison / inter-rater reliability report
```

Do **not** run paid benchmark candidates or paid model grading as part of this implementation unless explicitly instructed by a maintainer. Implement the apparatus, schemas, docs, and non-metered fixtures/tests.

## Critical issue to fix: context variant leakage in blind artifacts

Currently, `scripts/benchmark/run-candidate.sh` writes `context_variant` to `meta-blind.json`. That leaks whether the candidate was `baseline`, `pack:core-min`, `pack:class-b-implementation`, or `full-rules-injected`. For Stage 1E, this can bias graders.

You must revise the grading/blinding flow so grading bundles never reveal:

- platform
- model
- agent runtime
- real context variant
- context pack id
- descriptive run group names such as `ctx-a-core-min`
- prior scores
- previous grader comments

Keep real identities in sealed metadata only.

A minimal acceptable design is:

- `meta-blind.json` uses a neutral `context_condition` such as `cond-001` instead of `context_variant`.
- `meta-sealed.json` keeps `context_variant` and, for `pack:*`, the real pack id.
- A sealed map records `context_condition -> context_variant -> pack metadata` under the task/run group artifact root.
- Grading bundles use neutral `eval-###` IDs and do not include paths that reveal the run group or context variant.

If preserving backward compatibility is easier, you may leave historical `meta-blind.json` files alone and implement the no-leak guarantee in `prepare-grade-bundle.sh`, but future runs should stop leaking context variants in newly generated blind metadata.

## Required deliverables

### 1. Grading docs and schemas

Create this directory:

```text
.context/benchmarks/model-roi/grading/
```

Add at least:

```text
.context/benchmarks/model-roi/grading/README.md
.context/benchmarks/model-roi/grading/rubric.v1.json
.context/benchmarks/model-roi/grading/objective-grade.schema.json
.context/benchmarks/model-roi/grading/subjective-grade.schema.json
.context/benchmarks/model-roi/grading/final-grade.schema.json
.context/benchmarks/model-roi/grading/grade-set.schema.json
.context/benchmarks/model-roi/grading/tasks/opfit-281-class-a-premerge.json
.context/benchmarks/model-roi/grading/tasks/opfit-326-class-b-premerge.json
.context/benchmarks/model-roi/grading/calibration/README.md
.context/benchmarks/model-roi/grading/calibration/anchor-manifest.tsv.example
```

Use JSON for machine-readable specs to avoid adding a YAML dependency.

`README.md` must document:

- Scores are comparable only within the same `score_set_id`.
- A score set fixes rubric version, grading scripts, subjective prompt, subjective grader/harness, evidence bundle construction, and blinded-field policy.
- Exploratory regrades by another agent/model are separate score sets and may be used for inter-rater reliability only.
- Context variant and context pack identity are sealed until grading is locked.
- Practical tie-band policy: scores within 3 points are ties unless objective acceptance or ROI materially differs; scores within 5 points require ROI/variance review before changing routing policy.
- Adjudication triggers: score delta >= 8, rank winner changes, top two within 3 points, subjective claim conflicts with objective evidence, or subjective spread >= 10 across graders.

`rubric.v1.json` must encode the 100-point rubric:

- Correctness / acceptance: 30
- Code/doc quality: 25
- Repo-process adherence: 20
- Reliability / verification: 15
- Latency: 10

Split the first four into objective and subjective portions. Recommended starting point:

```text
Correctness: 20 objective + 10 subjective
Quality:     10 objective + 15 subjective
Process:     15 objective + 5 subjective
Reliability: 10 objective + 5 subjective
Latency:     10 objective only
```

Include scoring anchors for each category.

Task specs should be conservative. Do not invent acceptance checks that are not available. Use task-specific commands and path rules where the existing benchmark tasks make them clear; otherwise include placeholders with explicit `enabled: false` and instructions for maintainers to fill them before canonical grading.

### 2. Locked subjective grader prompts

Add these prompt files:

```text
.github/prompts/model-roi-grader-v1.md
.github/prompts/model-roi-pairwise-grader-v1.md
.github/prompts/model-roi-adjudicator-v1.md
```

`model-roi-grader-v1.md` must require JSON-only output matching `subjective-grade.schema.json`.

It must instruct the grader to:

- use only the blinded evidence bundle;
- ignore model, platform, context variant, context pack, alias family, prior scores, and outside knowledge;
- score only subjective residual points, not objective points;
- cite bundle evidence for every deduction or positive judgment;
- record uncertainty instead of guessing;
- fail closed when evidence is missing.

`model-roi-pairwise-grader-v1.md` should compare two blinded candidates and output structured JSON indicating which candidate is better on subjective residual quality and why. This is for future rank-stability work; it does not need full Elo/Bradley-Terry implementation in this PR.

`model-roi-adjudicator-v1.md` should resolve conflicts between two or more subjective grades using objective evidence and the rubric. It should not average blindly.

### 3. Benchmark grading scripts

Add these scripts under `scripts/benchmark/`:

```text
scripts/benchmark/prepare-grade-bundle.sh
scripts/benchmark/grade-objective.py
scripts/benchmark/render-subjective-grade-prompt.py
scripts/benchmark/record-subjective-grade.py
scripts/benchmark/compile-final-grades.py
scripts/benchmark/compare-grade-sets.py
scripts/benchmark/adjudicate-grades.py
```

All scripts must have `set -euo pipefail` if shell, or robust argparse/error handling if Python.

Use only standard library Python unless the repo already depends on something else. Do not require PyYAML.

#### `prepare-grade-bundle.sh`

Purpose: create blinded evidence bundles for all candidates in a task/stage/run group.

Required behavior:

- Inputs:
  - `--task <task-id>`
  - `--stage <stage>` default `1`
  - `--score-set <score_set_id>`
  - optional `--run-group <run_group>`
  - optional `--run-index <n>`
- Reads benchmark run artifacts from `scripts/benchmark/runs/...` using existing `RUN_GROUP` mechanics.
- Produces bundles under:

```text
scripts/benchmark/grade-bundles/<task>/<score_set_id>/eval-###/
```

Each bundle should include:

```text
candidate.md
meta-blind-sanitized.json
objective-input.json
files-changed.txt
diff.patch
verification/     # optional; created if objective checks run later
```

Sanitization rules:

- Do not include platform/model/agent.
- Do not include real `context_variant` or pack id.
- Do not include descriptive `RUN_GROUP` path segments.
- Do not include previous grade tables or prior scores.
- Use neutral `eval-###` IDs.
- Randomize or deterministic-shuffle row order using a score-set seed if practical; otherwise document deterministic order and keep row identity neutral.

Also produce sealed maps outside the bundle:

```text
scripts/benchmark/grade-bundles/<task>/<score_set_id>/sealed-eval-map.tsv
scripts/benchmark/grade-bundles/<task>/<score_set_id>/grade-set.json
```

`sealed-eval-map.tsv` should map `eval-###` to task, alias, run index, run group, context condition, real context variant, and artifact paths. It must be clearly labeled sealed.

`candidate.md` should include:

- task id and task class;
- candidate-safe task body from `.context/benchmarks/model-roi/tasks/<task>.md`;
- sanitized objective metadata;
- changed files;
- diff;
- objective check summary if available.

#### `grade-objective.py`

Purpose: assign deterministic objective points and collect evidence.

Required behavior:

- Inputs:
  - `--bundle <bundle-dir>` OR `--bundle-root <root>` to process all bundles
  - `--rubric .context/benchmarks/model-roi/grading/rubric.v1.json`
  - `--task-spec .context/benchmarks/model-roi/grading/tasks/<task>.json`
  - optional `--repo-root <path>` default current repo root
  - optional `--run-checks` to execute configured checks in a detached worktree
- Outputs `objective-grade.json` in each bundle.
- Validate output against `objective-grade.schema.json`.

Objective scoring should cover, where possible:

- hard gate: no diff / no work;
- task acceptance commands if enabled;
- changed-file scope / forbidden paths;
- artifact noise such as generated `.context/state`, local IDE state, stray `PLAN.md` if task spec says to penalize;
- required documentation/check artifacts where task-specific;
- verification evidence presence;
- latency score from sanitized metadata.

Do not overfit to one candidate. Keep scoring criteria encoded in rubric/task spec, not hard-coded per alias.

If a command cannot run because the environment lacks a tool, record a neutral `skipped` reason; do not silently pass it.

#### `render-subjective-grade-prompt.py`

Purpose: render the locked subjective grading prompt for a blinded bundle.

Inputs:

- `--bundle <bundle-dir>`
- `--prompt .github/prompts/model-roi-grader-v1.md`
- `--out <path>`

The output prompt should include the locked grader prompt plus the contents of `candidate.md` and `objective-grade.json`.

It must not include sealed maps.

#### `record-subjective-grade.py`

Purpose: validate and record a subjective judge response.

Inputs:

- `--bundle <bundle-dir>`
- `--response <json-file>`
- `--schema .context/benchmarks/model-roi/grading/subjective-grade.schema.json`
- `--grader-id <stable-id>`

Required behavior:

- Validate JSON shape.
- Check that scores are within the allowed subjective residual ranges from the rubric.
- Check that the `eval_candidate_id` matches the bundle.
- Write normalized output to:

```text
<bundle-dir>/subjective-grade.<grader-id>.json
```

Do not accept free-form markdown as a grade.

#### `compile-final-grades.py`

Purpose: combine objective and subjective grades into final candidate scores.

Inputs:

- `--bundle-root scripts/benchmark/grade-bundles/<task>/<score_set_id>`
- `--grader-id <id>` OR `--median-subjective` if multiple graders exist
- `--out final-grades.tsv`

Outputs:

```text
final-grades.tsv
final-grades.json
```

`final-grades.json` must validate against `final-grade.schema.json`.

Rules:

- Objective scores are authoritative for objective points.
- Subjective scores may only fill subjective residual points.
- Hard gate failures cap or zero scores according to task spec.
- Latency is objective only.
- If subjective grade is missing, mark final row incomplete; do not invent subjective points.

#### `compare-grade-sets.py`

Purpose: compare two grade sets for grading drift / inter-rater reliability.

Inputs:

- `--left <grade-set-root-or-final-grades.json>`
- `--right <grade-set-root-or-final-grades.json>`
- `--out <path>`

Outputs:

- paired score table by sealed candidate identity if both sets have compatible sealed maps;
- absolute score deltas;
- category deltas;
- rank deltas;
- top-1 agreement;
- top-2 overlap;
- Spearman rank correlation if straightforward to implement without dependencies;
- list of adjudication-required rows.

If sealed maps are absent, compare only by `eval_candidate_id` and clearly state limitations.

#### `adjudicate-grades.py`

Purpose: prepare adjudication packages and optionally normalize adjudicator responses.

Minimal acceptable implementation:

- detect rows requiring adjudication using thresholds from grading README;
- write an `adjudication-needed.tsv` file;
- render prompt packages using `.github/prompts/model-roi-adjudicator-v1.md`;
- validate adjudicator JSON if supplied.

### 4. Makefile integration

Add targets to `scripts/benchmark/Makefile`:

```text
grade-bundles
grade-objective
grade-subjective-prompts
grade-subjective-record
grade-compile
grade-compare
grade-adjudicate
```

Keep commands ergonomic and consistent with existing benchmark style.

Example target usage to document:

```bash
make -C scripts/benchmark grade-bundles \
  TASK=opfit-326-class-b-premerge \
  STAGE=1 \
  RUN_GROUP=<group> \
  SCORE_SET=stage-1e-context-packs-canonical-v1

make -C scripts/benchmark grade-objective \
  TASK=opfit-326-class-b-premerge \
  SCORE_SET=stage-1e-context-packs-canonical-v1

make -C scripts/benchmark grade-subjective-prompts \
  TASK=opfit-326-class-b-premerge \
  SCORE_SET=stage-1e-context-packs-canonical-v1

make -C scripts/benchmark grade-subjective-record \
  TASK=opfit-326-class-b-premerge \
  SCORE_SET=stage-1e-context-packs-canonical-v1 \
  EVAL_ID=eval-001 \
  GRADER_ID=codex-fixed \
  RESPONSE=/path/to/subjective-response.json

make -C scripts/benchmark grade-compile \
  TASK=opfit-326-class-b-premerge \
  SCORE_SET=stage-1e-context-packs-canonical-v1 \
  GRADER_ID=codex-fixed
```

### 5. Validation check

Add:

```text
scripts/checks/168-benchmark-grading.sh
```

It should be sourced by `test.sh` like other checks.

It must verify:

- grading directory exists;
- rubric and schemas are valid JSON;
- task grading specs are valid JSON;
- prompt files exist;
- scripts exist and pass syntax checks;
- a non-metered fixture can run:
  - create a fake bundle from a tiny synthetic diff or fixture artifacts;
  - run objective grading;
  - render subjective prompt;
  - validate a sample subjective response JSON;
  - compile final grades;
  - produce final JSON/TSV.

Do not require live model CLIs in `test.sh`.

Also ensure `scripts/checks/055-script-syntax.sh` covers any new shell scripts under `scripts/benchmark/` if it does not already.

### 6. Documentation updates

Update:

```text
.context/benchmarks/model-roi/README.md
.context/benchmarks/model-roi/benchmark-runbook.md
.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md
.github/prompts/README.md
AI_REPO_GUIDE.md
```

Docs must state:

- Stage 1E context-pack conclusions are not canonical until regraded under a single `score_set_id`.
- Existing Cursor/Codex exploratory regrades are separate score cohorts, not averaged canonical truth.
- Future benchmark conclusions must cite `score_set_id` and grading prompt/schema versions.
- Context pack identity is sealed during grading.
- Full-run ROI tables should separate benchmark execution cost from grading cost where grading LLMs are used.

### 7. Backward compatibility with current branch

The current branch has already implemented targeted context packs and Stage 1E scaffolding. Do not revert or redo that work.

Preserve:

- `RUN_GROUP` artifact grouping.
- `CONTEXT_VARIANT=pack:<pack-id>`.
- context pack manifests and validation.
- existing Stage 1C / 1D / 1E results docs.
- current Makefile run/suite/collect/unseal behavior unless you add compatible grading targets.

If you change `meta-blind.json` format for future runs, update schemas/docs and keep old-run handling tolerant where practical.

### 8. Acceptance criteria

Implementation is complete when:

- `./test.sh` passes.
- New grading check `168-benchmark-grading.sh` passes in non-metered mode.
- All new JSON schemas and sample outputs validate with `jq` and, where available, `check-jsonschema`.
- Running the fixture flow creates a grade bundle, objective grade, rendered subjective prompt, recorded sample subjective grade, final grades, and grade-set metadata.
- No grading bundle contains `context_variant`, `pack:`, known pack ids, platform/model names, or descriptive `RUN_GROUP` names.
- `meta-sealed.json` or sealed maps still retain enough data to unseal after grading is locked.
- Docs clearly explain score-set comparability and adjudication rules.
- No paid model calls are required by tests.

## Suggested implementation order

1. Add grading docs, rubric JSON, schemas, and task specs.
2. Add locked grader prompts.
3. Add bundle-preparation script with strict sanitization.
4. Add objective grader and fixture data.
5. Add subjective prompt rendering and subjective JSON recording.
6. Add final grade compilation.
7. Add grade-set comparison and adjudication scaffolding.
8. Add Makefile targets.
9. Add `168-benchmark-grading.sh` and wire it into test flow.
10. Update docs and prompt README.
11. Run `./test.sh`.

## Scope boundaries

Do not:

- rerun paid model candidates;
- decide the winner of Stage 1E;
- average current Cursor and Codex exploratory grades;
- rewrite unrelated PR review workflows;
- implement the post-merge retro-review system in this PR;
- change ADR model routing based on unstable grades;
- expose sealed model/context mappings in blind bundles.

Do:

- make grading reproducible;
- make score-set IDs first-class;
- make context-variant blinding safe;
- make objective scoring script-first;
- make subjective scoring schema-validated and prompt-locked;
- make grading variance visible instead of hidden.

## Final response expected from the implementing agent

When finished, report:

1. Files changed.
2. New grading workflow and commands.
3. How context-variant leakage is prevented.
4. What is objective-scored vs subjective-scored.
5. How to regrade Stage 1E under a canonical score set.
6. Validation commands run and results.
7. Any limitations or follow-up issues.
