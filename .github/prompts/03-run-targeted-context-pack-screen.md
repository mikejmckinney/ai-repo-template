# Run targeted context-pack benchmark screen

## Role and objective

You are the benchmark operator. Run the targeted context-pack benchmark after implementation support has landed.

Do not modify production routing. Do not merge candidate branches into `main`. Do not unseal aliases before blind scoring is locked.

## Required startup

1. Read `AGENTS.md`.
2. Read `.context/benchmarks/model-roi/README.md`.
3. Read `.context/benchmarks/model-roi/benchmark-runbook.md`.
4. Read `.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md`.
5. Read the targeted context-pack docs added by the implementation PR.
6. Run the benchmark `doctor` gate before spending.

## Base SHAs

Use the historical bases unless the benchmark plan explicitly chooses new bases:

```bash
CLASS_A_BASE=6946d04b3fd17014e32d9da5ea947acf6df14360
CLASS_B_BASE=cff89bffe7e15e155bd740b6c7a0f158a6f2bad6
```

If these SHAs are not present locally, fetch the benchmark base branches documented in the runbook.

## Stage CP-1: pack screen

Use the pack screen manifest:

```bash
PACK_SCREEN_MANIFEST="$PWD/.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example"
```

Candidate set should be:

```text
ctx-cur  = cursor / composer-2.5
ctx-gem  = gemini-cli / gemini-3.5-flash requested, observed backend recorded by adapter
```

### Class A runs

Run:

```bash
RUN_GROUP=ctx-a-baseline \
MANIFEST="$PACK_SCREEN_MANIFEST" \
make -C scripts/benchmark suite \
  TASK=opfit-281-class-a-premerge \
  BASE="$CLASS_A_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=baseline
```

```bash
RUN_GROUP=ctx-a-core-min \
MANIFEST="$PACK_SCREEN_MANIFEST" \
make -C scripts/benchmark suite \
  TASK=opfit-281-class-a-premerge \
  BASE="$CLASS_A_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=pack:core-min
```

```bash
RUN_GROUP=ctx-a-class-a-process \
MANIFEST="$PACK_SCREEN_MANIFEST" \
make -C scripts/benchmark suite \
  TASK=opfit-281-class-a-premerge \
  BASE="$CLASS_A_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=pack:class-a-process
```

```bash
RUN_GROUP=ctx-a-full-rules \
MANIFEST="$PACK_SCREEN_MANIFEST" \
make -C scripts/benchmark suite \
  TASK=opfit-281-class-a-premerge \
  BASE="$CLASS_A_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=full-rules-injected
```

### Class B runs

Run:

```bash
RUN_GROUP=ctx-b-baseline \
MANIFEST="$PACK_SCREEN_MANIFEST" \
make -C scripts/benchmark suite \
  TASK=opfit-326-class-b-premerge \
  BASE="$CLASS_B_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=baseline
```

```bash
RUN_GROUP=ctx-b-core-min \
MANIFEST="$PACK_SCREEN_MANIFEST" \
make -C scripts/benchmark suite \
  TASK=opfit-326-class-b-premerge \
  BASE="$CLASS_B_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=pack:core-min
```

```bash
RUN_GROUP=ctx-b-class-b-implementation \
MANIFEST="$PACK_SCREEN_MANIFEST" \
make -C scripts/benchmark suite \
  TASK=opfit-326-class-b-premerge \
  BASE="$CLASS_B_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=pack:class-b-implementation
```

```bash
RUN_GROUP=ctx-b-full-rules \
MANIFEST="$PACK_SCREEN_MANIFEST" \
make -C scripts/benchmark suite \
  TASK=opfit-326-class-b-premerge \
  BASE="$CLASS_B_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=full-rules-injected
```

## Collect blind grading sheets

Collect each run group.

Examples:

```bash
RUN_GROUP=ctx-a-core-min \
make -C scripts/benchmark collect \
  TASK=opfit-281-class-a-premerge \
  STAGE=1
```

```bash
RUN_GROUP=ctx-b-class-b-implementation \
make -C scripts/benchmark collect \
  TASK=opfit-326-class-b-premerge \
  STAGE=1
```

Repeat for each group.

Do not unseal yet.

## Blind scoring

Score each diff using the existing 100-point rubric:

```text
Correctness / acceptance: 30
Code and doc quality: 25
Repo-process adherence: 20
Reliability / verification: 15
Latency: 10
```

For targeted context packs, also record:

```text
context_pack_id
context_pack_files
context_pack_bytes
context_pack_sha256
score_delta_vs_baseline
cost_delta_vs_baseline
roi_delta_vs_baseline
scope_noise
process_misses
```

## Unseal only after scores are locked

After blind scores are locked:

```bash
RUN_GROUP=<group> \
make -C scripts/benchmark unseal \
  TASK=<task> \
  STAGE=1
```

## Stage CP-2: robustness check

After CP-1 identifies the top two packs per task class, run the robustness manifest:

```bash
ROBUSTNESS_MANIFEST="$PWD/.context/benchmarks/model-roi/stage-1e-pack-robustness-candidates.tsv.example"
```

Run the top Class A pack:

```bash
RUN_GROUP=ctx-a-robust-<pack-id> \
MANIFEST="$ROBUSTNESS_MANIFEST" \
make -C scripts/benchmark suite \
  TASK=opfit-281-class-a-premerge \
  BASE="$CLASS_A_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=pack:<pack-id>
```

Run the top Class B pack:

```bash
RUN_GROUP=ctx-b-robust-<pack-id> \
MANIFEST="$ROBUSTNESS_MANIFEST" \
make -C scripts/benchmark suite \
  TASK=opfit-326-class-b-premerge \
  BASE="$CLASS_B_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=pack:<pack-id>
```

Robustness candidates:

```text
cursor auto
gemini auto
claude-code haiku
copilot auto
```

## Sweet-spot decision rule

Recommend a pack only if it satisfies:

```text
sweet_spot_pack =
  highest marginal ROI pack
  with score >= best_score_for_task_class - 2
  and no model-specific degradation > 3 points
  and lower injected bytes/tokens than full-rules injection
```

If no pack meets this threshold, recommend `baseline-lazy` plus targeted manual reads instead of automatic injection.
