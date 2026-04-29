---
postmortem_number: 002
date: 2026-04-15
source_repo: mikejmckinney/cloud_migration_POC
source_commit: 4943212140cbcec760221ba405b437d678a26771
stacks: []
generalizes: Yes
follow_up_artifact: issue-69
mirror_status: original
---

<!--
Template-authored synthesized backfill, NOT a mirror of an existing
source-repo postmortem. Authored 2026-04-29 in
`mikejmckinney/ai-repo-template` (in #218) from the artifacts of the
cloud_migration_POC incident:

  - Source repo: https://github.com/mikejmckinney/cloud_migration_POC
    (pinned: commit 49432121, default branch as of 2026-04-29)
  - Remediation prompt:
    https://github.com/mikejmckinney/cloud_migration_POC/blob/4943212140cbcec760221ba405b437d678a26771/.github/prompts/07-working-demo-upgrade.md
  - Related issues (referenced from ai-repo-template#150):
    cloud_migration_POC#69, cloud_migration_POC#70

Provenance note: `mirror_status: original` because this file was
authored in the template repo, not copied verbatim from a source-repo
postmortem. The frontmatter `source_repo` / `source_commit` still
point at the project where the *incident* occurred — the schema
documents the incident, the `mirror_status` documents how this file
came to be here. See ADR-015's "Frontmatter schema".

If `cloud_migration_POC` later authors its own postmortem of this
incident (using `capture-postmortem.md`) and mirrors it back via
`mirror-postmortem.md`, that mirror should *supersede* this synthesized
backfill (add a follow-up section here citing the new file; do not
delete this file — immutability rule).

Per docs/postmortems/README.md "Numbering and immutability", the body
is append-only for facts. The project owner is invited to amend with a
"Follow-up" section from lived experience if the synthesis missed
something. Do not rewrite history; add follow-ups.

This is also the first end-to-end run of the procedure introduced by
ADR-015 (capture-postmortem.md → mirror-postmortem.md). See ADR-015
"References" for context.

Verdict-history note: this postmortem was originally filed in commit
45094e9 (#218) with `generalizes: Unclear` and
`follow_up_artifact: issue-219` on the cautious "N=1 = anecdote"
reading. Project owner @mikejmckinney upgraded the verdict to `Yes`
later in #218 because the underlying failure mode (designing around
deliverables instead of user outcomes) is not stack- or
sequence-specific — it can affect any issue type. The design-for-
outcomes follow-ups already exist as ai-repo-template#69 (agent logic
update) / PR #70 and #201 / PR #203, so `follow_up_artifact: issue-69`
points at the canonical originating issue (the others append to that
thread). Conditional issue #219 (re-evaluate after a second
multi-prompt-sequence occurrence) is therefore superseded — the
verdict no longer waits on a second occurrence.

NOTE: frontmatter is intentionally placed at line 1 (above this comment)
so GitHub's Markdown renderer parses it as YAML and shows the styled
table view; HTML comments before the opening `---` would push it past
line 1 and break that rendering.
-->

# Postmortem-002: Prompts 1–6 produced architecture instead of working demo

## Status

Final

## Date

2026-04-15

## Author(s)

Synthesized backfill authored by GitHub Copilot (Claude Opus 4.7) in the
ADR-015 / issue #150 PR, from the artifacts cited in the provenance
header. Project owner @mikejmckinney invited to amend.

## Trigger

