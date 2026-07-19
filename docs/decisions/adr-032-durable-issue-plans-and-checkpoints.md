# ADR-032: Durable issue plans and per-turn checkpoints

## Status

Accepted

## Date

2026-07-19

## Context

Issue contracts and plans required separate retrieval, while branch-first work
could remain local until a broad task boundary. That delayed draft review and
made session or Codespace loss unrecoverable. Fusion diagnostics also showed
that an unqualified Kimi route timed out and a fenced completion-marker example
was copied literally.

## Decision

New issues carry one `implementation-plan:v2` block in their body. Requester
content outside its delimiters is immutable to agents unless explicitly
authorized. Plans remain current merged snapshots with bounded material revision
history; existing v1 plan comments are grandfathered.

Implementation-ready work creates a branch, empty bootstrap commit, push, and
linked draft PR before meaningful edits. Every changed turn commits and pushes
task-owned files before updating `agent-state:v1`. Red tests and incomplete work
are recorded, not retained indefinitely on local disk. Secrets, unrelated or
ignored files, conflicts, and corrupt state are never checkpointed. Checkpoint
branches are squash-merged or cleaned before review.

Fusion uses explicit `moonshotai/kimi-k3@preset/default`, and its completion
prompt requires an unfenced raw final marker.

This decision supersedes ADR-011 and ADR-025 only for plan location and issue
body edit ownership.

## Options Considered

- Keep a plan comment and add a body pointer: lower edit risk but retains two
  recovery surfaces.
- Wait for a coherent first commit: cleaner early history but delays durability.
- Checkpoint every file: rejected because secrets and unrelated state must stay
  local.

## Consequences

### Positive

- GitHub contains resumable intent, code, and live state throughout a task.
- Draft advisory review can run during implementation.
- Explicit Kimi routing avoids the observed unqualified-route timeout behavior.

### Negative

- Issue body writes remain whole-field last-writer-wins operations.
- Per-turn pushes increase CI and advisory activity.
- Checkpoint branches require squash or cleanup discipline.

### Neutral

- Existing issues and v1 plan comments are not migrated.
- Advisory review remains optional and non-blocking.

## Verification

- V1: issue [#492](https://github.com/mikejmckinney/ai-repo-template/issues/492)
  opened draft PR [#493](https://github.com/mikejmckinney/ai-repo-template/pull/493)
  from an empty bootstrap commit.
- V2: sandbox evidence must prove plan splicing, recovery, exceptions, advisory
  synchronization, and squash output before PR #493 becomes ready.
- V3: repeated explicit-default Kimi trials must produce substantive output and
  the bare final marker.

## References

- [ADR-011](./adr-011-plan-as-comment-requirement.md)
- [ADR-025](./adr-025-github-issues-pr-comments-as-live-state.md)
- [ADR-030](./adr-030-non-blocking-review-pipeline.md)
