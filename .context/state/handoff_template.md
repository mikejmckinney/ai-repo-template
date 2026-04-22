# Handoff: [task-id]

> **Purpose**: Compact handoff between sessions or between roles. Use when
> a single agent conversation exceeds ~30 turns OR before any handoff to a
> different role/agent. Replaces "let me dump my entire chat history" with a
> structured baton-pass.
>
> **File name**: `handoff_<slug>.md` in `.context/state/`. Delete or move to
> `.context/sessions/` once the receiving role has read it and updated
> `_active.md`.

**Task ID**: <!-- e.g. login-backend, pr-98-followup -->
**From role**: <!-- analyst | architect | judge | critic | pm | frontend | backend | qa | devops | docs -->
**To role**: <!-- same shape; or "self / next session" -->
**Date**: YYYY-MM-DD
**Branch**: <!-- e.g. feature/backend-login; "none" if not on a branch yet -->

## Decisions made (and why)

<!-- 3-7 bullets max. Each bullet: the decision + the one-line rationale.
     Cite file:line for any decision grounded in the repo. -->

- <decision> — <why> — <source: path/to/file.md:NN>

## Files touched

<!-- Each: path + one-line purpose. Skip if zero files touched (planning
     handoff). -->

| File | Change |
|------|--------|
| `path/to/file` | <one-line summary> |

## Open questions / blockers

<!-- Things the receiver needs an answer or external input for. If empty,
     write "None". -->

- <question or blocker>

## Recommended next step

<!-- One sentence. The receiver should be able to start work after reading
     this section alone. -->

<next step>

## Source links (for the receiver)

<!-- Direct links into the repo or to external resources the receiver will
     need. Cite line numbers where precision matters. -->

- `path/to/relevant/file.md` (or `path/to/file.ts:42`)
- ADR / issue / PR reference

## Verification commands run

<!-- Commands the giver actually ran, with pass/fail. Skip if none. -->

- `command` — pass / fail / not run
