# ADR-014: Extend Analyst Pre-Flight Gate to Label-Triggered Issues

## Status

Accepted (supersedes ADR-005)

## Date

2026-04-28

## Context

ADR-005 added the Analyst Pre-Flight Gate to catch a specific failure mode:
prompts that describe deliverables (pages, files, components) without
specifying the user outcome those deliverables are meant to produce. The
gate's trigger was scoped narrowly — it fires only on issues that reference
`.github/prompts/NN-*.md` numbered project prompts — and was paired with a
deliberate set of carve-outs (shared procedural prompts, bug fixes,
dependency bumps, typo corrections, doc edits, ad-hoc issues with no prompt
reference).

That scope was correct for the failure mode ADR-005 set out to address
(numbered project prompts authored ahead of implementation). But the same
failure mode shows up in three places ADR-005 doesn't cover:

1. **Ad-hoc feature issues** — a maintainer files an issue describing a
   user-facing deliverable without referencing a prompt file at all
   (e.g., "Add a status dashboard for X" with a list of pages and an
   acceptance-criteria checklist). This is the most common authoring
   path for derived projects that don't use the `NN-*.md` convention.
2. **Chat-originated feature work** — work approved during a conversation
   with an agent and filed as an issue (or a direct PR) without going
   through the prompt-authoring flow. Issue #199's `chore:no-plan`
   exemption flow is one example; #196 was another.
3. **ADRs proposing new agent surfaces** — an ADR that introduces a new
   role, new gate, new pipeline phase, or new automation surface. The
   "deliverable" is operational (the surface is something agents will
   *use*), and a missing user outcome leads to the same wrong-artifact
   outcome as a prompt-authored deliverable.

In each case, the failure mode is identical: the deliverable list is
clear, the implementer ships exactly what's described, and the resulting
artifact misses the underlying intent. ADR-005's fix (the 15-minute test,
PASS / FAIL / HOLD verdicts, structured Pre-Flight Report) applies cleanly
— but the trigger condition doesn't reach these cases.

