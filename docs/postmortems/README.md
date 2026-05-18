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
| [postmortem-001](./postmortem-001-workflow-bypass.md) | Workflow bypass on Phases 2–7 (downstream `cmmc-level2-aws-enclave-reference2`) | 2026-04-24 | Yes — triggered [ADR-012](../decisions/adr-012-explicit-workflow-preconditions.md) |
| [postmortem-002](./postmortem-002-poc-outcome-mismatch.md) | Prompts 1–6 produced architecture instead of working demo (downstream `cloud_migration_POC`) | 2026-04-15 | Yes — design-for-outcomes enforcement (#69 / PR #70, #201 / PR #203); supersedes [#219](https://github.com/mikejmckinney/ai-repo-template/issues/219) |
| [postmortem-004](./postmortem-004-opportunity-feedback-channel.md) | Delivering the opportunity feedback channel (issue #337) | 2026-05-18 | Yes — triggered [ADR-027](../decisions/adr-027-opportunity-feedback-channel.md) |

When you add a new postmortem, add a row above. The "Generalizes?" column is
the only one that affects the template — see "What generalizes" below.

## Stack-tagged index

Mirrored postmortems are grouped here by the `stacks:` tags in their YAML
frontmatter so that an agent onboarding into a project using stack X can
scan for prior lessons. This index is hand-maintained on each mirror PR
(see ADR-015 — auto-generation deferred).

If your project uses one of the stacks below, read the listed postmortems
before starting non-trivial work in that stack.

### (universal)

- [postmortem-002](./postmortem-002-poc-outcome-mismatch.md) — Prompts 1–6 produced architecture instead of working demo (also: prompt-engineering, multi-prompt-sequence)

### github-actions

- [postmortem-001](./postmortem-001-workflow-bypass.md) — Workflow bypass on Phases 2–7 (also: bash)

### bash

- [postmortem-001](./postmortem-001-workflow-bypass.md) — Workflow bypass on Phases 2–7 (also: github-actions)

### prompt-engineering

- [postmortem-002](./postmortem-002-poc-outcome-mismatch.md) — Prompts 1–6 produced architecture instead of working demo (also: multi-prompt-sequence)

### multi-prompt-sequence

- [postmortem-002](./postmortem-002-poc-outcome-mismatch.md) — Prompts 1–6 produced architecture instead of working demo (also: prompt-engineering)

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

## Downstream-project lessons

The postmortem schema is intentionally project-agnostic so it can also
capture lessons from projects built *from* this template. The v1
procedure (manual, prompt-driven; see [ADR-015](../decisions/adr-015-postmortem-feedback-loop.md))
uses two prompts:

- **In the downstream project** — run
  [`.github/prompts/capture-postmortem.md`](../../.github/prompts/capture-postmortem.md).
  Walks the agent through the template, forces an explicit
  `What generalizes` decision, requires the YAML frontmatter (incl.
  stack tags) introduced by ADR-015.
- **Mirroring back to the template** — run
  [`.github/prompts/mirror-postmortem.md`](../../.github/prompts/mirror-postmortem.md).
  Validates the source frontmatter, refuses to mirror without a
  concrete same-PR follow-up, copies the body verbatim with a
  provenance header, and updates the stack-tagged index above.

Mirroring without a follow-up is not permitted — per "What generalizes"
above, a postmortem alone changes nothing. The mirror prompt enforces
this operationally; do not work around it by editing files by hand.

### Project-agnostic vs stack-specific vs project-only lessons

Every mirrored postmortem must classify into one of three tiers. ADR-015
records the rationale; the operational rules:

- **Universal** — lesson applies to every repo built from the template,
  regardless of stack. Follow-up artifact is an edit to `AGENTS.md`,
  `.context/rules/`, a prompt under `.github/prompts/`, or a new ADR.
  The mirrored postmortem documents the incident; the rule lives in
  the conventional surface.
- **Stack-specific** — lesson applies only to repos using the named
  stack(s) in `stacks:`. Follow-up is the mirrored postmortem itself
  plus its row in the stack-tagged index above. **Does NOT** modify
  `AGENTS.md` or `.context/rules/`. This boundary is load-bearing —
  see ADR-015. If you find yourself wanting to add a Terraform /
  Python / Rust / etc. tip to AGENTS.md, that is the signal to stop
  and re-read this section.
- **Project-only** — lesson is specific to the source project's
  domain, data, or compliance regime. Stays in the source repo's
  postmortem. Not mirrored.

When the classification is genuinely unclear, use `generalizes: Unclear`
in the frontmatter and file an issue titled
`Re-evaluate postmortem-NNN after second occurrence` as the follow-up.
