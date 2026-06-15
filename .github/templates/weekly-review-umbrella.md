<!-- markdownlint-disable MD055 MD056 -->
## Summary

Full-repository health review on `main` (static scan; not PR-scoped).

<!-- weekly-review:{{RUN_WEEK}} -->

| Field | Value |
|---|---|
| **Run week (ISO)** | `{{RUN_WEEK}}` — idempotency key for this batch (calendar week; not a commit range) |
| **Scan date (UTC)** | `{{RUN_DATE}}` |
| **HEAD SHA** | [`{{HEAD_SHA}}`](https://github.com/{{REPO}}/commit/{{HEAD_SHA}}) — tip of `main` at scan time, not the diff boundary |

## Findings

{{FINDING_BLOCKS}}

## Meta

Automated by [`agent-weekly-review.yml`](https://github.com/{{REPO}}/blob/main/.github/workflows/agent-weekly-review.yml).  
Draft fix PR (if created): {{FIX_PR_LINK}}

Review findings and merge the draft fix PR only after human or agent verification.