The naive fix — apply the gate to every issue — re-introduces the noise
ADR-005 deliberately scoped out (procedural prompts, ad-hoc bug fixes,
typo PRs would all pay a cost they don't need to pay). The carve-outs are
load-bearing and must survive any extension.

This ADR's job is to widen the trigger without weakening the carve-outs.

## Decision

We supersede ADR-005 and broaden the trigger so the Analyst Pre-Flight
Gate fires on **either** of two conditions:

1. **The issue references a numbered project prompt file** matching
   `.github/prompts/NN-*.md` (the original ADR-005 trigger, preserved
   verbatim).
2. **The issue carries the label `gate:preflight-required`** (new
   trigger).

The label is opt-in: authors apply it explicitly when they identify an
issue as proposing a novel user-facing deliverable, an ADR introducing a
new agent surface, or any other work where the 15-minute test is the
right validation. Absence of the label is the default — bug fixes,
dependency bumps, typos, doc edits, procedural-prompt issues, and
chat-originated revert work all proceed without pre-flight, exactly as
they do today.

The gate semantics from ADR-005 carry over unchanged: the Pre-Flight
Report (15-minute test, PASS / FAIL / HOLD verdicts, exact template in
`.github/agents/analyst.agent.md` → "Pre-Flight Validation") remains the
operative artifact. Judge BLOCKs at PLAN-GATE when the report is missing
or carries verdict FAIL or HOLD on a triggered issue.

### Scope of the gate

**In scope** (gate applies):

- Issues referencing `.github/prompts/NN-*.md` numbered project prompts
  *that describe a deliverable* (UI, service, pipeline, dataset —
  anything interactive or operational).
- Issues carrying the `gate:preflight-required` label, regardless of
  whether they reference a prompt file.

**Out of scope** (gate does NOT apply):

- Issues that don't reference an `NN-*.md` prompt **and** don't carry
  the `gate:preflight-required` label.
- Issues referencing shared procedural prompts (`pr-resolve-all.md`,
  `repo-onboarding.md`, `copilot-onboarding.md`,
  `expand-backlog-entry.md`) — these describe agent procedures, not
  project deliverables, and have their own verification.
- Prompt documentation (`README.md`) under `.github/prompts/`.
- Bug fixes, dependency bumps, typo corrections, doc edits, and
  procedural changes that don't introduce a novel user-facing
  deliverable — *unless* an author explicitly applies
  `gate:preflight-required`, in which case the author's judgment wins.

### When to apply the label

The label is the author's signal that a 15-minute test is the right
validation. Apply it when:

- Filing an ad-hoc feature issue (no `NN-*.md` reference) that proposes
  a UI, service, pipeline, dataset, or operational artifact.
- Filing an ADR proposal that introduces a new agent surface (new role,
  new gate, new pipeline phase, new automation surface).
- Filing chat-originated work where the conversation is the only place
  the user outcome was discussed and the issue body alone wouldn't pass
  pre-flight.

If you're unsure whether to apply the label, apply it. False positives
cost a Pre-Flight Report; false negatives cost the same wrong-artifact
rework ADR-005 was written to prevent.

### Changes to role definitions

The following role definition files are updated as part of this decision:

- `.github/agents/analyst.agent.md` — section "Prompt Pre-Flight
  Validation" is renamed to "Pre-Flight Validation" and the trigger
  enumeration is broadened to include the label condition. Report
  template, 15-minute test, and verdict semantics are unchanged.
- `.github/agents/judge.agent.md` — the PLAN-GATE checklist condition is
  extended: BLOCK when a Pre-Flight Report is missing on an issue that
  *either* references an `NN-*.md` prompt *or* carries
  `gate:preflight-required`. The "do not apply this gate to shared
  procedural prompts" exception is preserved verbatim.
- `.github/copilot-instructions.md` — the manual pre-flight procedure is
  extended to also fire on the label.
- `AGENTS.md` — the "Analyst pre-flight gate" section names the label as
  a trigger. The "When this gate does NOT apply" non-trigger list is
  preserved verbatim, with a clarifier that the label is opt-in
  (absence is the default).
- `.github/prompts/README.md` — adds a short author-guidance paragraph
  about when to apply the label to non-prompt issues.
- `docs/guides/agent-pipeline.md` — the gate-flow paragraph notes the
  label trigger and links this ADR.

Both canonical (`.github/agents/*.agent.md`) and mirror
(`.claude/agents/*.md`) files must be updated in lockstep per ADR-003.
The `description:` frontmatter must remain byte-identical between
mirrors, enforced by `test.sh` (`Check B`, lines 411–423).

### Label declaration

The `gate:preflight-required` label is declared in `scripts/setup.sh` via
`_ensure_label`, alongside `chore:no-plan` and the other pipeline
labels. Color: `5319E7` (matches `from-backlog` and `copilot-relay` —
the "agent-coordination purple" used elsewhere for opt-in pipeline
gates). Description: "Trigger Analyst Pre-Flight Report on this issue
(ADR-005, ADR-014)."

## Options Considered

### Option 1: Label-based opt-in (chosen)

- **Pros**: Carve-outs survive verbatim — bug-fix and typo PRs continue
  to bypass the gate by default. Trigger is explicit and auditable
  (label presence is structured data, not heuristic). Single-purpose
  `gate:*` namespace cannot drift via triage relabeling. Cheap to
  implement (no workflow changes; one label, doc updates only).
  Symmetric with `chore:no-plan` (the existing exemption-by-label
  pattern), so the convention scales.
- **Cons**: Relies on author discipline — false-negative if the author
  forgets the label. Mitigation: documented in §Consequences;
  `prompts/README.md` and `copilot-instructions.md` give explicit
  guidance; "if unsure, apply it" rule errs toward the gate firing.

### Option 2: Blanket-apply the gate to every issue

- **Pros**: No false-negatives; every issue gets a Pre-Flight Report.
- **Cons**: Re-introduces every problem ADR-005 deliberately scoped out.
  Bug-fix PRs, typo PRs, dependency-bump PRs, and procedural-prompt
  issues would all pay a Pre-Flight cost they don't need. The
  15-minute test isn't well-defined for "fix a typo in the README" —
  forcing it generates ceremonial PASS verdicts that add no signal.
  Signal degrades when the gate fires universally (FAIL/HOLD verdicts
  become noise once the population is mostly trivial). Rejected.

### Option 3: Piggyback on a generic `type:feature` label

- **Pros**: One label that doubles as taxonomy + gate trigger; less
  label sprawl.
- **Cons**: `type:feature` is a triage label that humans and bots will
  apply broadly for routing, sprint planning, and reporting. Every
  triage relabeling becomes a silent gate-scope change. The whole value
  of the gate is precision: it should fire when an author *explicitly
  opts in* knowing they're proposing a deliverable. A namespaced
  single-purpose label has exactly one job and cannot drift. Rejected.

### Option 4: Amend ADR-005 in place

- **Pros**: One ADR per topic; smaller diff; cross-references stay
  pointing at ADR-005.
- **Cons**: ADR-005's Context section is specifically about prompt
  files; the expanded scope (ad-hoc issues, ADRs) doesn't fit there
  without a rewrite. The repo's ADR template
  (`docs/decisions/adr-template.md` lines 13–26) explicitly lists
  "scope expands enough that the rationale no longer fits the original
  Context section" as a new-ADR trigger, and ADR-007→ADR-008 establish
  the supersession pattern. Editing ADR-005 in place would break the
  audit-trail discipline. Rejected.

## Consequences

### Positive

- The pre-flight gate now reaches ad-hoc feature issues, chat-originated
  work, and ADR proposals introducing new agent surfaces — closing the
  largest known gap in ADR-005's coverage.
- Carve-outs (bug fixes, typos, dependency bumps, doc edits, procedural
  prompts) survive verbatim. The cost of pre-flight is paid by, and
  only by, work that opts in.
- The label-based trigger composes cleanly with `chore:no-plan` and
  other opt-in/opt-out labels in the existing pipeline. Convention
  scales without inventing a new mechanism.
- `gate:*` namespace is established for future opt-in gates without
  diluting `chore:` or `type:`.

### Negative

- Author must remember to apply the label. False-negative is the
  failure mode; mitigation is documentation, not enforcement.
- One additional label in the pipeline-label set
  (`scripts/setup.sh` and the enumerated lists in the Codespaces /
  fallback warnings).

### Neutral

- Existing workflows for procedural prompts, bug fixes, dependency
  bumps, and ad-hoc issues without the label are completely unaffected.
- The Pre-Flight Report template, 15-minute test, verdict semantics,
  and Judge enforcement path are unchanged.
- Critic's "Outcome match" DIFF-GATE check (added in ADR-005) extends
  naturally — it triggers off the existence of a Pre-Flight Report,
  which now appears on a broader population of issues.

## Implementation

- [ ] Create this ADR (`docs/decisions/adr-014-extend-analyst-preflight-to-labeled-issues.md`).
- [ ] Update `docs/decisions/adr-005-analyst-preflight-gate.md` Status
      line to `Superseded by ADR-014` in the same PR.
- [ ] Update `AGENTS.md` "Analyst pre-flight gate" section: add label
      trigger, preserve non-trigger list, add label-is-opt-in clarifier.
- [ ] Update `.github/agents/analyst.agent.md`: rename "Prompt Pre-Flight
      Validation" → "Pre-Flight Validation"; broaden trigger
      enumeration; preserve report template.
- [ ] Update `.github/agents/judge.agent.md` PLAN-GATE check at line 67
      to fire on either trigger.
- [ ] Update `.github/copilot-instructions.md` pre-flight procedure to
      fire on either trigger.
- [ ] Update `.github/prompts/README.md` with author guidance about when
      to apply the label.
- [ ] Update `docs/guides/agent-pipeline.md` gate-flow paragraph to
      note the label trigger.
- [ ] Add `_ensure_label "gate:preflight-required" "5319E7" "..."` to
      `scripts/setup.sh` after line 365; update enumerated label lists
      in the Codespaces / fallback warning blocks.
- [ ] Add 4 invariants to `test.sh`: label declared in setup.sh; ADR-014
      file exists with `Status: Accepted (supersedes ADR-005)`; ADR-005
      Status references ADR-014; AGENTS.md mentions the label by name
      inside the gate section.
- [ ] Verify byte-identity check (`test.sh` Check B, lines 411–423) on
      `.github/agents/analyst.agent.md` ↔ `.claude/agents/analyst.md`
      `description:` lines stays green.

## References

- ADR-005 — Analyst Pre-Flight Gate for Project Prompts (superseded by
  this ADR)
- ADR-004 — Add Analyst role and agile feedback loop (introduces the
  Analyst role this gate sits on)
- ADR-003 — Claude Code subagent registration (lockstep update pattern
  for `.github/agents/**` ↔ `.claude/agents/**`)
- ADR-007 / ADR-008 — supersession-pattern reference
- `docs/decisions/adr-template.md` lines 13–26 — supersession discipline
- `.context/rules/agent_ownership.md` — Shared / Contested Files
  (`.github/agents/**`)
- `.github/agents/analyst.agent.md` → "Pre-Flight Validation"
- `scripts/setup.sh` lines 349–365 — pipeline label declarations
