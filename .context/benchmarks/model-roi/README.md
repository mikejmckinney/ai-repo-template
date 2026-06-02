# Model ROI Benchmark Protocol

> Durable protocol surface for the model ROI benchmark tracked in issue `#374`.
> The benchmark-specific prompt lives at `.github/prompts/model-roi-benchmark-candidate.md`.
> The current execution direction lives under `scripts/benchmark/`.

## Status

- **Scope now:** Phase A / Core Stage 1 only
- **Stage 1 effort policy:** target `medium`; Cursor is `medium (requested)`
- **Deferred:** extended Stage 1 harness-effect rows, all Stage 2 sweeps, and any ADR-019 routing changes
- **Manual fallback:** allowed after a documented headless failure via `make worktree` followed by `make record`

## Companion surfaces

| Path | Purpose |
|---|---|
| `.github/prompts/model-roi-benchmark-candidate.md` | Canonical prompt body reused unchanged across candidates. Candidate-specific input is limited to the run-metadata block and injected task. |
| `scripts/benchmark/Makefile` | Current operator entrypoint for `base`, `run`, `suite`, `worktree`, `record`, `collect`, and `unseal`. |
| `scripts/benchmark/candidates.tsv.example` | Example sealed alias manifest for Core Stage 1 plus later-phase placeholders. |
| `.context/benchmarks/model-roi/result-template.md` | Per-alias run record with blind-safe and sealed sections. |
| `.context/benchmarks/model-roi/summary-template.md` | Task-level Stage 1 summary and shortlist template. |

## Phase A contract

Phase A exists to produce a **blind, auditable Core Stage 1 screen** from a frozen base branch and a single prompt body shared across aliased candidates.

Required behavior:

1. Reuse the same prompt body for every candidate run.
2. Keep candidate branches and grader-facing artifacts aliased.
3. Run only **Core Stage 1** in this phase.
4. Keep Stage 1 effort fixed at `medium` where the harness can set it; Cursor remains `medium (requested)`.
5. Record manual fallback explicitly when a bundled adapter fails headlessly.
6. Defer Stage 2 and any model-routing remap decision to Phase B / Plan v2.

## Execution reality

The local `scripts/benchmark/` runner is now the committed Phase A execution base. It includes the approved Stage 1 guardrails, while full paid benchmark execution and later-phase sweeps remain intentionally out of scope for this rollout.

| Protocol requirement | Prototype status in this worktree | Notes |
|---|---|---|
| Canonical candidate prompt at `.github/prompts/model-roi-benchmark-candidate.md` | Present | `scripts/benchmark/lib.sh` points at this path. |
| Core Stage 1 operator flow (`base`, `run`, `suite`, `worktree`, `record`, `collect`, `unseal`) | Present | Driven by `scripts/benchmark/Makefile` and companion scripts. |
| Real pre-spend `doctor` gate | Present | `make doctor` checks prompt/manifest/base, per-harness binaries, auth heuristics, writable dirs, and remote readiness before spend. |
| Hard refusal to widen Phase A when `STAGE=1` is omitted | Present | `make suite` / `run-suite.sh` fail fast unless Stage 1 is selected explicitly. |
| Completeness enforcement for every Core Stage 1 alias terminal state | Present | `run-suite.sh` records the executed alias set; `collect` / `unseal` require exactly one terminal result per recorded alias. |
| Blind vs. sealed artifact split | Present | Model identity and detailed effort metadata stay sealed; blind surfaces expose only alias-safe operational facts. |
| Documented manual fallback after headless failure | Present | Use `make worktree` and `make record`; never count this as silent automated success. |

## Current operator flow

The commands below reflect the current Phase A operator flow.

1. Create the sealed manifest by copying `scripts/benchmark/candidates.tsv.example` to `scripts/benchmark/candidates.tsv`, then edit only the sealed mapping.
2. Freeze the benchmark base:

   ```bash
   make -C scripts/benchmark base TASK=<task-id>
   ```

3. Run the Core Stage 1 suite:

   ```bash
   make -C scripts/benchmark suite TASK=<task-id> BASE=<base-sha> STAGE=1
   ```

4. Run one alias in isolation when needed:

   ```bash
   make -C scripts/benchmark run TASK=<task-id> BASE=<base-sha> ALIAS=<cand-NN>
   ```

5. If a bundled adapter fails headlessly and the benchmark owner approves manual capture, keep the aliased worktree and record the run explicitly:

   ```bash
   make -C scripts/benchmark worktree TASK=<task-id> BASE=<base-sha> ALIAS=<cand-NN>
   make -C scripts/benchmark record TASK=<task-id> BASE=<base-sha> ALIAS=<cand-NN> RC=<rc>
   ```

6. Build the blind grading sheet only after every Core Stage 1 alias reaches a terminal state:

   ```bash
   make -C scripts/benchmark collect TASK=<task-id>
   ```

7. Reveal alias identity only after grading is locked:

   ```bash
   make -C scripts/benchmark unseal TASK=<task-id>
   ```

## Artifact model

The benchmark keeps **grader-facing** and **sealed** artifacts separate.

### Sealed inputs

- `scripts/benchmark/candidates.tsv` — alias→platform/model/agent manifest

### Per-run artifacts

Each run writes under:

```text
scripts/benchmark/runs/<task-id>/<alias>/r<run-index>/
```

Expected artifacts:

- `diff.patch` — candidate diff against the frozen base
- `meta-blind.json` — alias, timing, git facts, and other grader-safe metadata
- `meta-sealed.json` — platform/model/agent identity and sealed metadata
- `agent-output.jsonl` — raw machine-readable agent output
- `logs/` — adapter stderr and runtime logs

### Task-level artifacts

- `scripts/benchmark/runs/<task-id>/grading-sheet-blind.tsv` — blind grading sheet
- `scripts/benchmark/runs/<task-id>/unsealed-map.tsv` — post-lock alias reveal

Detailed effort controls belong in sealed records only. Blind artifacts should not expose model identity or detailed effort metadata.

## Core Stage 1 terminal states

Every Core Stage 1 alias in the recorded suite alias set must end in **exactly one** audited terminal state before blind collection or unseal:

- `graded`
- `blocked`
- `manual-capture-approved`

The runner now enforces this automatically at collect/unseal time; the templates remain the human-readable audit surface.

## Templates

- Use [`result-template.md`](./result-template.md) once per alias/run.
- Use [`summary-template.md`](./summary-template.md) once per task after every Core Stage 1 alias reaches a terminal state.
- If the docs and the runner ever disagree, follow the higher-priority source for the current task and note the mismatch in the summary instead of guessing.
