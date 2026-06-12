# Session: 2026-06-12 — feature/postmerge-retro-daily-v2 — OP

**Status**: PR #427 open — implementation complete; sandbox smoke pending (runbook)
**Issue/PR**: [#426](https://github.com/mikejmckinney/ai-repo-template/issues/426) / [#427](https://github.com/mikejmckinney/ai-repo-template/pull/427)
**Started**: 2026-06-12

## What Was Accomplished

### AGENTS.md v25 — read profile survival after compaction

- Task boundary, post-compaction re-startup, read profile routing table, compliance line.
- `handshake-and-shape-smoke.md` Scenario E (manual post-compaction check).
- Compliance fixtures bumped to v25.

### Post-merge retro v2 (issue #426)

- **Option C:** `schedule: 0 6 * * *` UTC + `workflow_dispatch` only (removed `pull_request: closed`).
- Rolling 24h merge scan → per-PR retro → `daily-retro.json` → umbrella issue (create/append) → draft fix PR `retro/fix-YYYY-MM-DD`.
- New scripts under `scripts/workflows/postmerge-retro/` (daily, umbrella, fix, list merges, merge JSON, apply fix).
- Prompts: `post-merge-retro-fix.md`; template: `.github/templates/postmerge-retro-umbrella.md`.
- Check `052` updated for v2 + AGENTS v25.
- `./test.sh` green (911 passed).

### Follow-up (same branch)

- **ADR-030** — documents full non-blocking pipeline (advisory → finalize → daily post-merge v2).
- Removed one-time impl spec `.github/prompts/05-postmerge-retro-daily-v2.md`; docs point to ADR-030.
- Removed mistaken `sandbox-smoke-postmerge-retro.yml` workflow (one-time smoke uses `docs/guides/sandbox-verification.md` runbook).

## Next

1. **Sandbox smoke (ADR-029)** — per runbook: push branch to sandbox → merge sandbox PR → `gh workflow run agent-postmerge-retro.yml` on sandbox; post run URL on #427.
2. **Merge #427** after green sandbox + review.
3. **Gemini router** (`07`) after merge + upstream smoke.
4. **Light triage** umbrella [#425](https://github.com/mikejmckinney/ai-repo-template/issues/425).

## Design notes (locked)

- No retro label workflow gates; no prompt hints.
- Umbrella append idempotency (manual dispatch before cron same day).
- Skip fix PR when zero findings.
- Merge blocked until sandbox evidence on #427.
