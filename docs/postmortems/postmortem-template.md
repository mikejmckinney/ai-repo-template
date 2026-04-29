---
postmortem_number: NNN
date: YYYY-MM-DD
source_repo: <owner>/<repo>
source_commit: <sha-at-time-of-incident>
stacks: []
generalizes: No
follow_up_artifact: none
mirror_status: original
---

<!--
Postmortem / Lessons Learned Template
Copy this file and rename to postmortem-NNN-short-title.md, where NNN is
the zero-padded three-digit sequence number (for example: 001, 002, …).
Use the same NNN value in the frontmatter, H1 title, and the filename.
Title: short, descriptive ("docs sync drift", "auth migration rollback", …)

The YAML frontmatter block above is REQUIRED. The schema is defined in
ADR-015 and enforced by test.sh. Do not omit fields; use the explicit
empty value (`[]` for stacks, `none` for follow_up_artifact when
generalizes is No) rather than deleting the line.

For walkthrough guidance, run `.github/prompts/capture-postmortem.md`.

Default values above pair `generalizes: No` with `follow_up_artifact: none`
because that is the only internally consistent placeholder combination
(capture-postmortem.md Phase 3a: if `generalizes` is `Yes` or `Unclear`,
`follow_up_artifact` MUST NOT be `none`). On a real postmortem you will
almost always change both — set `generalizes` honestly per Phase 3c, then
set `follow_up_artifact` to a concrete ID (e.g. `ADR-NNN`, `issue-NNN`,
`PR-NNN`). Placeholder strings like `TBD`, `issue-TBD`, `todo` are
rejected by `mirror-postmortem.md` Phase 1.

NOTE: frontmatter is intentionally placed at line 1 (above this comment)
so GitHub's Markdown renderer parses it as YAML and shows the styled
table view; HTML comments before the opening `---` would push it past
line 1 and break that rendering.
-->

# Postmortem-NNN: [Title]

## Status

<!-- One of: Draft | Final | Superseded by postmortem-NNN -->

Draft

## Date

<!-- Date the incident or surprise occurred. Use the actual event date,
     not the date the postmortem was written. -->

YYYY-MM-DD

## Author(s)

<!-- Who wrote this postmortem. If multiple agents/people contributed,
     list all of them. The author is accountable for the "What generalizes"
     verdict. -->

## Trigger

<!-- One sentence: what happened that prompted writing this postmortem?
     Examples:
     - "Production database lost 3 hours of writes after a botched migration."
     - "auto-resolve-on-merge.yml ran for months without ever doing anything."
     - "The 'small refactor' to extract auth helpers took 4 days instead of 4 hours." -->

## Context

<!-- What system, project, or process is this about? Enough background
     for a future reader who wasn't here to understand the rest. Cite
     the relevant ADR(s), issue(s), or PR(s). -->

## What happened

<!-- Timeline of the actual events. Be factual; save interpretation for
     "Root cause." Include timestamps if relevant.

     This section is the *what*. Resist the urge to explain *why* here. -->

## Expected vs. Actual

<!-- The gap is the lesson.

     - **Expected**: what the team / ADR / plan predicted would happen.
     - **Actual**: what actually happened.

     If these match, you're writing a status report, not a postmortem.
     Don't write one. -->

### Expected

### Actual

### Gap

<!-- Stated plainly: what was the predictive failure? -->

## Root cause

<!-- *Why* the gap existed. Go past the proximate cause.

     "Code path X had a bug" is not a root cause.
     "The test we relied on didn't exercise the worktree case, because
      we wrote the test from documentation rather than verifying with
      a real worktree" is a root cause.

     If you can answer "and why?" one more time and get a more useful
     answer, you haven't reached the root yet. -->

## Contributing factors

<!-- Things that didn't cause the gap on their own but made it more
     likely or harder to catch. Optional but valuable.

     Examples:
     - Documentation said one thing, code did another.
     - The reviewer who would have caught this was on PTO.
     - The tooling for verifying X is awkward, so people skip it. -->

## What worked

<!-- What did NOT go wrong, and is worth preserving? Postmortems often
     focus only on failures and lose track of the parts of the response
     that should be repeated. -->

## What generalizes

<!-- REQUIRED. The most important field in this template.

     Honestly answer: does this lesson apply to other projects, or only
     this one?

     - **Generalizes** → describe the pattern in general terms (not the
       specifics of this incident), and link to the follow-up issue / PR
       / ADR that turns the lesson into a rule, prompt, or template
       change. The postmortem alone changes nothing.

     - **Doesn't generalize** → say so explicitly. State why the
       circumstances were specific. This is a valid answer; saying so
       saves future readers from looking for actionable guidance that
       isn't there.

     - **Unclear** → say "unclear, revisit after N more occurrences." A
       pattern that appears once is an anecdote. -->

**Status**: `[Yes | No | Unclear]`

<!-- Use this value in the index row in docs/postmortems/README.md. -->

## Action items

<!-- Concrete follow-ups with owners and links. An action item without
     a link to an issue / PR is a wish. -->

- [ ] [Action] — owner: @handle — issue: #NNN
- [ ] [Action] — owner: @handle — issue: #NNN

## References

<!-- Links to relevant ADRs, issues, PRs, runbooks, external docs.
     If this postmortem supersedes another, cite it here. -->

- [Link 1]
- [Link 2]
