# Prompt frontmatter audit

> **Status**: Recommendation — **(c) not worth the complexity right now**.
> Keep the existing minimal `description` + `agent` schema documented in
> [`.github/prompts/README.md`](../../.github/prompts/README.md) §"Frontmatter
> schema". Do not add `role`, `requires-preflight`, `requires-plan`, or
> `triggers-gate` fields until a concrete tool needs them.
>
> **Scope**: Item 4 of issue [#226](https://github.com/mikejmckinney/ai-repo-template/issues/226)
> ("Audit `.github/prompts/NN-*.md` for YAML-frontmatter metadata"), broadened
> per the [issue #226 implementation plan](https://github.com/mikejmckinney/ai-repo-template/issues/226#issuecomment-4382960698)
> to cover all `.github/prompts/*.md`, since no `NN-*.md` project prompts
> ship in this template — they are authored downstream per
> [`docs/guides/agent-pipeline.md`](../guides/agent-pipeline.md) §"Authoring
> a project prompt".

## Inventory

`.github/prompts/` ships five prompt files plus a `README.md`. The README is
the documented exception that defines the schema; every other file must
have frontmatter (verified by the bash one-liner in the schema section of
`.github/prompts/README.md`).

| File | `description` (current) | `agent` | Implied role | Pre-flight gate? | Plan gate? |
|---|---|---|---|---|---|
| `capture-postmortem.md` | "Capture a postmortem in the current (downstream) repo using the ai-repo-template schema." | `agent` | docs / qa | No (procedural) | No (exempt — see below) |
| `expand-backlog-entry.md` | "Expand a sparse `.context/backlog.yaml` entry into a full issue body with acceptance criteria; called by `backlog-to-issues.yml`." | `agent` | architect | No (procedural) | No (machine-invoked) |
| `mirror-postmortem.md` | "Mirror a downstream-project postmortem into ai-repo-template; refuses to mirror without a same-PR follow-up." | `agent` | docs | No (procedural) | No (exempt — see below) |
| `pr-resolve-all.md` | "Resolve every open issue, suggestion, and TODO on a PR; produce Index + Resolution Report and auto-resolve bot threads." | `agent` | any (PR author) | No (procedural) | No (acts on existing PR) |
| `repo-onboarding.md` | "Onboard an AI agent to a repo (template-clone or existing); produce repo brief." | `agent` | any | No (procedural) | No (procedural) |
| `README.md` | — (intentional exception) | — | — | — | — |

All five non-README files conform to the schema documented in
`.github/prompts/README.md`. No drift.

## What the issue proposed

The issue ([#226](https://github.com/mikejmckinney/ai-repo-template/issues/226)
item 4) proposed five additional frontmatter fields, framed as "propose-and-discuss,
not 'do it'":

1. `role:` — which agent role this prompt is intended for
2. `requires-preflight: true|false` — does ADR-005/014 fire on this prompt
3. `requires-plan: true|false` — does ADR-011 fire on this prompt
4. `triggers-gate:` — list of named gates this prompt enforces
5. `description:` — already present; restate as required

The motivation for `requires-preflight`: ADR-005 + ADR-014 say "issue
references `.github/prompts/NN-*.md`" triggers the Analyst pre-flight gate.
Today that's prose-checked by the agent against filenames; a
`requires-preflight: true` field would make it machine-checkable.

## Findings

### Finding 1 — `description` is already covered, no work needed

Every prompt file already has a `description:` field, enforced by
`.github/prompts/README.md` §"Frontmatter schema" with a copy-pasteable
verification snippet. The picker UIs in VS Code, Claude Code, and the
`@<agent> follow` runtimes already consume it. No change needed for this
field.

### Finding 2 — `role:` is premature; current convention is good enough

The five shipped prompts span "any role" (`pr-resolve-all`,
`repo-onboarding`), "PM/architect-flavored" (`expand-backlog-entry`), and
"docs/qa-flavored" (`capture-postmortem`, `mirror-postmortem`). None pin
cleanly to a single role from `.github/agents/*.agent.md`, and the
`agent: agent` field in the existing schema is explicitly reserved for
future per-prompt role pinning (see `.github/prompts/README.md` →
"`agent`" field rule).

Project (`NN-*.md`) prompts are authored downstream and *do* tend to map
to a single role per stage. But:

- The role choice is downstream-author business; downstream agents already
  read the prompt body and `.github/agents/*.agent.md` to figure out which
  role to dispatch. Adding `role:` to the prompt frontmatter would
  duplicate the dispatch logic that already lives in
  `.context/rules/agent_ownership.md`.
- The `agent:` field is already reserved for this purpose and is
  intentionally pinned to `agent` until a tool needs to differentiate.

Verdict: keep `agent: agent` as the placeholder; revisit when (a) at
least one tool reads it and (b) downstream projects report friction with
the current dispatch flow. Neither condition holds today.

### Finding 3 — `requires-preflight:` and `requires-plan:` would duplicate AGENTS.md

The Analyst pre-flight gate (ADR-005 / ADR-014) and the plan-as-comment
requirement (ADR-011) already define their triggers in
[`AGENTS.md`](../../AGENTS.md) §"Analyst pre-flight gate" and §"Plan-as-comment
requirement". Both gates fire on **issue properties** (label, template,
body content), not on prompt-file properties:

- ADR-005 trigger: issue references `.github/prompts/NN-*.md` **and** the
  prompt describes a deliverable.
- ADR-014 broadening: issue uses `feature_request.md` + `enhancement`
  label, OR proposes a new agent surface, OR has action-verb + user-facing-noun
  body.
- ADR-011 trigger: issue is non-exempt (no `chore:no-plan` label, not a
  bot author, not a revert).

For the **shared procedural prompts** in this directory, AGENTS.md
§"Analyst pre-flight gate" → "Exemptions" already enumerates them by
name as exempt:

> Issues referencing only shared procedural prompts (`pr-resolve-all.md`,
> `repo-onboarding.md`, `expand-backlog-entry.md`, `capture-postmortem.md`,
> `mirror-postmortem.md`) … those describe procedures, not deliverables.

Adding `requires-preflight: false` to each of these five files would
duplicate that exemption list, creating a drift hazard: when the next
shared prompt is added, both AGENTS.md and the new prompt's frontmatter
would have to be updated in lockstep. Today, only AGENTS.md needs the
update.

For **project (`NN-*.md`) prompts**, `requires-preflight: true` would be
nominally true for all of them by convention (the entire reason they
exist is to drive a deliverable). The field would carry no information.
If a downstream project ever wants to mark a `NN-*.md` as exempt (e.g., a
purely-research stage that produces no user-facing deliverable), the
existing `outcome-validated` label + inline outcome paragraph escape
hatch from AGENTS.md §"Analyst pre-flight gate" → "Opt-out" already
handles it at the issue level — which is the right level, because the
gate fires on the *issue*, not the prompt.

`requires-plan:` has the same shape: ADR-011 fires on issues, not
prompts. The `chore:no-plan` opt-out is an issue label.

Verdict: do not add either field. The triggers and exemptions belong
where they already live (AGENTS.md + issue labels), not in prompt
frontmatter.

### Finding 4 — `triggers-gate:` solves a problem that isn't acute yet

The proposal was: list named gates the prompt enforces, e.g.
`triggers-gate: [phase-2-status, phase-4-thread-resolution]` for
`pr-resolve-all.md`. Two reasons not to add this:

1. **No tool consumes it today.** The CI workflows and the
   `agent-relay-reviews.yml` parsers find their inputs in PR comment
   bodies (Phase 2 status emojis, Phase 3 Resolution Report, etc.), not
   in prompt frontmatter. Adding the field would create documentation
   that no tool reads — pure overhead.
2. **The gates themselves are versioned independently of the prompt.**
   Phase 4 default + Copilot fallback (ADR-008) and the deferral marker
   (ADR-007) evolved without touching prompt frontmatter. A
   `triggers-gate:` list would have lagged each ADR by one PR, with no
   benefit.

Verdict: defer. If a future tool needs to enumerate "which prompt
enforces which gate" (e.g., a PR-status dashboard), reopen this with a
concrete consumer in mind.

### Finding 5 — One drift risk worth fixing now (not in this PR)

`.github/prompts/README.md` §"Frontmatter schema" lists the same five
shared prompts that AGENTS.md §"Analyst pre-flight gate" → "Exemptions"
lists. These two lists must stay in sync, but neither file references
the other and there is no test enforcing the match. This is a textbook
case for `.context/rules/process_doc_maintenance.md`'s doc-sync triggers
table.

Recommended follow-up (separate PR/issue, not part of #226 PR4):

- Add a row to `.context/rules/process_doc_maintenance.md`:
  "When adding/removing a shared procedural prompt under
  `.github/prompts/` (any `*.md` other than `NN-*.md`), update both
  `.github/prompts/README.md` §'Files here' AND AGENTS.md §'Analyst
  pre-flight gate' → 'Exemptions' bullet listing the shared prompts."
- Optionally extend `test.sh` to assert the two lists agree (cheap: parse
  the markdown bullets, set-diff them).

This finding does **not** require frontmatter changes; it requires a
process-doc rule. Filed as a recommendation, not a deliverable of this
audit.

## Recommendation — option (c), not worth the complexity

Per the issue's stated outcomes — "(a) ADR + implementation, (b) informal
per-file adoption, (c) not worth the complexity" — the audit recommends
**(c)**, with one process follow-up:

1. **Keep the current minimal schema.** `description` + `agent` is enough
   for the four runtimes that consume prompt frontmatter today (VS Code
   prompt picker, Claude Code loader, `@copilot follow`, `@claude follow`).
2. **Do not add** `role`, `requires-preflight`, `requires-plan`, or
   `triggers-gate`. Each either duplicates content already in AGENTS.md /
   `.context/rules/agent_ownership.md`, or has no consumer today, or both.
3. **File a separate issue** to add a doc-sync rule for the
   shared-procedural-prompt list (Finding 5). That's a process-doc fix,
   not a frontmatter change.

### When to revisit

Reopen this audit (or open a successor) if any of the following becomes
true:

- A workflow or script needs to programmatically enumerate "which prompts
  trigger which gate" — concrete consumer, not speculative.
- Downstream projects report that the dispatch flow ("which role runs
  this prompt") is a friction point that role frontmatter would solve
  better than `agent_ownership.md` already does.
- A new prompt-runtime tool ships that requires fields beyond `description`
  / `agent` — at which point the schema in `.github/prompts/README.md`
  should grow via an ADR (per the existing rule: "If a future tool needs
  them, propose the addition in an ADR so all four prompts stay
  consistent").

## Why not option (a) or (b)

- **(a) ADR + implementation** would lock in fields that no current
  consumer reads, violating the "don't add features beyond what was
  asked" floor in the implementation discipline rules and creating a
  drift hazard the moment AGENTS.md changes its trigger conditions.
- **(b) informal per-file adoption** is worse than (a): the same drift
  hazard, plus inconsistency between prompts. The existing schema is
  already enforced uniformly; abandoning that for ad-hoc per-file fields
  would make the next prompt author guess.
