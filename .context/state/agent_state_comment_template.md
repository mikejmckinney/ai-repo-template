<!--
.context/state/agent_state_comment_template.md
================================================

Canonical copy/paste template for the live `agent-state:v1` coordination
comment introduced by ADR-025 (issue #298).

WHO READS THIS FILE:
- Agents starting/continuing work on a GitHub issue or PR — copy the body
  below into a new comment on the issue (or the PR once it exists), then
  edit the placeholders.
- Future automation that parses the `agent-state:v1` HTML-comment marker.
  Keep the marker line stable; everything below it is editable prose.

WHO DOES *NOT* READ THIS FILE:
- The Analyst / Judge / Critic gates. They read the GitHub issue body
  (the `feature_request.md` template) and the PR body. This template is
  for live coordination only — never put gate inputs here.

CADENCE (mirrors `.context/rules/process_session_state.md`):
- Post or update at task start.
- Update at every wait-for-input pause, no exceptions (clarification
  questions, plan-mode approval pauses, review-feedback pauses, "what
  next?" pauses). Write now; do not defer until close-out.
- Update the `## Handoff` section before proceeding when ANY of:
    - conversation exceeds ~30 turns;
    - the runtime auto-summarizes mid-flight;
    - the session ends and the task is not yet merged/closed;
    - work moves to a different role/agent.
- Set `Status: done` at close-out. Retrospective lessons land in
  `.context/sessions/latest_summary.md` at PR merge — not here.

ONE COMMENT, NOT MANY:
- Edit the latest `agent-state:v1` comment in place. Do not append a
  fresh one per pause. Use GitHub's comment-edit history if you need
  the prior version.
- If you must post a new one (e.g., the previous comment was hidden
  or you switched issue/PR), the marker line still identifies it as
  "the latest agent-state:v1 comment" — that's what the next session
  reads.

WHAT THIS TEMPLATE DELIBERATELY OMITS:
- Long decision history → plan comments, PR body, ADRs.
- Full file list → PR diff/body.
- Verification matrix → PR body and CI results.
- Durable retrospective lessons → `.context/sessions/latest_summary.md`
  and archives.
- A `Pause reason` field — `Status` already carries that, and a
  separate field would contradict it.

FALLBACK WHEN GITHUB API IS UNAVAILABLE:
- Record the comment body locally (e.g., `/memories/session/agent-state.md`
  or a scratch file) and copy it into the issue/PR comment as soon as
  GitHub is reachable. Do not commit live-state files to the repo as a
  workaround.

-->

# Agent state comment template (`agent-state:v1`)

Copy everything between `--- BEGIN ---` and `--- END ---` into a new
comment on the GitHub issue (or the linked PR once it exists), then
edit the placeholders.

```markdown
--- BEGIN ---
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
--- END ---
```

## Field reference

- **Marker line** (`<!-- agent-state:v1 ... -->`):
  - `issue:NNN` — the GitHub issue this comment lives on or refers to. Use the issue number; write `N/A` if the work has no tracking issue (rare).
  - `pr:MMM` — the linked PR number, or `pending` if the PR doesn't exist yet, or `N/A` if no PR is planned.
  - `branch:feature/...` — the working branch name, or `none` if no branch yet.
  - `role:<role>` — your role per `.agents/<role>.md` (analyst | architect | judge | critic | pm | frontend | backend | qa | devops | docs).
  - Keep this line on a single line; future automation parses it.
- **Status** — agent state, not PR state. The PR's lifecycle lives in GitHub itself (open / merged / closed).
  - `in_progress` — actively working.
  - `awaiting_user_input` — paused for clarification or approval.
  - `blocked` — paused on an external dependency.
  - `awaiting_review` — PR open and waiting on review.
  - `handoff_needed` — done with your slice; next role should pick up.
  - `done` — work fully complete or fully released to a successor.
- **Updated** — ISO-8601 UTC timestamp. Update on every edit.
- **Since last update** — what changed since the previous version of this comment. One or two bullets per chunk of work.
- **Blockers / awaiting** — what's preventing forward motion. `None` is a valid value; don't manufacture blockers.
- **Next 1–3 actions** — what the agent (or successor) should do next. Cap at three to keep the comment scan-friendly.
- **Handoff** — only fill when leaving work. The target role tells the next session who's expected to pick up. The free-text line is the baton: what's the next session's first action.

## Why this template is slim

This is the **live coordination** surface. It deliberately doesn't duplicate:

| What | Where it belongs |
|---|---|
| Durable feature/task contract | GitHub issue body (`feature_request.md`) |
| Plan + design rationale | Plan-as-comment on the issue (per ADR-011) |
| Implementation summary + linked issue + verification | PR body + `pull_request_template.md` |
| File list + diffs | PR diff |
| CI results | PR checks |
| What Shipped / Harder Than Expected / Generalizable Lessons | `.context/sessions/latest_summary.md` and archives |
| ADRs / postmortems / rules | `docs/decisions/`, `docs/postmortems/`, `.context/rules/` |
| Reusable procedures (PR resolution, onboarding, etc.) | `.github/prompts/*.md` |

If you find yourself wanting to add a section here, ask whether it belongs in one of the surfaces above instead.

## See also

- ADR-025 — the GitHub-first agent state model.
- `.context/rules/process_session_state.md` — cadence rules (every wait-for-input pause, ~30-turn handoff, runtime auto-summary, session-end-before-merge).
- `.github/ISSUE_TEMPLATE/feature_request.md` — the durable issue-body contract for Analyst / Judge / Critic gates.
- `.github/pull_request_template.md` — the PR review contract; links the issue, plan, and verification.
- `.context/sessions/README.md` — durable retrospective lessons surface; rotation now keys to PR merge / close-out.
