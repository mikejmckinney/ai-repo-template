## Summary

Draft fix PR for daily post-merge retrospective **{{RUN_DATE}}**.

- Findings: **{{FINDINGS_COUNT}}**
- Umbrella marker: `<!-- postmerge-retro:daily:{{RUN_DATE}} -->`
- Umbrella issue: {{UMBRELLA_ISSUE_LINK}}
- Branch: `{{FIX_BRANCH}}`

## Linked issues / ADRs

**Closes / Refs:** {{UMBRELLA_ISSUE_REF}}

Automated follow-up from post-merge retro v2 (ADR-030). Human or agent must verify each fix before marking ready.

## Findings addressed

See umbrella issue for the full findings table. This draft implements the bundled fixes from the daily retro JSON.

## Verification

- [ ] Each finding in the umbrella row has a corresponding fix or explicit skip reason
- [ ] `./test.sh` — pass / fail
- [ ] Manual review of LLM-applied edits before undrafting

## Doc sync

- [ ] `AI_REPO_GUIDE.md: no changes required — retro fix PR; companion updates only if new paths added`
- [ ] `ADR: no changes required — unless retro proposed ADR amendments`

## Meta

Automated by [`agent-postmerge-retro.yml`](https://github.com/{{REPO}}/blob/main/.github/workflows/agent-postmerge-retro.yml) (fix job).
