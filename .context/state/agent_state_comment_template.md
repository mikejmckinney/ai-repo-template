# `agent-state:v1` comment template

Copy this template into a comment on the GitHub issue or PR you're
working from. Keep **one** latest comment per work item current —
update it instead of scattering live state across multiple repo-local
files. The HTML comment marker is what makes the comment discoverable
to humans and (eventually) tooling.

The template is intentionally slim. Long decision history, full file
lists, verification matrices, and durable retrospective lessons stay
out of this comment — those belong in plan comments, PR bodies, ADRs,
CI, and `.context/sessions/latest_summary.md` respectively.

There is no separate `Pause reason` field; `Status:` already carries
that signal and a second field invites contradiction.

## Template

```markdown
<!-- agent-state:v1 issue:NNN pr:MMM branch:feature/example role:devops -->

**Status:** in_progress | awaiting_user_input | blocked | awaiting_review | handoff_needed | done
**Updated:** YYYY-MM-DDTHH:MM:SSZ

## Since last update
- ...

## Blockers / awaiting
- None

## Next 1–3 actions
1. ...

## Handoff
**To:** self / next session / analyst / architect / judge / critic / pm / frontend / backend / qa / devops / docs

<Only fill when pausing, transferring ownership, or leaving work. One or two sentences max.>
```

## When to update

Per `.context/rules/process_session_state.md`:

- **Task start.** Post or update the comment with `Status: in_progress`,
  the branch, and your initial Next 1–3 actions.
- **Every wait-for-input pause, no exceptions.** Includes mid-task
  clarification, plan-mode approval, review-feedback waits, and
  "task done, what's next?" pauses. Refresh `Since last update`,
  `Blockers / awaiting`, and `Next 1–3 actions` before waiting.
- **Durability-risk boundaries.** Refresh `Handoff` before proceeding
  when the conversation exceeds ~30 turns, the runtime auto-summarizes
  mid-flight, the session ends mid-task, or work moves to a different
  role/agent.
- **Closeout.** Set `Status: done` when the agent has fully left the
  work. Durable retrospective lessons land in
  `.context/sessions/latest_summary.md` at PR merge/closeout.

## Coarse labels (v1)

- `agent:claimed` — a role has the work item in active progress.
- `agent:blocked` — work is paused on an external dependency or
  decision.
- `agent:awaiting-review` — work is paused waiting for human/judge/critic
  review.

The `Status:` field carries finer-grained state. Promote new labels
only when a workflow or filter actually needs them.

## Fallback when GitHub is unavailable

If the API is briefly unreachable, write the same template body into a
local scratch note. Copy it into the issue/PR comment once access
returns. Do **not** commit local live-state scratch files as the
normal coordination path.

See [`docs/decisions/adr-025-github-first-agent-state.md`](../../docs/decisions/adr-025-github-first-agent-state.md)
for the full design rationale.
