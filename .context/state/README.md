# State Directory

> **Purpose**: Keep the GitHub-first live-state reference artifacts discoverable. ADR-025 makes GitHub issues, PRs, labels, and the latest `agent-state:v1` comment the primary live coordination state for normal GitHub-connected work.

## Contents

```text
.context/state/
├── README.md                        # This file
└── agent_state_comment_template.md  # GitHub live-state comment template
```

PM owns this directory because it defines the coordination baton format, but current task state still lives on GitHub rather than in committed repo-local boards.

## Primary live state after ADR-025

Use these GitHub surfaces for current work:

1. **Issue body** — durable feature/task contract and gate input.
2. **PR body** — implementation, review, plan links, and verification contract.
3. **Latest `agent-state:v1` issue/PR comment** — mutable live status, blockers, next actions, and handoff baton.
4. **Labels** — coarse workflow filters only: `agent:claimed`, `agent:blocked`, `agent:awaiting-review`. The `agent-suggested` label marks follow-up issues filed from the `opportunity_notes` channel (ADR-027 / [`process_opportunity_feedback.md`](../rules/process_opportunity_feedback.md)) and awaits PM triage.

The copy/paste template for the live comment is [`agent_state_comment_template.md`](agent_state_comment_template.md). Keep comments slim; do not duplicate full PR bodies, verification matrices, file lists, or retrospective lessons.

## What was removed

The legacy repo-local live boards and checked-in `task_*.md` artifacts were removed by issue #368. The old `task_template.md` and `handoff_template.md` files were already removed by ADR-025. Do not recreate a repo-local live claim board for normal GitHub-connected work.

## Offline or no-GitHub fallback

If GitHub API access is unavailable, temporarily write the same `agent-state:v1` content into a local scratch note. Copy it into the issue or PR comment once access returns. Do not commit local live-state scratch files as the normal coordination path.

## Durable knowledge belongs elsewhere

- Decisions belong in `docs/decisions/<adr>.md`.
- Formal incidents belong in `docs/postmortems/**`.
- Durable session lessons belong in `.context/sessions/latest_summary.md` and archives.
- Operating rules belong in `.context/rules/**`.
