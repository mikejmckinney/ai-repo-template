---
description: Capture a postmortem in the current (downstream) repo using the ai-repo-template schema.
agent: agent
---

# Capture Postmortem

> **Usage**: Run this prompt in the **downstream project repo** (the one
> built *from* `mikejmckinney/ai-repo-template`), NOT in the template
> itself. The output is a new file at
> `docs/postmortems/postmortem-NNN-<slug>.md` in the project repo.
>
> If you are already inside `mikejmckinney/ai-repo-template` and the
> incident is template-internal, the same procedure applies; skip the
> sync-back step (Phase 5) — there is nothing to mirror.
>
> **When to invoke**: a maintainer (human or agent) decides an incident
> matches one of the criteria in the template's
> `docs/postmortems/README.md` → "When to write a postmortem". Agents
> may *suggest* invoking this prompt when those criteria match, but
> should not author a postmortem unsolicited; postmortems are
> expensive to read, the bar is "future-me would benefit."

You are about to capture a postmortem. Do not write the postmortem
free-hand. Walk this prompt end to end, in order. Each phase has a
verification step; do not advance until it passes.

---

## Phase 1: Confirm the incident warrants a postmortem

Read `docs/postmortems/README.md` → "When to write a postmortem"
(present in this repo if it was bootstrapped from `ai-repo-template`;
if the file is missing, fetch the canonical version from
[`mikejmckinney/ai-repo-template`](https://github.com/mikejmckinney/ai-repo-template/blob/main/docs/postmortems/README.md)).

State, in one sentence, which criterion this incident matches. If none
matches, **stop**. Do not write a postmortem; surface the decision back
to the requester with a one-line explanation. The "this is interesting"
threshold is intentionally lower than "warrants a postmortem."

## Phase 2: Pick the next postmortem number and slug

1. List `docs/postmortems/postmortem-[0-9][0-9][0-9]-*.md` in this
   repo (the numeric pattern excludes `postmortem-template.md` so it
   doesn't get parsed as a sequence number).
2. The new number is the highest existing + 1, zero-padded to three
   digits (`001`, `002`, ...).
3. Slug: 2–5 words, kebab-case, descriptive of the gap (not the fix).
   Good: `workflow-bypass`, `outcome-mismatch`, `migration-rollback`.
   Bad: `bug-fix`, `incident`, `lessons-learned`.

## Phase 3: Author the postmortem

Copy the template body from
`docs/postmortems/postmortem-template.md` (or fetch from the canonical
template repo if absent locally) into
`docs/postmortems/postmortem-NNN-<slug>.md`. Fill **every** section.

### Phase 3a: YAML frontmatter (required)

The **first line** of the file must be `---` (no leading blank lines,
no leading HTML/Markdown comment, no shebang). The validator in
`test.sh` (ADR-015 frontmatter check) hard-fails any postmortem whose
line 1 is not `---`, so anything else here will be rejected by CI even
if it parses as YAML. The full block:

```yaml
---
postmortem_number: NNN
date: YYYY-MM-DD
source_repo: <owner>/<repo>
source_commit: <sha-at-time-of-incident>
stacks: []
generalizes: Yes | No | Unclear
follow_up_artifact: <ADR-NNN | issue-NNN | PR-NNN | none>
mirror_status: original
---
```

Field rules — every field is required:

- **`postmortem_number`** — matches the `NNN` in the filename and the H1.
- **`date`** — date the incident occurred, not the date you wrote this
  up. ISO 8601 (`YYYY-MM-DD`).
- **`source_repo`** — `<owner>/<repo>` of the project where the incident
  happened. For postmortems authored in this repo, that's this repo.
- **`source_commit`** — short or full SHA of the commit that best
  represents the incident state. Use `git log` to find it; do not
  invent.
- **`stacks`** — YAML list of technology / domain tags that scope this
  lesson. Use lowercase, kebab-case. Examples: `[terraform, aws]`,
  `[python, fastapi, postgres]`, `[github-actions, bash]`. **Empty
  list `[]`** means "applies regardless of stack" — only use this if
  truly universal. If the lesson only makes sense to readers using a
  specific tool, name the tool.
- **`generalizes`** — see Phase 3c. The verdict here must match the
  body's "What generalizes" section.
- **`follow_up_artifact`** — the ID of the concrete change this
  postmortem produces. If `generalizes: Yes` or `Unclear`, this MUST
  NOT be `none` and MUST NOT be a placeholder — file the actual
  follow-up issue (or open the actual ADR PR) **before** committing
  the postmortem and use its real ID. Acceptable shapes:
  `ADR-NNN`, `issue-NNN`, `PR-NNN`, or `none` (only when
  `generalizes: No`). Casing matters for downstream consumers: use
  uppercase `ADR-` and `PR-` and lowercase `issue-` exactly as shown.
  `mirror-postmortem.md` Phase 1 accepts case-insensitive variants
  for compatibility but normalizes to this canonical form when it
  mirrors back, so authoring it correctly here avoids needless
  drift. Placeholders like `issue-TBD`, `TBD`, `todo`, `pending`,
  `pr-TBD`, `adr-TBD`, `<...>` are rejected by
  `mirror-postmortem.md` Phase 1; that rejection is the gate, not a
  suggestion. If `generalizes: No`, `none` is acceptable.
- **`mirror_status`** — `original` for postmortems authored here.
  `mirrored-from:<owner>/<repo>` is set later, by `mirror-postmortem.md`,
  in the template-side mirror copy — never set it manually.

### Phase 3b: Fill the body

Follow the inline guidance in `postmortem-template.md`. Resist these
common shortcuts:

- "Code path X had a bug" is not a root cause; keep asking "and why?"
  until you reach a process / assumption / verification gap.
- The "What worked" section is not optional padding. Naming what worked
  prevents the next response from accidentally regressing on it.
- Action items without a linked issue / PR are wishes. File the issues
  before declaring the postmortem done.

### Phase 3c: The "What generalizes" decision (required, do not skip)

This is the only field in the postmortem that can affect other
projects. Three honest answers:

- **Yes** — the lesson applies to other repos *regardless of stack*
  (e.g., a workflow rule, a missing precondition in agent prompts, a
  documentation pattern). This is rare. Yes triggers Phase 5
  (sync-back to template) and requires `follow_up_artifact != none`.
- **Yes, stack-specific** — the lesson applies to other repos *that
  use the same stack* (e.g., "Terraform `for_each` on data sources
  evaluates lazily; assume nothing is materialized at plan time"). The
  `stacks:` field is what makes this discoverable. This still triggers
  Phase 5 — the postmortem is mirrored — but the follow-up artifact
  does NOT modify AGENTS.md or `.context/rules/`. It stays in the
  postmortem; future projects find it via the stack-tagged index.
  Mark `generalizes: Yes` and explain the stack scope in the body.
- **No** — project-specific. Stays in this repo. Do not mirror.
- **Unclear** — say so explicitly. State the form a confirming second
  occurrence would take ("if this happens again on a non-`for_each`
  resource, it generalizes"). Marking everything `Yes` to avoid the
  decision is the failure mode this gate exists to prevent.

The body's prose verdict must match the frontmatter `generalizes:`
value. Mismatches block the next phase.

## Phase 4: Self-check before posting

Verify all of:

- [ ] Filename matches frontmatter `postmortem_number` and H1 title number.
- [ ] Frontmatter has all 8 fields, none empty (use `[]` and `none`
      explicitly when applicable).
- [ ] Every body section has content; no `<!-- … -->` template
      comments left in their raw form.
- [ ] "Action items" has at least one item with a linked issue or PR.
- [ ] If `generalizes: Yes` **or** `Unclear`, `follow_up_artifact != none`
      and is not a placeholder (`TBD`, `issue-TBD`, `pr-TBD`, `adr-TBD`,
      `todo`, `pending`, `<...>`). File the real issue/ADR/PR first,
      then commit the postmortem with its real ID. This mirrors the
      `mirror-postmortem.md` Phase 1 gate so template-internal
      postmortems (which never run mirror validation) still get caught.
- [ ] `follow_up_artifact` matches the canonical schema regex
      `^(ADR-[0-9]+|issue-[0-9]+|PR-[0-9]+|none)$` (strict casing).
      `test.sh` validates committed postmortems with the same strict
      pattern, so non-canonical forms like `adr-015` or `Pr-10` that
      mirror-postmortem.md would accept from a source repo will be
      **rejected by CI** in this repo. Write canonical casing here
      from the start: uppercase `ADR-` / `PR-`, lowercase `issue-`
      and `none`. Malformed forms like `issue69` (missing hyphen),
      `ticket-12` (wrong noun), or `ADR15` (missing hyphen) must
      also fail this check. Template-internal postmortems skip
      `mirror-postmortem.md` Phase 1, so this is the only gate
      before downstream tooling and queries see the value.
- [ ] "Trigger" is one sentence.
- [ ] "Expected vs Actual" is non-trivial — if Expected and Actual
      match, you do not have a postmortem; stop.

If any item fails, fix before committing.

Commit on a branch following the project's branch-naming policy. In
repos that adopt the `ai-repo-template` AGENTS.md work-style rule, that
means `feature/docs-postmortem-NNN-<slug>` (Docs is the owning role for
postmortem files) or `fix/<issue>-postmortem-NNN-<slug>` if the
postmortem is filed in response to a tracked incident. Do not invent a
`postmortem/...` prefix — it is not in the AGENTS.md branch grammar and
will fail review. Open a PR in **this** repo (the project repo, not the
template), and request review.

## Phase 5: Sync-back decision (only if generalizes is Yes / Unclear)

- **`generalizes: No`** → done. Merge in this repo. Do not mirror.
- **`generalizes: Yes` or `Unclear`** → after the source-repo PR is
  merged, run [`mirror-postmortem.md`](./mirror-postmortem.md) against
  `mikejmckinney/ai-repo-template`. That prompt validates frontmatter,
  copies the postmortem with a provenance header, and opens the
  template-side PR with the drafted follow-up artifact in the same PR.
  Do not mirror by hand — the prompt's validation gate exists to
  enforce the "no mirror without a follow-up" rule from the template's
  postmortem README.

## Phase 6: Resolution Report

Post a comment on the project-repo PR with:

```
### Postmortem captured

- File: `docs/postmortems/postmortem-NNN-<slug>.md`
- Generalizes: <Yes | No | Unclear>
- Stacks: <comma-separated list, or "(universal)">
- Follow-up: <ADR / issue / PR / none>
- Sync-back: <not applicable | pending mirror-postmortem.md run | template PR #NNN>
```

The report is the audit trail for whether this incident did or did not
flow back to the template.
