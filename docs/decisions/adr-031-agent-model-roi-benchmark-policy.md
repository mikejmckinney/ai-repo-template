# ADR-031: Agent/model ROI benchmark procedure and current recommendations

## Status

Proposed

## Date

2026-06-15

## Context

Issue [#374](https://github.com/mikejmckinney/ai-repo-template/issues/374) and follow-ons ([#376](https://github.com/mikejmckinney/ai-repo-template/issues/376), [#378](https://github.com/mikejmckinney/ai-repo-template/issues/378)) produced a reproducible **model ROI benchmark harness** on `main` (Phase A merged in PR [#379](https://github.com/mikejmckinney/ai-repo-template/pull/379)). Scored results live in [`.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md`](../../.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md).

Until this ADR, benchmark **procedure** and **actionable recommendations** were scattered across:

- `.context/benchmarks/model-roi/README.md` and `benchmark-runbook.md` (operator protocol)
- Issue comments and prompt pack notes (ad hoc guidance)
- Partial pointers in [ADR-019](./adr-019-per-role-model-tiering.md) (tier policy deferred pending benchmark refresh)

Operators and agents need a single durable **policy surface** for:

1. How to run and extend benchmarks (without re-deriving protocol from issues).
2. What the completed Class A / Class B evidence supports **today** for model, context, and orchestration choices.
3. What is **still missing** (Class C greenfield) and when to re-run.

Benchmark evidence is **not static**. Platforms rename models, pricing changes, agent runtimes change tool behavior, and repo process (`AGENTS.md`, context packs, subagent dispatch) evolves. Recommendations here are **current as of the cited score sets** and must be revisited when those inputs change materially.

## Decision

### 1. Canonical benchmark procedure

We treat the following as the **single operator contract** for agent/model ROI benchmarks in this repo:

| Surface | Role |
|---|---|
| [`.context/benchmarks/model-roi/README.md`](../../.context/benchmarks/model-roi/README.md) | Protocol, artifact model, task classes, stage definitions |
| [`.context/benchmarks/model-roi/benchmark-runbook.md`](../../.context/benchmarks/model-roi/benchmark-runbook.md) | Repeatable setup, run, grade, telemetry, known issues |
| [`.context/benchmarks/model-roi/grading/`](../../.context/benchmarks/model-roi/grading/) | Rubrics, schemas, score-set comparability rules |
| [`scripts/benchmark/`](../../scripts/benchmark/) | Harness entrypoints (`make doctor`, `base`, `run`, `suite`, `regrade-stage.sh`, etc.) |
| [`.github/prompts/model-roi-benchmark-candidate.md`](../../.github/prompts/model-roi-benchmark-candidate.md) | Shared candidate prompt body (task injected per run) |
| [`.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md`](../../.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md) | Scored record and ROI tables (operator source of truth on `main`) |

**Primary ranking metric:** **marginal ROI** = canonical weighted score ÷ marginal cost USD (token telemetry × public rate card where available). Amortized/subscription ROI is secondary unless explicitly scoped.

**Task classes (Phase A completed unless noted):**

| Class | Description | Committed tasks | Status |
|---|---|---|---|
| **A** | Operational fit — small/medium repo-process implementation | `opfit-281-class-a` (+ pipeline variant) | Benchmarked (Stage 1, 1C, 1D, 1E, #376 pipeline) |
| **B** | Reasoning / code — harder implementation | `opfit-326-class-b` (+ pipeline variant) | Benchmarked (same stages) |
| **C** | Greenfield app / framework comparison | Planned in `.github/prompts/06-implement-class-c-framework-benchmark.md` | **Not yet run** — required for a complete picture |

**Blind / sealed discipline:** alias manifests, frozen bases, blind grading before unseal, and `score_set_id` citation for canonical conclusions (see grading README).

**Read profile:** agents changing benchmark protocol, scoring, adapters, or results must use the `benchmark` profile in [`.context/rules/README.md`](../../.context/rules/README.md).

### 2. Current recommendations (Phase A evidence)

These recommendations apply to **routine repo implementation and non-blocking review automation** unless a task explicitly requires multi-role coordination quality as the primary goal.

#### 2a. Default execution shape: monolithic over multi-role pipeline

Issue #376 tested repo-native **orchestration pipelines** (subagents + handoffs) against completed monolithic Stage 1 baselines on the same Class A/B tasks.

**Finding:** No favorable ROI crossover was observed. Monolithic Cursor Auto / Composer-style runs and strong Gemini Flash rows remain the better default direction; pipeline runs were generally slower, often costlier, and did not materially improve quality on simple Class A work ([`agent-roi-benchmark-results.md` § Issue #376](../../.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md)).

**Policy:**

- **Prefer a single implementing agent** (monolithic pass) for routine issue/PR implementation, retro fix passes, and weekly fix passes.
- **Do not default to subagent fan-out** for ROI reasons alone. Use role dispatch when ownership, gates, or explicit multi-perspective review require it — not as the default implementation shape.
- **Stage 1D duo** (planner + implementer) did not beat the best monolithic ROI leaders on either class; treat duo as experimental, not default.

This aligns with [ADR-019 Amendment guidance](./adr-019-per-role-model-tiering.md) and [`.context/rules/process_model_tier.md`](../../.context/rules/process_model_tier.md) (ghost-success / pass-back caveats for dispatched subagents).

#### 2b. Model / platform shortlist (where telemetry exists)

For **implementation-shaped** work (Classes A/B), Phase A marginal ROI and canonical scores support:

| Tier | Candidates | Notes |
|---|---|---|
| **First choice (implementation)** | Cursor **Composer 2.5**, Gemini **Flash** (requested `gemini-3.5-flash` → observed `gemini-3-flash-preview` backend in harness), Cursor **Auto** | Strong score/ROI on both classes when telemetry captured |
| **Use with care** | Copilot **Auto** (routed model varies), Codex default | Useful rows exist; verify routed model and partial-run caveats |
| **Escalation / gates** | High-tier models per ADR-019 (Opus-class, GPT-5.4 xhigh on Copilot parent for reasoning-heavy parent sessions) | Not default for routine implementation; use for plan-gate, diff-gate, architecture, hard review resolution |

Advisory/retro **CI defaults** (`gemini-3.5-flash`, `composer-2.5` with `fast=false` for SDK paths) remain governed by [ADR-030](./adr-030-non-blocking-review-pipeline.md) and workflow vars — this ADR informs those choices but does not replace per-workflow env documentation.

#### 2c. Context loading (Stage 1C / 1E)

**Do not** inject full `.context/rules/*.md` by default. Full-rule injection rarely improved ROI for already-strong models and often increased cost.

**Stage 1E targeted packs (benchmark evidence only — production routing still requires explicit policy PR):**

| Work shape | Recommendation |
|---|---|
| **Class A** (process/doc-heavy small changes) | **Baseline lazy loading** default; optional `pack:class-a-process` for Cursor when process/doc-sync reminders help (accept small score tradeoffs) |
| **Class B** (code/reasoning-heavy) | **`pack:core-min`** when baseline lazy under-delivers; avoid `full-rules-injected` as default |

Sweet-spot rule (from benchmark README): highest marginal ROI pack within **−2** canonical points of the class best, no **>3** point model-specific degradation, fewer bytes than full-rules injection.

**Caveat:** Stage 1E CP-1 used frozen bases with older `AGENTS.md` versions (v14/v20). Re-benchmark before changing production context-loading policy on current `AGENTS.md`.

#### 2d. What Phase A does **not** yet justify

- **Class C greenfield** app/framework benchmarks (`06-implement-class-c-framework-benchmark.md`) — **still required** for complete adoption decisions on greenfield work and framework comparison (ai-repo-template vs Spec Kit).
- **Stage 1E CP-2** robustness screen — deferred.
- **Copilot overlay remap** to GPT-5.4 xhigh or verified fallback arrays — still deferred pending refreshed #220 benchmark tranche ([ADR-019](./adr-019-per-role-model-tiering.md)).
- Production changes to default read profiles, workflow model vars, or subagent registration based solely on Class A/B premerge tasks.

### 3. Revisit cadence

Re-run benchmark stages or amend this ADR when **any** of the following change materially:

- Platform model catalogs, pricing, or API telemetry shape
- Agent runtime / SDK / CLI adapter behavior (`scripts/benchmark/adapters/`)
- Repo orchestration: `AGENTS.md` version, context-pack layout, subagent dispatch contract, or role overlays
- Task class definitions or grading rubrics (`grading/rubric.v*.md`)
- Observed production ROI drift (e.g., advisory/retro cost or quality regressions)

**Minimum:** review recommendations **quarterly** or before any ADR-019 overlay remap PR.

Class C results, when available, must be merged into this ADR (or a superseding ADR) before claiming benchmark completeness.

## Options Considered

### Option 1: Keep benchmark guidance only in `.context/benchmarks/` (status quo)

- **Pros:** No ADR maintenance; protocol stays near harness.
- **Cons:** Policy recommendations invisible to ADR index; agents cite issue comments inconsistently; no revisit trigger.

### Option 2: Encode procedure + recommendations in ADR-031 (chosen)

- **Pros:** Durable policy index entry; links protocol to ADR-019/030; explicit Class C gap and revisit rules.
- **Cons:** Must update when new stages land; risk of drift from results file if not synced.

### Option 3: Amend ADR-019 in place with all benchmark conclusions

- **Pros:** Single model-policy ADR.
- **Cons:** ADR-019 already large; benchmark **procedure** is orthogonal to tier table; violates "new decision → new ADR" discipline for expanded scope.

## Consequences

### Positive

- Single place to answer "how do we benchmark?" and "what did we learn?"
- Clear default: monolithic implementation unless coordination is the goal.
- Explicit Class C gap prevents over-generalizing from premerge Class A/B tasks.

### Negative

- Recommendations age; owners must update ADR or supersede when re-benchmarking.
- Stage 1E pack guidance remains benchmark-scoped until a separate production context-loading ADR lands.

### Neutral

- Does not replace per-workflow env vars or ADR-019 tier table.
- Subjective JSON fixtures remain on `benchmark/roi` tag/branch per runbook — not on `main`.

## Implementation

- [x] Phase A harness + results on `main` (PR #379).
- [x] Canonical regrades for Stage 1, 1C, 1D, pipeline, 1E CP-1 documented in results file.
- [ ] Class C greenfield benchmark (`06-implement-class-c-framework-benchmark.md` on `benchmark/roi`).
- [ ] Stage 1E CP-2 robustness (deferred).
- [ ] Refresh Stage 1E / overlay policy against current `AGENTS.md` before production context-pack routing change.
- [ ] Link this ADR from ADR-019 next amendment tranche when Copilot pins are remapped.

## References

- Issue [#374](https://github.com/mikejmckinney/ai-repo-template/issues/374), [#376](https://github.com/mikejmckinney/ai-repo-template/issues/376), [#378](https://github.com/mikejmckinney/ai-repo-template/issues/378), [#220](https://github.com/mikejmckinney/ai-repo-template/issues/220)
- [`.context/benchmarks/model-roi/README.md`](../../.context/benchmarks/model-roi/README.md)
- [`.context/benchmarks/model-roi/benchmark-runbook.md`](../../.context/benchmarks/model-roi/benchmark-runbook.md)
- [`.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md`](../../.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md)
- [ADR-019 Per-role model tiering](./adr-019-per-role-model-tiering.md)
- [ADR-030 Non-blocking review pipeline](./adr-030-non-blocking-review-pipeline.md)
- [`.github/prompts/06-implement-class-c-framework-benchmark.md`](../../.github/prompts/06-implement-class-c-framework-benchmark.md)