A six-prompt sequence (`01-*.md` through `06-*.md`) intended to ship a
working cloud-migration demo for `cloud_migration_POC` instead produced
an architecture/design presentation; the gap was only visible at the
end of prompt 06, after the work was done. Remediation required adding
a seventh prompt — [`07-working-demo-upgrade.md`](https://github.com/mikejmckinney/cloud_migration_POC/blob/4943212140cbcec760221ba405b437d678a26771/.github/prompts/07-working-demo-upgrade.md)
— to convert the architecture artifacts into a runnable demo.

## Context

`mikejmckinney/cloud_migration_POC` is a project bootstrapped from
`mikejmckinney/ai-repo-template`. The intended deliverable was a
"working demo" — something a 15-minute observer could *experience*
running, in line with the Analyst pre-flight gate
([ADR-005](../decisions/adr-005-analyst-preflight-gate.md), broadened
by [ADR-014](../decisions/adr-014-extend-preflight-to-adhoc-deliverables.md)).

The project was decomposed into six numbered prompts under
`.github/prompts/01-*.md` … `06-*.md`. Each prompt was individually
sensible; each was implemented in turn. At the end, the deliverable was
not what the project had asked for — it was a careful architecture
presentation, not a runnable demo.

This is the second mirrored postmortem and the first end-to-end use of
the procedure ratified in [ADR-015](../decisions/adr-015-postmortem-feedback-loop.md).

## What happened

Timeline (reconstructed from the source repo's prompt files and issue
trail; corrections welcome via follow-up section):

1. Master prompt + prompts 01–06 authored to decompose the project into
   stages (typical of the template's `NN-*.md` convention).
2. Each prompt picked up by an agent; each produced its named
   deliverable. Per-prompt outputs reviewed; nothing in any individual
   PR looked obviously wrong.
3. After prompt 06 merged, the cumulative artifact was inspected. It
   was an architecture/design package — diagrams, schemas, runbooks —
   not a runnable demo. The 15-minute test failed: an observer would
   *read about* the migration, not *experience* it.
4. cloud_migration_POC#69 / #70 captured the gap.
5. Remediation: a seventh prompt (`07-working-demo-upgrade.md`) was
   added explicitly to convert the architecture artifacts into running
   code. The original six prompts were not retroactively rewritten.

## Expected vs. Actual

### Expected

Six numbered prompts, executed in sequence by the standard template
agent loop, would converge on a working cloud-migration demo. Each
prompt's pre-flight (ADR-005/014) would catch any individual deliverable
mismatch.

### Actual

Each individual prompt passed pre-flight on its own terms. The
cumulative deliverable was the wrong artifact type entirely — design
output, not running code. Pre-flight fired six times and found nothing
each time, because each prompt's stated outcome (e.g., "produce
architecture diagrams for stage N") was honest about what *that prompt*
would produce. No gate evaluated whether `prompt_01 + … + prompt_06 = a
runnable demo`.

### Gap

The pre-flight gate evaluates **per-prompt** outcomes. It does not
evaluate **per-sequence** outcomes. A multi-prompt sequence can pass
every pre-flight check individually and still produce the wrong
end-state, because no single prompt is responsible for the end-state's
shape.

## Root cause

The Analyst pre-flight gate, as designed in ADR-005 and broadened by
ADR-014, runs at issue / prompt level. The 15-minute test asks "would
the user *experience* the outcome of *this issue*" — which is the
correct question for any one issue. It is the wrong question for a
sequence of issues whose individual outputs are inputs to the
end-state, not the end-state.

Restated: the gate catches "wrong artifact for this issue." It does not
catch "right artifact for each issue, but the union is the wrong
deliverable type." When a project is decomposed into N prompts whose
outputs are intermediate (architecture, schema, plan) rather than
terminal (running code), every individual pre-flight will pass even if
the sequence converges on the wrong thing.

## Contributing factors

- Numbered-prompt decomposition (`NN-*.md`) makes intermediate
  artifacts feel like deliverables in their own right. Each one has an
  Analyst pre-flight, an issue, and a PR — the per-prompt ceremony
  obscures that the *project* deliverable hasn't been verified.
- The template's own conventions reward this decomposition (it's how
  `repo-onboarding.md` Phase 0 talks about project prompts), so an
  agent following the conventions has no signal that "decompose into
  prompts" might itself be the failure mode.
- "Architecture first, code later" is a defensible engineering
  approach in many contexts — the failure mode here is not the
  approach but the absence of a checkpoint that confirms the
  transition from "later" to "now."

## What worked

- The remediation prompt approach (`07-working-demo-upgrade.md`)
  successfully converted the architecture artifacts into a running
  demo without requiring the original prompts to be rewritten or the
  work to be discarded. The recovery cost was bounded.
- The numbered-prompt convention made the gap diagnosable: it was easy
  to see "we have 06 deliverables, none of which is a demo." A more
  ad-hoc decomposition would have made the gap harder to localize.
- The Analyst pre-flight gate itself is not the bug — it caught nothing
  here, but only because the question it asks is correctly scoped to
  individual issues. The gate did not produce a false positive.

## What generalizes

**Status**: `Yes` (universal — not stack- or sequence-specific).

The candidate lesson generalizes to **any work whose definition is
phrased as a list of deliverables rather than a user outcome**. The
multi-prompt-sequence shape is one expression of the failure mode,
but not the failure mode itself. Per-prompt pre-flight passed six
times here because each prompt's stated outcome ("produce architecture
for stage N") was honest about what *that prompt* would produce. The
gap was that the **project** was never expressed as an outcome a user
would experience — only as a sequence of deliverables.

The same shape applies to single-issue work, multi-PR features,
epic-style backlogs, and any other unit where the work definition
lists artifacts ("build X, Y, Z") instead of user actions ("a user
will be able to do A in 15 minutes"). Wherever the definition is
deliverable-shaped, the verification gate has nothing to check
against beyond "did the artifact get produced," which is the wrong
question.

**Why `Yes` rather than `Unclear`** (verdict upgraded in #218): the
original `Unclear` filing reasoned from N=1 of the
multi-prompt-sequence shape. That framing was too narrow. The actual
generalizable lesson — "design for outcomes, not deliverables" — was
already being addressed by ai-repo-template#69 (agent logic update to
ensure prompts describe user outcomes) / PR #70 and #201 / PR #203
before postmortem-002 was even filed. Those follow-ups exist *because*
the pattern recurs across issue types, not just multi-prompt
sequences. The verdict was upgraded to match what the existing
follow-ups already imply.

**Follow-up artifact**: `issue-69` is the canonical originating issue
for the design-for-outcomes change; PR #70, #201, and PR #203 build
on it. They collectively codify the rule the Analyst pre-flight gate
already expresses (15-minute test) so that prompt and issue authoring
upstream of the gate produces work definitions the gate can
meaningfully evaluate.

**Multi-prompt-sequence as a sub-case**: per-sequence checkpointing
(verify the cumulative artifact after the last prompt in a sequence)
remains a worthwhile sub-question, but it's a tactic for one shape of
the failure, not the lesson itself. If a future incident shows that
the outcome-framing fix at the issue/prompt boundary is insufficient
for sequences specifically, that's the moment to draft the
per-sequence-checkpoint ADR — not now.

## Action items

- [x] File [issue #219](https://github.com/mikejmckinney/ai-repo-template/issues/219)
      in `ai-repo-template`: "Re-evaluate postmortem-002 if a second
      multi-prompt-sequence deliverable mismatch occurs" — owner:
      @mikejmckinney — filed in #218. **Superseded** by the verdict
      upgrade to `Yes` later in #218; the conditional re-evaluation
      this issue tracked is no longer blocking. Close #219 with a
      pointer to this postmortem's "Verdict-history note" and the
      design-for-outcomes follow-ups below.
- [x] Design-for-outcomes enforcement at the issue / prompt authoring
      layer is tracked by
      [ai-repo-template#69](https://github.com/mikejmckinney/ai-repo-template/issues/69)
      / [PR #70](https://github.com/mikejmckinney/ai-repo-template/pull/70)
      and [#201](https://github.com/mikejmckinney/ai-repo-template/issues/201)
      / [PR #203](https://github.com/mikejmckinney/ai-repo-template/pull/203).
      These predate this postmortem and are the canonical follow-ups;
      the postmortem's role is to provide the worked example that
      explains *why* those changes matter.
- [ ] Cross-link postmortem-002 from `cloud_migration_POC`'s own
      `docs/postmortems/` (if that repo has one) so the source-repo
      record points to this synthesized backfill — owner: @mikejmckinney.
- [ ] (Conditional, lower priority) If a future incident shows that
      design-for-outcomes at the issue / prompt boundary is
      insufficient *specifically* for multi-prompt sequences (i.e.
      every prompt has an honest user outcome and the cumulative
      deliverable is still the wrong shape), draft an ADR adding a
      per-sequence checkpoint to the Analyst pre-flight gate. Until
      that case appears, the issue/prompt-level fix is the canonical
      remediation.

## References

- [`07-working-demo-upgrade.md`](https://github.com/mikejmckinney/cloud_migration_POC/blob/4943212140cbcec760221ba405b437d678a26771/.github/prompts/07-working-demo-upgrade.md) — remediation prompt (pinned to incident commit, matches `source_commit` in frontmatter)
- [cloud_migration_POC#69](https://github.com/mikejmckinney/cloud_migration_POC/issues/69) — gap discovery
- [cloud_migration_POC#70](https://github.com/mikejmckinney/cloud_migration_POC/issues/70) — gap discovery (companion)
- [ai-repo-template#69](https://github.com/mikejmckinney/ai-repo-template/issues/69) / [PR #70](https://github.com/mikejmckinney/ai-repo-template/pull/70) — design-for-outcomes follow-up (canonical)
- [ai-repo-template#201](https://github.com/mikejmckinney/ai-repo-template/issues/201) / [PR #203](https://github.com/mikejmckinney/ai-repo-template/pull/203) — design-for-outcomes follow-up (companion)
- [ai-repo-template#219](https://github.com/mikejmckinney/ai-repo-template/issues/219) — conditional re-evaluation; superseded by the verdict upgrade to `Yes`
- [ADR-005](../decisions/adr-005-analyst-preflight-gate.md) — per-issue pre-flight gate (the gate that did not catch this)
- [ADR-014](../decisions/adr-014-extend-preflight-to-adhoc-deliverables.md) — pre-flight extension
- [ADR-015](../decisions/adr-015-postmortem-feedback-loop.md) — the procedure that produced this mirrored postmortem
- [ai-repo-template#150](https://github.com/mikejmckinney/ai-repo-template/issues/150) — feedback-loop tracking issue
