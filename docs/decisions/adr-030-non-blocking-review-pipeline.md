# ADR-030: Non-blocking LLM review pipeline (advisory, daily retro, weekly review)

## Status

Accepted (finalize stage retired by ADR-031)

## Date

2026-06-12

## Context

The combined agent prompt pack v2 (PRs 2–4 on `main`) added three **opt-in, non-blocking** GitHub Actions workflows that use Cursor/Gemini runners for LLM-assisted review. They sit alongside existing formal bot reviews (Copilot, Gemini Code Assist) and blocking human gates — they do **not** replace plan-gate, diff-gate, or `claude-fix`.

Prior to pack PR 4, post-merge retro created **one GitHub issue per finding**, which produced operator noise during dogfood (umbrella [#425](https://github.com/mikejmckinney/ai-repo-template/issues/425)). PR [#427](https://github.com/mikejmckinney/ai-repo-template/pull/427) refactors post-merge retro into a **daily batch**: umbrella issue + draft fix PR.

No ADR previously documented the three-phase pipeline, trigger model, or the v1→v2 post-merge output change. This ADR records the durable **why**; workflow behavior is specified in [`docs/guides/agent-pipeline.md`](../guides/agent-pipeline.md).

## Decision

We adopt a **three-stage non-blocking review pipeline** on `main`:

| Stage | Workflow | Opt-in | When | Output |
|---|---|---|---|---|
| **1. Advisory** | `agent-advisory-review.yml` | `ai-review:live` (+ optional `ai-review:full` for depth) | During PR life (incl. draft); on push/label | Single sticky PR comment `<!-- ai-advisory-review:v1 -->` |
| **2. Post-merge retro** | `agent-postmerge-retro.yml` | **None** (daily batch; no label gate) | `schedule: 0 6 * * *` UTC + `workflow_dispatch` | One **umbrella issue**/day + optional **draft fix PR** `retro/fix-YYYY-MM-DD` |
| **3. Weekly repo review** | `agent-weekly-review.yml` | **None** (weekly batch; no label gate) | `schedule: 0 7 * * 0` UTC (Sunday) + `workflow_dispatch` | One **umbrella issue**/ISO week + optional **draft fix PR** `weekly/fix-YYYY-Www` |

Shared properties:

- **Providers:** `POSTMERGE_RETRO_PROVIDER` / `WEEKLY_REVIEW_PROVIDER` / `ADVISORY_REVIEW_PROVIDER`, default `auto` (Cursor first, then the retained OpenCode/Antigravity/Gemini adapters).
- **Scripts:** `scripts/workflows/advisory-review/` (LLM runners), `scripts/workflows/pr-feedback/` (finalize collect), `scripts/workflows/postmerge-retro/` (retro + daily batch), `scripts/workflows/weekly-review/` (weekly full-repo scan + fix).
- **Lifecycle libraries:** daily and weekly adapters share provider dispatch, umbrella issue transport/reference handling, priority derivation, superseded-path detection, and batch-fix publication under `scripts/workflows/lib/`. Cadence-specific prompts, templates, markers, and metadata hooks remain explicit.
- **Non-goals:** No auto-merge of fix PRs; no automatic `claude-fix`; no ADR/context-pack file edits in retro jobs; no formal PR review submission from advisory/finalize.

### Post-merge retro v2 (supersedes v1 trigger/output)

**Triggers (Option C):** cron + `workflow_dispatch` only. **Removed:** `pull_request: closed` and retro label workflow gates (`retro-review`, `retro:adr`, etc.). The obsolete retro labels are retired and do **not** gate automation.

**Batch behavior:**

1. List all PRs merged to `main` in the rolling last 24 hours.
2. Per-PR evidence collection + LLM retro → merge into `daily-retro.json`.
3. Create or **append** one umbrella issue per calendar day (`<!-- postmerge-retro:daily:YYYY-MM-DD -->`).
4. If findings &gt; 0: second LLM pass opens/updates a **draft** fix PR implementing **all** findings; human or agent verifies before merge.

**Idempotency:** Later runs the same day **append** new PR rows to the umbrella; they do not skip the job because the daily marker exists.

**Empty windows:** No merges, or zero findings → skip umbrella and/or fix PR as appropriate.

**Verification class:** `schedule` + `workflow_dispatch` → default-branch-only workflow ([ADR-016](./adr-016-pre-merge-verification-gate.md)); prove in sandbox before merging upstream ([ADR-029](./adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md)).

### Weekly repo review (stage 4)

**Triggers:** Sunday **07:00 UTC** cron + `workflow_dispatch` only (offset from daily retro at 06:00 UTC to reduce concurrent load). **Scope:** static **full-repo** health scan on `main` — not PR-scoped.

**Batch behavior:**

1. Collect run metadata (HEAD SHA, run week) + inject **`full`** context profile via `prompt_helpers.py select-context` (context pack only — no path-trigger expansion).
2. Single LLM pass with **repository read access** (Cursor `local.cwd`; Antigravity when `auto` lacks Cursor) → `weekly-review.json`. Findings use the same classifier inputs as daily retro; automation derives `priority_band` and rejects deprecated `severity`.
3. Create or **append** one umbrella issue per ISO week (`<!-- weekly-review:YYYY-Www -->`). Each finding appears in a compact triage summary table and a detailed block containing its full body, `repo-*` key, reproduction steps, and evidence links pinned to scan HEAD.
4. If findings &gt; 0: second LLM pass opens/updates a **draft** fix PR `weekly/fix-YYYY-Www`; native GitHub issue link via `Fixes #N` in PR body (`scripts/workflows/lib/link-fix-pr-to-issue.sh`).

**Idempotency:** Re-runs the same ISO week **append** new finding blocks by dedupe marker (`<!-- weekly-review:finding:repo-… -->`); they do not skip because the weekly marker exists.

**Smoke-test inputs:** `workflow_dispatch` may pass explicit `run_week` / `run_date` (e.g. sandbox `2099-Www` + far-future dates) to isolate idempotency keys from production ISO weeks. Production cron computes `RUN_WEEK` from UTC `RUN_DATE` via `resolve-run-week.sh`.

**Empty windows:** Zero findings → skip umbrella and fix PR (same as daily retro).

**Deferred routing parity:** Weekly review does not copy the per-PR evidence coverage or adaptive routing model. Add weekly coverage warnings/routing only when explicit weekly context caps exist or observed truncation provides a concrete trigger.

## Options Considered

### Option 1: Keep v1 per-PR close trigger + per-finding issues

- **Pros:** Immediate retro on labeled merges; granular issues.
- **Cons:** Noisy; duplicate work when daily batch added; label ceremony.

### Option 2: Daily batch only (chosen for stage 3)

- **Pros:** One umbrella + one draft fix PR; simpler operator model; no label gates.
- **Cons:** Up to ~24h delay; fix PR may be large; requires sandbox proof pre-merge.

### Option 3: Prompt-hint or label-gated daily batch

- **Pros:** Cheaper runs on quiet days.
- **Cons:** Reintroduces label discipline; rejected for v2.

## Consequences

### Positive

- Single documented pipeline for AP8 non-blocking LLM review.
- Post-merge output matches operator preference (umbrella + draft fix PR).
- Reuses shared evidence collection and LLM runners across stages.

### Negative

- Daily fix PRs can be large; review load shifts to morning batch review.
- Sandbox verification required for workflow changes ([ADR-016](./adr-016-pre-merge-verification-gate.md)).
- Legacy `postmerge-retro-create-issues.sh` retained but not used by v2 daily path.

### Neutral

- Provider routing can evolve independently after benchmark and sandbox evidence supports a change.

## Amendment 2026-07-14 — OpenCode runtime and GitHub MCP

Issue [#480](https://github.com/mikejmckinney/ai-repo-template/issues/480)
moves all three stages to an OpenCode-first runtime without moving evidence or
publication authority into the agent.

- The production adapter uses pinned `@opencode-ai/sdk/v2` sessions. Headless
  CLI remains a diagnostic surface, not the workflow protocol.
- The public-CI model cascade is `openrouter/z-ai/glm-5.2@preset/default`, then
  `openrouter/minimax/minimax-m3@preset/default`. The adapter validates model
  text against the cadence schema, sends one corrective prompt, and then
  advances models. OpenCode 1.18.0's `format` path is not a correctness boundary
  because its synthetic output tool and `retryCount` are unreliable (upstream
  [issue #25430](https://github.com/anomalyco/opencode/issues/25430)).
  Subscription-backed `openai/gpt-5.6-sol` remains an
  interactive local and `local-consensus` model because OpenAI excludes personal
  ChatGPT-managed credentials from public/open-source CI automation.
- Jobs run on GitHub-managed `ubuntu-latest`, matching the established Cursor
  workflow pattern. Node 22 is configured with `actions/setup-node`, and
  `npm ci` installs pinned OpenCode and SDK `1.18.0` from the committed lockfile.
- Agent-directed GitHub reads use a dedicated `OPENCODE_GITHUB_TOKEN` through
  GitHub's hosted MCP endpoint with read-only and lockdown headers and only the
  `repos`, `issues`, `pull_requests`, and `actions` toolsets.
- Deterministic scripts retain pagination, evidence coverage, schema validation,
  dedupe, comments, issues, commits, pushes, and draft-PR publication. The
  OpenCode child process is launched without `GITHUB_TOKEN`, `GH_TOKEN`,
  `CLAUDE_PAT`, or `SANDBOX_BOOTSTRAP_TOKEN`.
- Review profiles deny edits, shell, web, and subagents. Fix profiles allow edits
  but deny shell because command allowlists cannot prevent an editable script from
  reading inherited model or MCP credentials. Every model attempt runs in a
  disposable detached worktree, and the deterministic controller runs `./test.sh`
  without credentials. Only the first schema-valid, verified patch is promoted.
- Cursor, Antigravity, and Gemini remain explicit rollback providers during the
  rollout.

## Amendment 2026-07-16 — Retrieval-first evidence and durable fallback

[Issue #485](https://github.com/mikejmckinney/ai-repo-template/issues/485)
corrects two gaps exposed by
[run 29477823468](https://github.com/mikejmckinney/ai-repo-template/actions/runs/29477823468):

- Tool-capable full-evidence review receives a deterministic inventory of
  addressable local and GitHub sources instead of injected source bodies and
  capped diff/HEAD excerpts. The inventory remains the completeness control;
  agent retrieval does not replace coverage accounting.
- Ephemeral evidence lives inside ignored repository `.artifacts/` so the
  read-only OpenCode profile can inspect it without external-directory access.
- `auto` attempts available analysis providers in OpenCode, Cursor, then Gemini
  order. A failed provider advances to the next provider rather than retrying a
  bounded version of the same incomplete review.
- Daily per-PR failures become explicit sidecars and batch metadata. They do not
  prevent successful PR results, final daily JSON, or workflow artifacts from
  surviving.
- Empty Cursor results include sanitized status/error metadata. Interactive
  process termination uses prospective lifecycle and signal diagnostics rather
  than attributing graceful disposal to model output limits without evidence.

## Amendment 2026-07-17 — Cursor Grok primary review routing

Review automation now prefers Cursor `cursor-grok-4.5-medium` when Cursor
credentials are available, then falls back to the retained OpenCode and Gemini
adapters. This supersedes only the provider order established by the 2026-07-16
amendment; the OpenCode isolation, retrieval, validation, and durable-fallback
controls remain unchanged. Composer 2.5 remains an explicit override rather
than the workflow default.

## Implementation

- [x] Pack PRs 2–4 on `main` (advisory, finalize, retro v1).
- [x] PR #427 — retro v2 daily batch + AGENTS.md v25 compaction/profile rules.
- [x] Sandbox smoke of `agent-postmerge-retro.yml` on `ai-repo-template-sandbox` — end-to-end with canary PR #42 (ADR-029 evidence on #427).
- [x] Automation templates: `.github/templates/postmerge-retro-umbrella.md`, `postmerge-retro-fix-pr.md`; resilient `agent-suggested` label; sandbox label bootstrap via `ensure-pipeline-labels.sh`.
- [x] Merge #427 after review.
- [x] Triage legacy umbrella [#425](https://github.com/mikejmckinney/ai-repo-template/issues/425) (2026-06-13 post-merge).
- [x] Sandbox smoke of `agent-weekly-review.yml` — [run 27516674507](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27516674507) (`2099-W05`, umbrella [#79](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/79), fix PR [#80](https://github.com/mikejmckinney/ai-repo-template-sandbox/pull/80); detailed finding blocks + native link verified on PR #433 branch).
- [x] Merge PR [#433](https://github.com/mikejmckinney/ai-repo-template/pull/433) (weekly review + collector hardening) to upstream `main` (merged 2026-06-15).
- [x] Issue [#480](https://github.com/mikejmckinney/ai-repo-template/issues/480) — OpenCode-first amendment merged in [PR #481](https://github.com/mikejmckinney/ai-repo-template/pull/481).

## References

- [Agent pipeline guide § Post-merge retrospective](../guides/agent-pipeline.md)
- [Combined prompt pack v2 at its final retained commit](https://github.com/mikejmckinney/ai-repo-template/blob/57630c8bc3409798ca4844cc807b406d57108bd8/.github/prompts/agent-pr-prompts-combined-v2.md) — PRs 2–4
- [ADR-016 Pre-merge verification gate](./adr-016-pre-merge-verification-gate.md)
- [ADR-027 Opportunity feedback channel](./adr-027-opportunity-feedback-channel.md)
- [ADR-029 Sandbox dogfood evidence](./adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md)
- [ADR-031 Agent/model ROI benchmark policy](./adr-031-agent-model-roi-benchmark-policy.md) — monolithic default; model/context recommendations
- Issue [#426](https://github.com/mikejmckinney/ai-repo-template/issues/426), PR [#427](https://github.com/mikejmckinney/ai-repo-template/pull/427), PR [#433](https://github.com/mikejmckinney/ai-repo-template/pull/433)
