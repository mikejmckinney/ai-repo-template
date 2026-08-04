## Summary

Draft fix PR for weekly repo review **{{RUN_WEEK}}**.

- Findings: **{{FINDINGS_COUNT}}**
- Umbrella marker: `<!-- weekly-review:{{RUN_WEEK}} -->`
- Umbrella issue: {{UMBRELLA_ISSUE_LINK}}
- Branch: `{{FIX_BRANCH}}`

## Linked issues

Fixes #{{UMBRELLA_ISSUE_NUM}}

**Umbrella:** {{UMBRELLA_ISSUE_LINK}} ({{UMBRELLA_ISSUE_REF}})

Automated follow-up from weekly repo review (ADR-030 stage 4). Human or agent must verify each fix before marking ready.

## Findings addressed

See umbrella issue for the full findings table. This draft implements the bundled fixes from the weekly review JSON.

## Verification

- [ ] Each finding in the umbrella row has a corresponding fix or explicit skip reason (`cant_reproduce` in fix-verify.json)
- [ ] `./test.sh` — pass / fail (recorded in fix-verify.json)
- [ ] Remove `weekly/fix-verify-{{RUN_WEEK}}.json` before undraft/merge
- [ ] Manual review of LLM-applied edits before undrafting

{{FIX_VERIFY_SECTIONS}}

## Doc sync

- [ ] `AI_REPO_GUIDE.md`: no changes required — weekly fix PR; companion updates only if new paths added`
- [ ] `ADR`: no changes required — unless weekly review proposed ADR amendments`

## Meta

Automated by [`agent-weekly-review.yml`](https://github.com/{{REPO}}/blob/main/.github/workflows/agent-weekly-review.yml) (fix job).
