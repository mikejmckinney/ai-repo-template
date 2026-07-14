# Model ROI Benchmark Result Template

Use one copy of this template per alias/run. Keep the **blind-safe** section shareable with graders. Keep the **sealed** section private until grading is locked.

## Blind-safe record

### Candidate

- Alias:
- Task id / class:
- Phase / stage: `Phase A / Core Stage 1`
- Run index:
- Base branch / Base SHA:
- Candidate branch:
- Final commit SHA:
- PR or local-only:

### Result

- Terminal state: `graded | blocked | manual-capture-approved`
- Status: `SUCCESS | PARTIAL | BLOCKED`
- Acceptance criteria met: `yes | partial | no`
- Verification run / result:
- Human intervention needed:
- Headless run outcome:
- Manual fallback used: `no | yes`

### Blind artifacts

- `meta-blind.json`:
- `diff.patch`:
- `agent-output.jsonl`:
- `grading-sheet-blind.tsv` row:
- Notes for grader:

### Files changed

- `path` — reason

## Sealed evaluator record

> Fill only after blind grading is locked.

- Platform:
- Model:
- Agent/runtime:
- `meta-sealed.json`:
- Input tokens / Output tokens / Cached tokens:
- Wall-clock minutes:
- Effort requested:
- Effort application/status:
- Cost source:

## Process compliance

- AGENTS.md instructions loaded:
- Plan posted or included:
- Subagents used: `no`
- Monolithic justification recorded:
- PR template completed or local-only fallback recorded:
- Doc-sync decisions recorded:
- Phase A scope guard honored:

## Known deviations

- None yet.

## Opportunity notes

- None yet.
