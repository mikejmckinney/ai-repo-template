# ADR-030: Non-blocking LLM review pipeline (advisory → finalize → daily post-merge retro)

## Status

Proposed

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
| **2. Finalize** | `agent-review-finalize.yml` | `implementation-complete` | Near end of implementation | Single sticky **Feedback Inbox** comment |
| **3. Post-merge retro** | `agent-postmerge-retro.yml` | **None** (daily batch; no label gate) | `schedule: 0 6 * * *` UTC + `workflow_dispatch` | One **umbrella issue**/day + optional **draft fix PR** `retro/fix-YYYY-MM-DD` |

Shared properties:

- **Providers:** `POSTMERGE_RETRO_PROVIDER` / `ADVISORY_REVIEW_PROVIDER`, default `auto` (Cursor SDK if key present, else Gemini API).
- **Scripts:** `scripts/workflows/advisory-review/` (LLM runners), `scripts/workflows/pr-feedback/` (finalize collect), `scripts/workflows/postmerge-retro/` (retro + daily batch).
- **Non-goals:** No auto-merge of fix PRs; no automatic `claude-fix`; no ADR/context-pack file edits in retro jobs; no formal PR review submission from advisory/finalize.

### Post-merge retro v2 (supersedes v1 trigger/output)

**Triggers (Option C):** cron + `workflow_dispatch` only. **Removed:** `pull_request: closed` and retro label workflow gates (`retro-review`, `retro:adr`, etc.). Labels may remain as optional human metadata; they do **not** gate automation.

**Batch behavior:**

1. List all PRs merged to `main` in the rolling last 24 hours.
2. Per-PR evidence collection + LLM retro → merge into `daily-retro.json`.
3. Create or **append** one umbrella issue per calendar day (`<!-- postmerge-retro:daily:YYYY-MM-DD -->`).
4. If findings &gt; 0: second LLM pass opens/updates a **draft** fix PR implementing **all** findings; human or agent verifies before merge.

**Idempotency:** Later runs the same day **append** new PR rows to the umbrella; they do not skip the job because the daily marker exists.

**Empty windows:** No merges, or zero findings → skip umbrella and/or fix PR as appropriate.

**Verification class:** `schedule` + `workflow_dispatch` → default-branch-only workflow ([ADR-016](./adr-016-pre-merge-verification-gate.md)); prove in sandbox before merging upstream ([ADR-029](./adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md)).

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

- Gemini free/paid routing ([`07-implement-gemini-free-paid-routing.md`](../../.github/prompts/07-implement-gemini-free-paid-routing.md)) remains queued after v2 sandbox smoke.

## Implementation

- [x] Pack PRs 2–4 on `main` (advisory, finalize, retro v1).
- [x] PR #427 — retro v2 daily batch + AGENTS.md v25 compaction/profile rules.
- [ ] Sandbox smoke of `agent-postmerge-retro.yml` on `ai-repo-template-sandbox` (ADR-029 evidence on #427).
- [ ] Merge #427 after green sandbox + review.
- [ ] Triage legacy umbrella [#425](https://github.com/mikejmckinney/ai-repo-template/issues/425).

## References

- [Agent pipeline guide § Post-merge retrospective](../guides/agent-pipeline.md)
- [Combined prompt pack v2](../../.github/prompts/agent-pr-prompts-combined-v2.md) — PRs 2–4
- [ADR-016 Pre-merge verification gate](./adr-016-pre-merge-verification-gate.md)
- [ADR-027 Opportunity feedback channel](./adr-027-opportunity-feedback-channel.md)
- [ADR-029 Sandbox dogfood evidence](./adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md)
- Issue [#426](https://github.com/mikejmckinney/ai-repo-template/issues/426), PR [#427](https://github.com/mikejmckinney/ai-repo-template/pull/427)
