# ADR-031: Agent/model ROI benchmark and execution lifecycle policy

## Status

Accepted

## Date

2026-06-15

## Amendment 2026-07-15 — Isolate benchmark apparatus

Benchmark harnesses, prompts, tasks, schemas, grading tools, and benchmark-only
checks live on `benchmark/roi`. `main` retains this policy, the canonical
operator guide, and published result records under `docs/`. The completed
pre-isolation apparatus is pinned at
[`8c296458`](https://github.com/mikejmckinney/ai-repo-template/tree/8c2964583af04b3352561410e22511304001ec21),
and raw Phase A evidence remains tagged at
[`benchmark/phase-a-artifacts-20260608`](https://github.com/mikejmckinney/ai-repo-template/tree/benchmark/phase-a-artifacts-20260608).

## Context

Issue [#374](https://github.com/mikejmckinney/ai-repo-template/issues/374) and follow-ons ([#376](https://github.com/mikejmckinney/ai-repo-template/issues/376), [#378](https://github.com/mikejmckinney/ai-repo-template/issues/378)) produced a reproducible **model ROI benchmark harness** (Phase A merged in PR [#379](https://github.com/mikejmckinney/ai-repo-template/pull/379)). Issue [#483](https://github.com/mikejmckinney/ai-repo-template/issues/483) later isolated the apparatus on `benchmark/roi`. Scored results live in [`docs/benchmarks/agent-roi-benchmark-results.md`](../benchmarks/agent-roi-benchmark-results.md).

Until this ADR, benchmark **procedure** and **actionable recommendations** were scattered across:

- the `benchmark/roi` README and runbook (operator protocol)
- Issue comments and prompt pack notes (ad hoc guidance)
- Partial pointers in [ADR-019](./adr-019-per-role-model-tiering.md) (tier policy deferred pending benchmark refresh)

Operators and agents need a single durable **policy surface** for:

1. How to run and extend benchmarks (without re-deriving protocol from issues).
2. What the completed Class A / Class B evidence supports **today** for model, context, and orchestration choices.
3. What is **still missing** (Class C greenfield) and when to re-run.

Issue [#474](https://github.com/mikejmckinney/ai-repo-template/issues/474)
applied the benchmark result to the repository's operating model. Maintaining
unused role registries, platform overlays, and separate formal-review stages
continued to create drift after the evidence favored monolithic execution.

Benchmark evidence is **not static**. Platforms rename models, pricing changes, agent runtimes change tool behavior, and repo process (`AGENTS.md`, context packs, subagent dispatch) evolves. Recommendations here are **current as of the cited score sets** and must be revisited when those inputs change materially.

## Decision

### 1. Canonical benchmark procedure

We treat the following as the **single operator contract** for agent/model ROI benchmarks in this repo:

| Surface | Role |
|---|---|
| [`8c296458` protocol](https://github.com/mikejmckinney/ai-repo-template/blob/8c2964583af04b3352561410e22511304001ec21/.context/benchmarks/model-roi/README.md) | Protocol, artifact model, task classes, stage definitions |
| [`docs/guides/model-roi-benchmark-runbook.md`](../guides/model-roi-benchmark-runbook.md) | Canonical setup, synchronization, run, grade, and publication procedure |
| [`8c296458` grading](https://github.com/mikejmckinney/ai-repo-template/tree/8c2964583af04b3352561410e22511304001ec21/.context/benchmarks/model-roi/grading) | Rubrics, schemas, score-set comparability rules |
| [`8c296458` harness](https://github.com/mikejmckinney/ai-repo-template/tree/8c2964583af04b3352561410e22511304001ec21/scripts/benchmark) | Harness entrypoints (`make doctor`, `base`, `run`, `suite`, `regrade-stage.sh`, etc.) |
| [`8c296458` candidate prompt](https://github.com/mikejmckinney/ai-repo-template/blob/8c2964583af04b3352561410e22511304001ec21/.github/prompts/model-roi-benchmark-candidate.md) | Shared candidate prompt body (task injected per run) |
| [`docs/benchmarks/agent-roi-benchmark-results.md`](../benchmarks/agent-roi-benchmark-results.md) | Scored record and ROI tables (operator source of truth on `main`) |
| [`docs/benchmarks/retro-execution-447-results.md`](../benchmarks/retro-execution-447-results.md) | Retro execution benchmark record |

**Primary ranking metric:** **marginal ROI** = canonical weighted score ÷ marginal cost USD (token telemetry × public rate card where available). Amortized/subscription ROI is secondary unless explicitly scoped.

**Task classes (Phase A completed unless noted):**

| Class | Description | Committed tasks | Status |
|---|---|---|---|
| **A** | Operational fit — small/medium repo-process implementation | `opfit-281-class-a` (+ pipeline variant) | Benchmarked (Stage 1, 1C, 1D, 1E, #376 pipeline) |
| **B** | Reasoning / code — harder implementation | `opfit-326-class-b` (+ pipeline variant) | Benchmarked (same stages) |
| **C** | Greenfield app / framework comparison | Planned on `benchmark/roi` | **Not yet run** — required for a complete picture |

**Blind / sealed discipline:** alias manifests, frozen bases, blind grading before unseal, and `score_set_id` citation for canonical conclusions (see grading README).

Before a benchmark campaign, synchronize `benchmark/roi` from current `main` and
refresh its operator contract for any repository changes. The pinned snapshot
above is the completed-campaign reference; result-only changes to `main` follow
the normal repository contract.

### 2. Current recommendations (Phase A evidence)

These recommendations apply to **routine repo implementation and non-blocking review automation** unless a task explicitly requires multi-role coordination quality as the primary goal.

#### 2a. Default execution shape: monolithic over multi-role pipeline

Issue #376 tested repo-native **orchestration pipelines** (subagents + handoffs) against completed monolithic Stage 1 baselines on the same Class A/B tasks.

**Finding:** No favorable ROI crossover was observed. Monolithic Cursor Auto / Composer-style runs and strong Gemini Flash rows remain the better default direction; pipeline runs were generally slower, often costlier, and did not materially improve quality on simple Class A work ([`agent-roi-benchmark-results.md` § Issue #376](../benchmarks/agent-roi-benchmark-results.md)).

**Policy:**

- **Prefer a single implementing agent** (monolithic pass) for routine issue/PR implementation, retro fix passes, and weekly fix passes.
- **Do not use subagent fan-out for routine repository work.** The role registry is retired; use `multi-model-consensus` only when independent multi-model review is explicitly justified.
- **Stage 1D duo** (planner + implementer) did not beat the best monolithic ROI leaders on either class; treat duo as experimental, not default.

This supersedes ADR-019's active role-tiering guidance while preserving that
ADR as historical benchmark context.

#### 2b. Model / platform shortlist (where telemetry exists)

For **implementation-shaped** work (Classes A/B), Phase A marginal ROI and canonical scores support:

| Tier | Candidates | Notes |
|---|---|---|
| **First choice (implementation)** | Cursor **Composer 2.5**, Gemini **Flash** (requested `gemini-3.5-flash` → observed `gemini-3-flash-preview` backend in harness), Cursor **Auto** | Strong score/ROI on both classes when telemetry captured |
| **Use with care** | Copilot **Auto** (routed model varies), Codex default | Useful rows exist; verify routed model and partial-run caveats |
| **Escalation / gates** | High-tier models per ADR-019 (Opus-class, GPT-5.4 xhigh on Copilot parent for reasoning-heavy parent sessions) | Not default for routine implementation; use for plan-gate, diff-gate, architecture, hard review resolution |

Advisory/retro **CI defaults** are governed by [ADR-030](./adr-030-non-blocking-review-pipeline.md) and workflow vars. Its 2026-07-21 amendment makes eligible access-only Sol and OpenRouter Kimi K3 the first runtime, followed by Cursor Grok 4.5 Medium and retained rollback providers. GPT-5.6 Sol also remains the first multi-model Judge/Advisor model. This ADR informs those choices but does not replace per-workflow environment documentation.

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

- **Class C greenfield** app/framework benchmarks (planned on `benchmark/roi`) — **still required** for complete adoption decisions on greenfield work and framework comparison (ai-repo-template vs Spec Kit).
- **Stage 1E CP-2** robustness screen — deferred.
- **Copilot overlay remap** to GPT-5.4 xhigh or verified fallback arrays — still deferred pending refreshed #220 benchmark tranche ([ADR-019](./adr-019-per-role-model-tiering.md)).
- Production changes to default read profiles or workflow model variables based solely on Class A/B premerge tasks.

#### 2e. Active execution and review lifecycle

The repository applies the benchmark recommendation as follows:

- Routine implementation uses one monolithic implementing agent.
- CI and lint are the blocking pre-merge controls.
- Advisory review is optional via `ai-review:live`, runs in parallel with active
  implementation, updates one sticky comment, and cannot mutate or block the PR.
- Daily post-merge retro and weekly full-repository review remain the recurring
  review and draft-fix pipelines.
- `.agents/skills/multi-model-consensus/` is the sole opt-in multi-model mechanism.
- One shared review contract feeds advisory, daily, and weekly prompts; cadence
  prompts retain only their evidence boundary and output interface.
- Canonical roles, platform overlays, native reviewer rules, multi-role dispatch,
  formal AI review, review resolution, finalization, and legacy consensus
  planning are retired.
- Cross-PR overlap visibility remains; issue assignment and branch updates are
  operator-owned.

This lifecycle supersedes ADR-003, ADR-004, ADR-005, ADR-008, ADR-009, ADR-014,
ADR-019, ADR-023, and ADR-024 for active operations. Their bodies and benchmark
artifacts remain historical evidence. ADR-007 remains superseded through ADR-008.

#### Amendment 2026-07-17 — Multi-model skill identity and Fusion panel

The public skill identity moves from `local-consensus` to
`multi-model-consensus`; callers must update the directory, skill slug, and
`LOCAL_CONSENSUS_*` overrides to `.agents/skills/multi-model-consensus/`,
`multi-model-consensus`, and `MULTI_MODEL_CONSENSUS_*`. No deprecated alias is
retained. Fusion uses OpenRouter Kimi K3, Fable, and Cursor Grok as primary
panels, then backfills with Sol, GLM, MiniMax, MiMo, and DeepSeek. Judge/Advisor
ordering remains Sol, Fable, Grok, then GLM.

#### Amendment 2026-07-18 - Risk-based problem framing and critical review

The monolithic implementing agent validates the problem and user outcome before
designing implementation when work introduces net-new behavior, has ambiguous
scope, makes a user-facing product choice, or is costly or difficult to reverse.
Routine deterministic fixes and behavior-neutral maintenance do not acquire a
mandatory framing stage unless their expected behavior is itself ambiguous.

This is a reasoning contract, not a restoration of the retired Analyst, Judge,
or Critic roles. It adds no role handoff, pipeline stage, verdict, or mandatory
approval pause. `AGENTS.md` contains the concise normative policy, while
`docs/guides/problem-framing.md` provides an optional detailed scaffold for
product and market decisions.

Critical review must identify the concrete failure mode, evidence, affected
surface, and a proportionate path forward. Supporting checks cannot substitute
for the issue's user-outcome test. Conditional impact dimensions remain separate
and evidence-backed rather than being collapsed into a composite score.

Class C greenfield work remains unbenchmarked. This amendment therefore does not
claim that deeper framing improves model ROI for all product work; it bounds the
new policy by consequence and ambiguity and requires sandbox dogfood before the
change is treated as complete.

### 3. Revisit cadence

Re-run benchmark stages or amend this ADR when **any** of the following change materially:

- Platform model catalogs, pricing, or API telemetry shape
- Agent runtime / SDK / CLI adapter behavior on `benchmark/roi`
- Repo orchestration: `AGENTS.md` version, context-pack layout, subagent dispatch contract, or role overlays
- Task class definitions or grading rubrics (`grading/rubric.v*.md`)
- Observed production ROI drift (e.g., advisory/retro cost or quality regressions)

**Minimum:** review recommendations **quarterly** or before any ADR-019 overlay remap PR.

Class C results, when available, must be merged into this ADR (or a superseding ADR) before claiming benchmark completeness.

### OpenCode rollout evidence requirement

Issue #480 changes the runtime/tool boundary rather than claiming that the new
models outperform prior benchmark leaders. Before removing the retained
Cursor/Gemini adapters, compare sandbox advisory, daily, and weekly runs against
the latest successful Cursor runs for schema success, elapsed time, token/tool
context, finding usefulness, and fix verification. Record requested and observed
models, locked runtime version, and GitHub runner image release. A regression in evidence completeness,
structured-output reliability, or fix isolation reverses `auto` to Cursor while
the OpenCode adapter remains available explicitly.

## Amendment 2026-06-15 — Slim `.context/rules/` catalog (issue #437 / PR #438)

**Motivation:** Phase A benchmark evidence (especially issue #376 pipeline vs monolithic) supports a **monolithic default** for routine implementation. A large per-concern rule catalog increased context cost without improving ROI on Class A/B tasks. The slim catalog adopted by this historical amendment is pinned at [`.context/rules/README.md`](https://github.com/mikejmckinney/ai-repo-template/blob/b21f76149c84962566950d61eeca7d54fcaeb505/.context/rules/README.md); the catalog was later retired from `main`.

**Decision:**

- **Remove** these normative rule files from `.context/rules/` (restore point: `origin/backup-2026-06-15`):
  - `agent_ownership.md`
  - `process_gates.md`
  - `process_model_tier.md`
  - `process_pr_completion.md`
  - `process_role_selection.md`
  - `process_subagent_bootstrap.md`
  - `process_template_detection.md`
- **Retain** durable surfaces for the same concerns outside the rule catalog:
  - Template detection / Mode B bootstrap → the OpenCode `repo-onboarding` skill
  - Gates and PR completion → `AGENTS.md`, [`.github/pull_request_template.md`](../../.github/pull_request_template.md), and `scripts/verify-pr.sh`
  - Ownership / parallelism → `agent-parallelism-report.yml` remains; live ownership table enforcement is **deferred** until a future benchmark or operational need justifies restoring `agent_ownership.md`
- **Stage 1E context packs** on `main` drop references to removed rule files so harness manifests match the production catalog.

**Reversal:** If a future benchmark score set (documented in [`docs/benchmarks/agent-roi-benchmark-results.md`](../benchmarks/agent-roi-benchmark-results.md) with a new `score_set_id`) shows favorable ROI for multi-role pipeline or full-rule injection as the default, **amend this ADR** with the contradicting evidence and restore removed rule files from `origin/backup-2026-06-15` (or a successor backup) as needed. Until then, monolithic default + slim catalog stand.

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
- One active review lifecycle replaces unused role and formal-review surfaces.
- Explicit Class C gap prevents over-generalizing from premerge Class A/B tasks.

### Negative

- Recommendations age; owners must update ADR or supersede when re-benchmarking.
- Stage 1E pack guidance remains benchmark-scoped until a separate production context-loading ADR lands.
- Optional advisory feedback can complete after implementation advances; some
  defects will instead be found by recurring post-merge review.

### Neutral

- Does not replace per-workflow env vars or ADR-019 tier table.
- Subjective JSON fixtures remain on `benchmark/roi` tag/branch per runbook — not on `main`.

## Implementation

- [x] Phase A harness + results originally landed on `main` (PR #379); issue
  #483 later isolated apparatus on `benchmark/roi` and results under `docs/`.
- [x] Canonical regrades for Stage 1, 1C, 1D, pipeline, 1E CP-1 documented in results file.
- [ ] Class C greenfield benchmark (`06-implement-class-c-framework-benchmark.md` on `benchmark/roi`).
- [ ] Stage 1E CP-2 robustness (deferred).
- [ ] Refresh Stage 1E policy against current `AGENTS.md` before a production context-pack routing change.
- [x] Slim `.context/rules/` catalog per Amendment 2026-06-15 (issue #437 / PR #438).
- [x] Apply the monolithic implementation and review lifecycle (issue #474 / PR #476).
- [x] Add risk-based problem framing and actionable critical review (issue #488 / PR #487).
- [ ] Refresh the model shortlist when Copilot pins are remapped.
- [ ] Record issue #480 sandbox OpenCode-versus-Cursor telemetry before retiring rollback providers.

## References

- Issue [#374](https://github.com/mikejmckinney/ai-repo-template/issues/374), [#376](https://github.com/mikejmckinney/ai-repo-template/issues/376), [#378](https://github.com/mikejmckinney/ai-repo-template/issues/378), [#220](https://github.com/mikejmckinney/ai-repo-template/issues/220)
- Issue [#474](https://github.com/mikejmckinney/ai-repo-template/issues/474), PR [#476](https://github.com/mikejmckinney/ai-repo-template/pull/476)
- [`8c296458` protocol](https://github.com/mikejmckinney/ai-repo-template/blob/8c2964583af04b3352561410e22511304001ec21/.context/benchmarks/model-roi/README.md)
- [`docs/guides/model-roi-benchmark-runbook.md`](../guides/model-roi-benchmark-runbook.md)
- [`docs/benchmarks/agent-roi-benchmark-results.md`](../benchmarks/agent-roi-benchmark-results.md)
- [`docs/benchmarks/retro-execution-447-results.md`](../benchmarks/retro-execution-447-results.md)
- [ADR-019 Per-role model tiering](./adr-019-per-role-model-tiering.md)
- [ADR-030 Non-blocking review pipeline](./adr-030-non-blocking-review-pipeline.md)
- [`benchmark/roi` Class C prompt](https://github.com/mikejmckinney/ai-repo-template/blob/benchmark/roi/.github/prompts/06-implement-class-c-framework-benchmark.md)
