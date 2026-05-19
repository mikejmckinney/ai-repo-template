# State Directory

> **Purpose**: Keep transition-era state templates and compatibility views discoverable. ADR-025 makes GitHub issues, PRs, labels, and the latest `agent-state:v1` comment the primary live coordination state for normal GitHub-connected work.

## Primary live state after ADR-025

Use these GitHub surfaces for current work:

1. **Issue body** — durable feature/task contract and gate input.
2. **PR body** — implementation, review, plan links, and verification contract.
3. **Latest `agent-state:v1` issue/PR comment** — mutable live status, blockers, next actions, and handoff baton.
4. **Labels** — coarse workflow filters only: `agent:claimed`, `agent:blocked`, `agent:awaiting-review`. The `agent-suggested` label marks follow-up issues filed from the `opportunity_notes` channel (ADR-027 / [`process_opportunity_feedback.md`](../rules/process_opportunity_feedback.md))—pending triage by PM.

The copy/paste template for the live comment is [`agent_state_comment_template.md`](agent_state_comment_template.md). Keep comments slim; do not duplicate full PR bodies, verification matrices, file lists, or retrospective lessons.

## Legacy compatibility views

- **`_active.md`** — legacy manual multi-task snapshot from ADR-018. Existing sections may be stale because GitHub owns PR lifecycle events. Do not create new normal-work sections after ADR-025; old entries may drain naturally or be cleaned by a separate legacy cleanup PR.
- **`coordination.md`** — legacy manual claim board and task-state machine. It may remain useful as a compatibility view or generated target, but it is no longer the primary live-state source for GitHub-connected work.
- **`feedback_template.md`** — stakeholder feedback capture template for the optional stakeholder-review path. This remains a durable template, not a live coordination baton.

The old `task_template.md` and `handoff_template.md` files were removed by ADR-025. The GitHub issue body supersedes copied task files; the `Handoff` section of the latest `agent-state:v1` comment supersedes copied handoff files.

## Offline or no-GitHub fallback

If GitHub API access is unavailable, temporarily write the same `agent-state:v1` content into a local scratch note. Copy it into the issue or PR comment once access returns. Do not commit local live-state scratch files as the normal coordination path.

## Durable knowledge belongs elsewhere

- Decisions belong in `docs/decisions/<adr>.md`.
- Formal incidents belong in `docs/postmortems/**`.
- Durable session lessons belong in `.context/sessions/latest_summary.md` and archives.
- Operating rules belong in `.context/rules/**`.
