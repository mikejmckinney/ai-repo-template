# Session: 2026-06-11 — feature/postmerge-retro-review — OP

**Status**: done
**Issue/PR**: [#383](https://github.com/mikejmckinney/ai-repo-template/pull/383) (merged at [`7e0bf68`](https://github.com/mikejmckinney/ai-repo-template/commit/7e0bf68d592cb391602a4380c4f38e3435a302ad); combined pack PR 4) + hotfixes #384–#404
**Started**: 2026-06-11T23:12:00Z

## What Was Accomplished

- Shipped opt-in **post-merge retrospective review**: label `retro-review` (or related retro labels / `ai-review:full`) on merge to `main` runs `agent-postmerge-retro.yml`; collects merged-PR evidence via wrapper around `collect-pr-feedback.sh`, runs Cursor/Gemini JSON retro, creates follow-up issues idempotently (`<!-- postmerge-retro:pr=<N>:key=... -->`).
- **Combined pack v2 PR 4 complete** on `main` (`agent-postmerge-retro.yml`, `scripts/workflows/postmerge-retro/`, `.github/prompts/post-merge-retro.md`, check `052`).
- **Dogfood:** `workflow_dispatch` succeeded for merged PRs [#383](https://github.com/mikejmckinney/ai-repo-template/actions/runs/27384741284) and [#382](https://github.com/mikejmckinney/ai-repo-template/actions/runs/27384742168) after hotfixes (gh `-R`, checkout `main` for scripts, collector cp fix, `context-pack` / `adr:update` labels).
- Post-merge retro on #383 created follow-up issues [#388–#401](https://github.com/mikejmckinney/ai-repo-template/issues/388) (dedupe prevented duplicates on re-run).

## What Shipped

- `.github/workflows/agent-postmerge-retro.yml`
- `scripts/workflows/postmerge-retro/*`
- `.github/prompts/post-merge-retro.md`
- `.github/schemas/postmerge-retro.schema.json`
- `scripts/checks/052-postmerge-retro-invariants.sh`
- Labels: `adr:update`, `context-pack` (+ existing retro labels)
- Docs: `docs/guides/agent-pipeline.md`, `AI_REPO_GUIDE.md`, prompts README + combined pack status

## Harder Than Expected

- First close-trigger run failed (`gh pr view --json merged` invalid; fixed #384).
- `workflow_dispatch` needed `gh pr view -R` before checkout (#385) and **checkout `main`** (not merge commit) so dogfood re-runs use hotfixed scripts (#387).
- Collector had a no-op self-`cp` (#386); missing GitHub labels (`context-pack`, `adr:update`) blocked issue create until #404.
- `gh label list` pagination caused false “label not found” warnings for `agent-suggested` (follow-up: use per-label API lookup).

## Generalizable Lessons

- Post-merge automation should checkout **default branch scripts**, not the merged PR's merge commit, when re-running on historical PRs.
- `gh pr view` in Actions needs `-R "$GITHUB_REPOSITORY"` when no git workspace exists yet.
- Issue creators should tolerate missing labels (warn + continue) and verify label existence via API, not paginated list.

## Open Items / Next

1. **Gemini free/paid routing** — `.github/prompts/07-implement-gemini-free-paid-routing.md` on fresh branch from `main`.
2. **Read-profile experiment** — deferred from PR 3 session.
3. **Triage retro follow-ups** — issues #388+ from dogfood (many are valid; some may be duplicates/noise).
