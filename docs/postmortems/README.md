# Postmortems / Lessons Learned

> **Purpose**: Durable record of "this happened, here's what we learned." ADRs
> capture *prospective* design decisions; postmortems capture *retrospective*
> outcomes — incidents, surprises, friction, things that didn't work the way
> the ADR predicted.

Postmortems are the second half of the feedback loop. An ADR says "we will do
X because we expect Y." A postmortem says "we did X, and what actually
happened was Z." Without the second half, the same mistakes recur.

## Index

| Postmortem | Title | Date | Generalizes? |
|---|---|---|---|
| _(none yet)_ | | | |

When you add a new postmortem, add a row above. The "Generalizes?" column is
the only one that affects the template — see "What generalizes" below.

## When to write a postmortem

Write one whenever:

- A production incident or near-miss happened (downtime, data loss, security exposure, broken release).
- A design decision (ADR or otherwise) produced a materially different outcome than predicted — better or worse.
- A workflow, process, or rule consistently produced friction across multiple sessions.
- A "this took way longer than expected" task finished, and the reasons are non-obvious.
- A rollback or supersession happened (the supersession ADR captures *what* changed; the postmortem captures *why we got it wrong the first time*).

Don't write one for: routine bug fixes, individual frustrations without a pattern, or anything that resolves with "the existing process worked." Postmortems are expensive to read; the bar for writing one is "future-me would benefit."

## Postmortem vs. ADR

| | ADR | Postmortem |
|---|---|---|
| **Tense** | Future ("we will") | Past ("we did") |
| **Trigger** | A decision needs to be made | A decision had a consequence worth recording |
| **Updates in place?** | No — supersede with a new ADR | No — append a follow-up postmortem if new info appears |
| **Affects template?** | Yes, via the rules/prompts the ADR ratifies | Only if "What generalizes" is filled in *and* an ADR/rule/prompt change ships in the same PR |

A postmortem alone changes nothing. To affect the template, the postmortem
must produce a follow-up: a new ADR, a rule update, a prompt edit, or a
deletion. Otherwise it's a journal entry.

## What generalizes

The most important field in the template (and the one most often skipped).
Honestly answer: does this lesson apply to other projects, or only this one?

- **Generalizes** → file a follow-up issue or PR that turns the lesson into a rule, prompt, or ADR update. Mark "Generalizes? Yes" in the index. The postmortem itself doesn't change the template; the follow-up does.
- **Doesn't generalize** → say so explicitly. "Doesn't generalize" is a perfectly valid answer; most lessons are project-specific. The honesty matters because future readers won't waste time looking for actionable guidance that isn't there.
- **Unclear** → say "unclear, revisit after N more occurrences." A pattern that appears once is an anecdote.

## Numbering and immutability

Sequential, zero-padded: `postmortem-001-short-title.md`, `postmortem-002-...`, …

Once posted, postmortems are **append-only for facts**. You may:

- Add a "Follow-up" section at the bottom with new evidence or outcomes.
- File a *new* postmortem that supersedes an old conclusion (`Supersedes
  postmortem-NNN`), same discipline as ADR supersession.

You may **not** rewrite history. If the original postmortem was wrong,
say so in the follow-up — don't pretend the wrong conclusion never existed.
The wrong-conclusion-and-correction is itself a useful artifact.

## What a well-written postmortem looks like

Use the template (`postmortem-template.md`) as the schema. The fields that
matter most:

- **Trigger** — one sentence; what happened that prompted writing this.
- **Expected vs. Actual** — the gap is the lesson. If they match, you're writing a status report, not a postmortem.
- **Root cause** — *why* the gap existed, not what broke. "Code path X had a bug" is not a root cause; "the test we relied on didn't exercise the worktree case" is.
- **What generalizes** — see above. Required field; "doesn't generalize" is a valid answer.
- **Action items** — concrete follow-ups with owners and links. An action item without a link to an issue/PR is a wish.

If your postmortem is missing one of these, the postmortem isn't done.

## Relationship to other artifacts

- **Sessions** (`.context/sessions/`) — running session summaries. Postmortems are the formal version when a session summary surfaces a pattern worth preserving.
- **ADRs** (`docs/decisions/`) — prospective. A postmortem may *trigger* a new ADR (or supersede one), but lives separately.
- **Rules** (`.context/rules/`) — prescriptive. A postmortem may justify a new rule, but the rule lives there, not here.
- **Issues** — operational. A postmortem may file an issue for follow-up, but is not itself an issue.

## Downstream-project lessons (future)

The postmortem schema is intentionally project-agnostic so it can also
capture lessons from projects built *from* this template. The mechanism
for collecting those lessons doesn't exist yet — see
[issue #150](https://github.com/mikejmckinney/ai-repo-template/issues/150)
for the planned feedback loop (registry, opt-in, promotion gate). Until
that mechanism ships, this directory holds postmortems about the
template itself only.
