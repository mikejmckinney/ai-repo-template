---
description: Post-merge retro v2 — nightly daily sweep, one umbrella issue, one draft fix PR (cron + dispatch only).
agent: agent
---

# Post-merge retrospective v2 — daily sweep + draft fix PR

## Status

**Implemented** on branch `feature/postmerge-retro-daily-v2` (issue [#426](https://github.com/mikejmckinney/ai-repo-template/issues/426)). Replaces v1 per-PR close trigger + per-finding issues.

**Sequencing:** Implement and smoke-test this prompt **before** `07-implement-gemini-free-paid-routing.md`.

## Objective

Replace noisy per-finding issue creation with a **nightly batch pipeline**:

1. Scan **all PRs merged to `main` in the rolling last 24 hours**.
2. Run retrospective analysis across the batch → **one umbrella GitHub issue per calendar day**.
3. Run a **second LLM pass** (same Cursor/Gemini runner, different prompt) → **one draft fix PR** (`retro/fix-YYYY-MM-DD`) implementing **all** findings.
4. Human or agent reviews the draft PR before merge.

## Triggers (Option C — cron + dispatch only)

| Trigger | Behavior |
|---|---|
| `schedule: 0 6 * * *` (06:00 UTC daily) | Full daily pipeline |
| `workflow_dispatch` | Same full daily pipeline (scan last 24h → umbrella → fix PR) |

**Remove** the v1 `pull_request: closed` label gate. No immediate retro on merge.

**Empty window:** If no merges in last 24h, or retro produces zero actionable findings, skip issue and/or fix PR as appropriate.

**`ai-review:live` / `ai-review:full`:** Unchanged — advisory review during PR life (`agent-advisory-review.yml`). Not post-merge retro gates.

## Umbrella issue

- **One issue per calendar day** identified by `<!-- postmerge-retro:daily:YYYY-MM-DD -->`.
- Body from a **Markdown template file** (automation-filled), not a GitHub Issue Form (`.yml`).
- Table rows: source PR, dedupe key, finding, severity, suggested action.
- **Append semantics:** If manual dispatch at 01:00 UTC creates today's umbrella and cron runs at 06:00 UTC, cron **appends new PR rows** to the existing issue — do **not** skip the job because the marker exists.
- PR-level dedupe: skip PRs already listed in today's umbrella table.

Manual umbrella example from dogfood: [#425](https://github.com/mikejmckinney/ai-repo-template/issues/425).

## Draft fix PR

- Branch: `retro/fix-YYYY-MM-DD` → `main`.
- **Draft** PR only; no auto-merge.
- Implements **all** findings from the nightly retro JSON.
- Permissions: `contents: write`, `pull-requests: write` (v1 was read-only).
- If draft PR for today already exists (open), push additional commits rather than opening a duplicate.
- Skip fix step when retro JSON has zero findings.

## Agent / provider

- Same provider stack as v1 (`POSTMERGE_RETRO_PROVIDER` / `auto`: cursor → gemini).
- **Two prompts:** daily retro batch prompt + fix implementation prompt.
- Reuse `scripts/workflows/advisory-review/` runners where possible.

## Idempotency

| Surface | Marker / rule |
|---|---|
| Umbrella issue | `<!-- postmerge-retro:daily:YYYY-MM-DD -->` — update/append, never skip job |
| Per-PR in umbrella | Dedupe by PR number in table |
| Fix PR | One open draft per day on `retro/fix-YYYY-MM-DD` |
| v1 per-finding markers | Retire `postmerge-retro-create-issues.sh` per-row path or gate behind v1 compat flag |

## Files to add / change (implementation checklist)

1. Refactor `.github/workflows/agent-postmerge-retro.yml` (or split daily job):
   - Remove `pull_request: closed` trigger and label `if`.
   - Add `schedule: 0 6 * * *`.
   - Change `workflow_dispatch` to full daily pipeline (drop single-PR input or make optional debug-only).
   - Add fix-step job with write permissions.
2. New prompts:
   - `.github/prompts/post-merge-retro-daily.md` — batch retro → combined JSON
   - `.github/prompts/post-merge-retro-fix.md` — implement findings on branch
3. New scripts under `scripts/workflows/postmerge-retro/`:
   - `list-merges-last-24h.sh`
   - `create-umbrella-issue.sh` (Markdown template fill + append)
   - `run-postmerge-retro-daily.sh`
   - `run-postmerge-retro-fix.sh` (branch + draft PR)
4. Template: `.github/templates/postmerge-retro-umbrella.md` (or `scripts/templates/`)
5. Update check `052-postmerge-retro-invariants.sh` for v2 wiring.
6. Docs: `docs/guides/agent-pipeline.md`, `AI_REPO_GUIDE.md`, `.github/prompts/README.md`, combined pack status.

## Out of scope

- Gemini free/paid routing (`07-implement-gemini-free-paid-routing.md`) — next after v2 smoke test.
- Auto-merge of fix PRs.
- Per-PR close trigger restoration (unless explicitly re-requested).

## Verification

```bash
./test.sh
# Manual smoke (after merge):
gh workflow run agent-postmerge-retro.yml
# Confirm: umbrella issue (or append), draft fix PR when findings exist, artifacts uploaded
```

## References

- v1 spec: `04-postmerge-retrospective.md` in `agent-pr-prompts-combined-v2.md`
- Dogfood umbrella: issue #425
- Tracking issue: [#426](https://github.com/mikejmckinney/ai-repo-template/issues/426)
