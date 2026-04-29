---
description: Mirror a downstream-project postmortem into ai-repo-template; refuses to mirror without a same-PR follow-up.
agent: agent
---

# Mirror Postmortem

> **Usage**: Run this prompt against `mikejmckinney/ai-repo-template`
> after a downstream-project postmortem has been authored using
> [`capture-postmortem.md`](./capture-postmortem.md) and merged in the
> source repo. This prompt does NOT author postmortems; it copies an
> already-merged one over and ensures the template-side follow-up
> ships in the same PR.
>
> **Inputs**: the URL of the source-repo postmortem file at the
> commit (or tag) you want to mirror.
>
> **Output**: a single PR against `ai-repo-template` containing
> (a) the mirrored postmortem with a provenance header, (b) an index
> row in `docs/postmortems/README.md`, and (c) the concrete follow-up
> artifact (ADR edit, rules edit, prompt edit, or new ADR file).
>
> **Hard rule**: this prompt refuses to mirror a postmortem that has
> no concrete follow-up. The downstream-mirroring policy in
> `docs/postmortems/README.md` ("Mirroring without a follow-up is not
> permitted — a postmortem alone changes nothing") is enforced
> operationally here.

---

## Phase 1: Validate the source postmortem

Fetch the source file. Verify all of:

- [ ] File path is `docs/postmortems/postmortem-NNN-<slug>.md` in the
      source repo.
- [ ] **Line 1** is `---` after stripping any leading UTF-8 BOM
      (the three bytes `\xEF\xBB\xBF` / octal `\357\273\277`; some
      editors, especially on Windows, emit one). Strip the BOM
      before checking, exactly as `test.sh` does — a file that
      passes the template's own CI validator is valid here too. No
      **other** leading content (blank lines, HTML/Markdown comments)
      is tolerated. The frontmatter block must run
      to a closing `---` and match the schema in
      `capture-postmortem.md` Phase 3a.
- [ ] `generalizes:` is `Yes` or `Unclear`. **Stop here if `No`** —
      project-specific lessons stay in the source repo. Mirroring a
      `No` postmortem violates the schema's intent. If you believe the
      verdict was wrong, the fix is to amend the source postmortem
      with a follow-up section that re-evaluates, then re-run this
      prompt.
- [ ] `follow_up_artifact:` is not `none` and is not a placeholder.
      If it is `none`, `generalizes` cannot be `Yes` or `Unclear`
      (per `capture-postmortem.md` Phase 3a) — surface the
      inconsistency back to the source-repo maintainer and stop. Do
      not mirror.
      Placeholder strings (case-insensitive match on the value)
      `TBD`, `issue-TBD`, `pr-TBD`, `adr-TBD`, `todo`, `pending`,
      `<...>` (any angle-bracketed token) are rejected with the
      "no mirror without a concrete follow-up" error. Any value not
      matching the POSIX ERE
      `^([Aa][Dd][Rr]-[0-9]+|[Ii][Ss][Ss][Uu][Ee]-[0-9]+|[Pp][Rr]-[0-9]+)$`
      is also rejected. The bracketed character classes are how this
      regex stays case-insensitive in bash `[[ =~ ]]` (POSIX ERE has
      no `(?i)` inline flag), so downstream variants like `adr-015`
      or `pr-123` are accepted and then normalized to canonical
      casing — uppercase `ADR-` / `PR-`, lowercase `issue-` — in
      Phase 3 step 1 below. Note `none` is intentionally **not** in
      this regex: it is rejected by the separate `none`-with-Yes/Unclear
      gate above, and this prompt only mirrors `Yes`/`Unclear` postmortems,
      so a successful mirror by definition has a concrete artifact ID.
      The whole point of this gate is that the follow-up exists *before*
      mirroring; `issue-TBD` is the failure mode this rejects.
- [ ] `mirror_status:` is `original`. If it already starts with
      `mirrored-from:`, the file you fetched is itself a mirror — go
      back upstream to find the original. Mirroring a mirror is not
      supported.
- [ ] The source file's body's "What generalizes" prose verdict
      matches the frontmatter `generalizes:` value.

If any check fails, **stop**. Post a single comment on the source-repo
PR (or, if no PR exists, open an issue on the source repo) explaining
which check failed and how to fix. Do not open a template-side PR.

## Phase 2: Pick the template-side number

Numbers in `mikejmckinney/ai-repo-template`'s `docs/postmortems/` are
independent of the source repo's numbering. Apply the same rule as
`capture-postmortem.md` Phase 2: highest existing + 1, zero-padded.

The mirrored file's filename uses the **template-side** number; the
H1 also uses the template-side number. The body otherwise keeps the
source's narrative content unchanged — see Phase 3 step 3 for the
explicit H1 carve-out, which is the *only* permitted body edit.

## Phase 3: Compose the mirrored file

Create `docs/postmortems/postmortem-NNN-<slug>.md` in the template
with this exact shape — **frontmatter first (line 1), provenance
comment after the closing `---`** so GitHub's Markdown renderer parses
the YAML into the styled table view (HTML comments before the opening
`---` push it past line 1 and break that rendering):

1. The YAML frontmatter as the **first** content in the file (no
   leading blank lines, no leading comment), **modified** from the
   source as follows:
   - `postmortem_number:` — change to the template-side number.
   - `mirror_status:` — change to `mirrored-from:<source-owner>/<source-repo>`.
   - `follow_up_artifact:` — set per the **three-tier rule** below
     (this depends on Phase 5's classification; if you haven't yet
     decided the tier, do that now and come back). Whatever value
     you write here, normalize the casing to canonical form:
     uppercase `ADR-NNN` / `PR-NNN`, lowercase `issue-NNN`. The
     Phase 1 regex accepts case-insensitive variants from the
     source for compatibility, but the mirrored copy is canonical:
     - **Universal lesson** — set to the template-side artifact ID
       you create in Phase 5 (e.g. `ADR-015`, `issue-NNN` filed in
       this PR). Do **not** carry over the source's artifact; that
       was the source-repo follow-up, not the template-side one.
     - **Stack-specific lesson** — keep the source's value
       unchanged. Per Phase 5 the mirror itself + its index row are
       the follow-up; there is no template-side artifact by design,
       and inventing one to satisfy this field would defeat the
       three-tier policy. The source-repo artifact is the canonical
       reference and stays in this field.
     - **Unclear lesson** — set to the `issue-NNN` you file in
       Phase 5 (the conditional re-evaluation issue). Do not carry
       over the source's value; the template-side issue is the
       template's commitment to revisit, not the source's.
   - All other frontmatter fields (`source_repo`, `source_commit`,
     `date`, `stacks`, `generalizes`) **stay identical** to the source.
     They describe the original incident and must not drift.

2. A provenance HTML comment block immediately after the closing
   `---` of the frontmatter — same shape as
   `postmortem-001-workflow-bypass.md`:

   ```
   <!--
   Mirrored from <source-repo> (a project bootstrapped from this template)
   under docs/postmortems/postmortem-NNN-<slug>.md.

   Source URL: https://github.com/<source-repo>/blob/<commit-sha>/docs/postmortems/postmortem-NNN-<slug>.md
   (Pin to a commit SHA, not a branch name — branches are moving refs
   and weaken provenance.)
   Mirrored: YYYY-MM-DD (use current date; in PR for issue #NNN; <any supersession context>).
   Triggered: <ADR-NNN | rule edit | prompt edit | issue #NNN> (pick one and fill).
   Source H1 number: <source-NNN> (renumbered to template-NNN in the H1
   below per Phase 3 step 3 carve-out; recorded here so nothing is lost).

   Per docs/postmortems/README.md "Numbering and immutability", postmortems
   are append-only for facts. The body below is a verbatim copy of the
   source as of the mirror date; if new evidence appears, add a follow-up
   section at the bottom rather than editing the original.

   NOTE: frontmatter is intentionally placed at line 1 (above this comment)
   so GitHub's Markdown renderer parses it as YAML and shows the styled
   table view; HTML comments before the opening `---` would push it past
   line 1 and break that rendering.
   -->
   ```

3. The body — verbatim from the source, with **exactly one permitted
   edit**: the H1 line. Replace `# Postmortem-<source-NNN>: <title>`
   with `# Postmortem-<template-NNN>: <title>` so the H1 number
   matches the filename and the (renumbered) frontmatter
   `postmortem_number:`. Title text stays identical. No other body
   edits are allowed. Do not "improve" wording, fix typos, or
   reformat — the immutability rule applies to mirrors. If the source
   H1 number already matches the template-side number you picked in
   Phase 2 (rare but possible), no edit is needed and "verbatim"
   is fully literal.

   This single carve-out exists because the H1 is part of the body
   *syntactically* but is metadata *semantically* — like the
   `postmortem_number:` frontmatter field, it identifies which file
   in *this* repo's numbering you are reading. Leaving the source
   number in the H1 would create a within-file inconsistency
   (`postmortem_number: 002` in frontmatter, `# Postmortem-001:` in
   the H1) that breaks discoverability for readers who scan H1s.
   Record the original source H1 number in the provenance comment if
   it differs, so nothing is lost.

## Phase 4: Update the index

Add a row to `docs/postmortems/README.md` "Index" table for the new
mirrored file. Then update the "Stack-tagged index" section: for each
tag in the postmortem's `stacks:` list, add a bullet under that
section's matching subheading. Create the subheading if the tag is
new. Format:

```
### terraform
- [postmortem-NNN](./postmortem-NNN-slug.md) — short title (also: aws, bash)
```

For postmortems with `stacks: []` (universal), add them under a
`### (universal)` subheading.

## Phase 5: Draft the follow-up artifact (required, same PR)

`generalizes: Yes` or `Unclear` means the lesson must produce a
concrete change to the template **in this same PR**. Apply the
three-tier policy from `docs/postmortems/README.md` →
"Project-agnostic vs stack-specific vs project-only":

- **Universal lesson** (the postmortem's body explains why this is not
  stack-specific) → either:
  - amend `AGENTS.md` (a single bullet, no per-stack content), or
  - amend a file under `.context/rules/`, or
  - add a new ADR under `docs/decisions/`, or
  - amend a file under `.github/prompts/`.

  Pick the smallest change that captures the rule. Do not bundle.

- **Stack-specific lesson** → **do NOT** amend `AGENTS.md` or
  `.context/rules/`. The follow-up is the mirrored postmortem itself
  + its row in the stack-tagged index. The promotion gate is
  intentional: AGENTS.md must not accumulate per-stack tips. If you
  feel the urge to add a Terraform / Python / Rust / etc. tip to
  AGENTS.md, that's the signal to stop and re-read this section.

- **Unclear** → file an issue in this same PR titled
  `Re-evaluate postmortem-NNN after second occurrence` and link it
  from `follow_up_artifact:`. The issue is the follow-up.

## Phase 6: Open the PR

Title: `docs(postmortems): mirror postmortem-NNN from <source-repo>`

Body must include:

- Source URL (file at commit).
- Verdict: `generalizes: Yes | Unclear`, stacks list.
- Three-tier classification (universal / stack-specific / unclear)
  with a one-sentence justification.
- The follow-up artifact, named.
- Plan-as-comment link if applicable (per `AGENTS.md` plan
  requirement; this counts as a non-trivial change).

Open the PR. Do not merge until the source-repo PR is also merged
(provenance header references the source commit, which must exist on
the source repo's default branch).

## Phase 7: Resolution Report

Post a comment on the template PR with:

```
### Postmortem mirrored

- Source: <source-repo>#postmortem-NNN-<slug>
- Template file: `docs/postmortems/postmortem-NNN-<slug>.md`
- Tier: <universal | stack-specific | unclear>
- Stacks: <list, or "(universal)">
- Follow-up artifact: <named, with link>
```

This is the audit trail for the sync-back step.
