# Model ROI Benchmark Summary Template

Use one copy of this template per benchmark task after every Core Stage 1 alias reaches a terminal state. Keep the **blind-safe** portions intact until grading is locked.

## Round

- Task id:
- Task class:
- Phase / stage: `Phase A / Core Stage 1`
- Base branch / Base SHA:
- Prompt path: `.github/prompts/model-roi-benchmark-candidate.md`
- Manifest revision:
- Date window:

## Scope guard

- Stage 1 only confirmed:
- Stage 2 deferred to Phase B / Plan v2:
- Shared prompt body reused across candidates:
- Detailed effort metadata kept out of blind-facing summary:
- Pending DevOps hardening noted where applicable:

## Blind-safe alias coverage

| Alias | Run | Terminal state | PR / local-only | Artifact path | Notes |
|---|---|---|---|---|---|
| `cand-01` | `r1` | `graded` |  |  |  |

Every Core Stage 1 alias must appear exactly once in this table before `collect` or `unseal`.

## Blind grading outcome

- Shortlist for Phase B:
- Non-finalists:
- Blocked or manual-capture rows:
- Grader notes:

## Sealed reveal

> Fill this section only after scores are locked and `make unseal` has been run.

| Alias | Platform | Model | Agent/runtime | Effort note | Score / outcome note |
|---|---|---|---|---|---|
| `cand-01` |  |  |  |  |  |

## Phase B inputs

- Finalists proposed for extended Stage 1 or Stage 2:
- Reasons for shortlist:
- Runner gaps to address before Phase B:
- Open blockers or caveats:
