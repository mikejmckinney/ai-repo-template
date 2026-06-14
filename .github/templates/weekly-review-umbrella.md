<!-- markdownlint-disable MD055 MD056 -->
## Summary

Weekly **full-repo** health review on `main` (static scan; not PR-scoped).

<!-- weekly-review:{{RUN_WEEK}} -->

**Run week (ISO):** {{RUN_WEEK}}  
**Scan date (UTC):** {{RUN_DATE}}  
**HEAD SHA:** {{HEAD_SHA}}

## Findings

| Scope | Category | Dedupe key | Severity | Finding | Suggested action |
|---|---|---|---|---|---|
{{FINDING_ROWS}}

## Meta

Automated by [`agent-weekly-review.yml`](https://github.com/{{REPO}}/blob/main/.github/workflows/agent-weekly-review.yml).  
Draft fix PR (if created): {{FIX_PR_LINK}}

Review findings and merge the draft fix PR only after human or agent verification.
