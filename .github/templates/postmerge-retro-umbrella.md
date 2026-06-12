## Summary

Daily post-merge retrospective for merges to `main` in the rolling last **{{WINDOW_HOURS}}** hours.

<!-- postmerge-retro:daily:{{RUN_DATE}} -->

**Window end (UTC):** {{WINDOW_END}}  
**PRs in this update:** {{PR_LIST}}

## Findings

| PR | Category | Dedupe key | Severity | Finding | Suggested action |
|---|---|---|---|---|---|
{{FINDING_ROWS}}

## Meta

Automated by [`agent-postmerge-retro.yml`](https://github.com/{{REPO}}/blob/main/.github/workflows/agent-postmerge-retro.yml) (daily batch v2).  
Draft fix PR (if created): {{FIX_PR_LINK}}

Review findings and merge the draft fix PR only after human or agent verification.
