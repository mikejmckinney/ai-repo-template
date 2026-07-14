---
description: End-to-end issue-to-merge playbook for the default agent.
agent: agent
---

# OP issue-to-merge playbook

One agent implements the issue end to end per
[ADR-032](../../docs/decisions/adr-032-monolithic-agent-and-review-lifecycle.md).
Use `local-consensus` only when the user requests it or consequential uncertainty
justifies independent model perspectives. Optional advisory review may run in
parallel but never owns implementation or blocks progress.

## Phase 0 — Start

1. Follow [`AGENTS.md`](../../AGENTS.md), which is already loaded by supported
   runtimes.
2. Emit the current handshake from `AGENTS.md` at a new task boundary.
3. Read the assigned issue and linked PR. Use `.context/00_INDEX.md` only when
   project direction or state is relevant.
4. Resolve ambiguity from current sources; ask the user when materially
   different interpretations remain.

## Phase 1 — Plan

1. Create a non-default branch before non-trivial edits.
2. For issue-backed work, post a concise plan using
   [`.github/PLAN_TEMPLATE.md`](../PLAN_TEMPLATE.md), unless an ADR-011 exemption
   applies.
3. State the user outcome, approach, expected files, risks, and exact validation
   steps.
4. Keep implementation with one agent. Record any independent advisory input in
   ordinary prose; no compliance YAML is required.

## Phase 2 — Implement

1. Make the smallest reversible change that resolves the issue.
2. Preserve unrelated worktree changes.
3. Add or update focused tests for behavioral changes.
4. Update companion documentation required by `AGENTS.md`.
5. If scope materially diverges from the plan, update the issue plan before
   review.

## Phase 3 — Verify

1. Perform the issue's observable user-outcome or 15-minute test.
2. Run affected focused tests and linters.
3. Run `./test.sh` before declaring repository changes complete.
4. For default-branch-only workflow changes, follow
   [`docs/guides/sandbox-verification.md`](../../docs/guides/sandbox-verification.md)
   and record real issue, PR, and run links.
5. Stop and surface a framing mismatch when the implementation does not resolve
   the stated problem.

## Phase 4 — Review and PR

1. Inspect `git status`, the complete diff, and recent commits.
2. Ensure the PR links its issue, plan, verification results, user-outcome
   evidence, documentation synchronization, risks, and rollback path.
3. Use optional advisory review or `local-consensus` when risk or uncertainty
   justifies independent input.
4. Resolve review findings by fixing the underlying behavior; never weaken tests
   merely to force a green result.

## Phase 5 — Close out

1. Confirm required CI is green.
2. Keep the latest `agent-state:v1` comment only when work is paused, blocked,
   awaiting review, or handed off.
3. Keep durable decisions in ADRs and durable lessons in postmortems or session
   summaries rather than creating a second task-state system.

## Phase 6 — Merge

1. Merge only after required checks and review are complete.
2. Preserve the PR and issue links as the durable implementation record.

## Phase 7 — Learn

1. Capture a postmortem only for incidents or lessons worth preserving.
2. Feed generalized lessons into `AGENTS.md`, an ADR, or a focused guide rather
   than creating another mandatory context layer.

## Anti-patterns

- Do not hardcode handshake versions outside `AGENTS.md`.
- Do not recreate structured compliance blocks or context-receipt tables.
- Do not recreate role dispatch or a multi-agent implementation pipeline.
- Do not treat green CI as a substitute for user-outcome validation.
