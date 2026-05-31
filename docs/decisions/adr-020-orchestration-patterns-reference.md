# ADR-020: Orchestration patterns and anti-patterns reference file

<!--
This ADR is the implementation of sub-issue #252 in parent epic #251
(addressing recommendations from the 2026-05-07 architectural review).
The PR that lands this ADR also lands the rules file the ADR ratifies
(`.context/rules/repo_orchestration_patterns.md`). Architect's normal
plan-only constraint applies — the file *is* the implementation of this
ADR's decision, not a separate code change.
-->

## Status

Accepted

## Date

2026-05-08

## Context

PR review on changes to the orchestration layer (AGENTS.md, `.context/rules/**`, `.github/agents/**`, `.github/workflows/**`, `scripts/**`) currently lacks shared vocabulary for naming the patterns the template uses and the anti-patterns it has accumulated. Reviewers (Critic, Judge) argue quality and structural drift in vague terms, with no citable handle. This is the same gap that motivated `domain_code_quality.md` for the code layer — but at the orchestration layer, no equivalent file exists.

Three related forces make this acute now:

1. **The 2026-05-07 architectural review** (recorded in parent issue #251, sub-issue #252, and conversation history) identified six anti-patterns currently triggered or at risk of being triggered: God Object (`AGENTS.md` at ~330+ lines and version-canary in active use — see `AGENTS.md:3` for the canary marker), Mirror Duplication (`.github/agents/` ↔ `.claude/agents/` byte-identity, tracked in #248/#249), Implicit Contract (postmortem PM-001 lesson), Goal Substitution (postmortem PM-002 lesson, marked universal), Sequential Coupling (current onboarding read order), and Single-Writer Shared State (postmortem PM-003 lesson). Without named entries for these, the follow-up work in sub-issues 2–4 of #251 has no shared language to argue in.

2. **Three postmortems contain generalizable lessons** (`docs/postmortems/postmortem-001`, `-002`, `-003`) but those lessons currently live only in the postmortem files themselves and in the ADRs that responded to them (ADR-012, the design-for-outcomes work in #69/#201, ADR-018). Postmortems by convention are append-only and stack-tagged; they're a lesson archive, not a review-time vocabulary. Reviewers don't cite postmortems at diff-gate; they cite rules. The lessons need a rules-layer home.

3. **The decomposition of `AGENTS.md`** (sub-issue 2 of parent epic #251) materially changes the orchestration layer's structure. That ADR will need to cite the God Object anti-pattern by name to justify the split. That citation needs a referent; this file is it.

Without a named-vocabulary file:

- Critic's `CRAFT NOTES` cite `H1`–`H8` (code-layer rules from `domain_code_quality.md`) when discussing orchestration concerns where the analog is approximate, or hand-wave with no citation when no analog exists.
- Judge's diff-gate decisions on orchestration changes lack the cite-by-ID precision they have for code-layer changes.
- Downstream forks of this template inherit the same vocabulary gap silently — the lessons learned here don't propagate, even though the postmortems explicitly mark several as generalizing.
- Pattern naming arguments at PR review consume time without changing the implementation, because there's no canonical name to converge on.

## Decision

We will add `.context/rules/repo_orchestration_patterns.md` as an Architect-owned, binding rules file describing the orchestration patterns and anti-patterns currently in use or at risk in this template. The file is consulted by Critic and Judge during review of changes to the orchestration layer.

### File scope

The file describes the orchestration layer only — multi-agent workflow, role definitions, rule files, gates, and coordination state. Code-layer patterns for downstream projects (CMMC enclave, FedRAMP OSCAL, etc.) are deliberately out of scope and will live in `docs/guides/design-patterns.md` (sub-issue 5 of parent epic #251, deferred).

### Prefix convention

Entries use a citable-handle prefix matching the convention from `domain_code_quality.md` (`H<n>` for Hard rules, `S<n>` for Soft rules):

- **`P<n>`** — patterns currently used. Descriptive vocabulary for what exists. Examples: `P1` (Strategy via role files), `P2` (Chain of Responsibility via the pipeline).
- **`AP<n>`** — anti-patterns to watch for. Block-able or advisory at diff-gate, designated per entry. Examples: `AP1` (God Object), `AP2` (Mirror Duplication).

The `P<n>` / `AP<n>` distinction matters because patterns are vocabulary, not enforceable rules; only anti-patterns block at diff-gate. Conflating them would invite "you should add a Strategy here" review comments — exactly the prescriptive misuse this ADR is trying to prevent.

### Block-vs-advisory designation

Each anti-pattern entry is designated either **block-able** (Judge stops the PR at diff-gate when triggered without justification) or **advisory** (Critic flags as `CRAFT NOTES`; Judge does not block on the entry alone). The initial designations:

| ID | Anti-pattern | Designation | Rationale |
|---|---|---|---|
| AP1 | God Object | Block-able | Detection signals are objective (file size, concern count, edit frequency). |
| AP2 | Mirror Duplication | Block-able (with carve-out) | Block on adding a *new* mirror set; permit edits to existing mirror sets while #248 is in flight. |
| AP3 | Implicit Contract | Block-able | The check is "is this rule written down somewhere?" — binary. |
| AP4 | Goal Substitution | Advisory | Outcome quality is judgment-dependent. Judge blocks only when the User outcome paragraph is missing or clearly inverted. |
| AP5 | Sequential Coupling | Advisory | Read-list length is judgment-dependent. Judge blocks only on material extensions of the canonical read list without an ADR. |
| AP6 | Single-Writer Shared State | Block-able | Schema check is mechanical: "does this concurrent-write surface have an owner-key?" |
| AP7 | Magic String Sprawl | Block-able | Mechanical: did the PR update all known consumers when introducing/renaming an identifier? |
| AP8 | Workflow-as-Application | Advisory | "Trigger filter vs business logic" line is judgment-dependent; blocks on postmortem-traceable cases or material extensions without extraction. |
| AP9 | Compatibility Surface Entrenchment | Block-able | Once a replacement operating model has been accepted as canonical, retaining deprecated compatibility surfaces as active normal-work docs, workflows, onboarding steps, or validators is no longer a bounded migration tail; it recreates the dual-model state the anti-pattern was added to catch. |

Designations may be tightened (advisory → block-able) by a follow-up ADR if local conventions warrant. Loosening (block-able → advisory) requires an ADR ratifying why the failure mode no longer warrants stopping at diff-gate.

### Postmortem-derived entries are load-bearing

Entries `AP3`, `AP4`, `AP6`, and `P7` were generalized from `docs/postmortems/postmortem-001`, `-002`, `-003`. These entries are load-bearing for downstream forks: deleting them implicitly says "we no longer think this lesson applies." Removal of any of these four entries (in this template or in a fork) requires an ADR explaining why the underlying failure mode is no longer relevant. Edits, additions, and tightening do not require this — only removal.

### Block conditions are a Critic/Judge contract

Block conditions in the file are part of the contract between this rules file and the review roles (`.github/agents/critic.agent.md`, `.github/agents/judge.agent.md`). Changing a block condition is a process change, not a content change, and requires an ADR amending this one. Architect can amend descriptions, detection signals, and remediation guidance without an ADR (those are content within the established contract).

## Options Considered

### Option 1: Place in `docs/guides/` (advisory only)
- **Pros**: Lower-friction creation; no ADR needed; Docs-owned.
- **Cons**: Guides are advisory; Critic/Judge cite rules at diff-gate, not guides. Putting orchestration patterns in `docs/guides/` would mean reviewers can flag drift but can't BLOCK on it. The God Object anti-pattern in particular needs to be block-able to give sub-issue 2's decomposition work a hard floor.

### Option 2: Place in `.context/rules/` (binding, chosen)
- **Pros**: Citable at diff-gate; Architect-owned; matches the convention used for `domain_code_quality.md`; Critic and Judge can BLOCK on entries.
- **Cons**: Requires this ADR; Architect must own the file and ratify changes; downstream forks inherit it (intentional but worth naming).

### Option 3: Distribute pattern naming inline in role files
- **Pros**: Roles already describe their behavior; pattern names could be added there.
- **Cons**: Duplicates content across 10 role files; breaks the single-source-of-truth convention; makes the patterns harder to discover (no central list); Critic and Judge would need to scan all 10 role files to find the entry they need to cite.

### Option 4: Two separate files (one for patterns, one for anti-patterns)
- **Pros**: Cleaner separation; either file could be edited without touching the other.
- **Cons**: The two are intertwined (every anti-pattern has a remediation that often references the corresponding positive pattern; e.g., `AP6` Single-Writer Shared State remediated by `P7` Owner-Keyed Concurrent State). Splitting forces cross-file references for content that is naturally adjacent. Doubles the file count without proportional benefit.

### Option 5: Don't write the file; keep arguing in vague terms
- **Pros**: Zero up-front cost.
- **Cons**: The follow-up work in sub-issues 2–4 of #251 has no shared vocabulary; pattern-naming bikeshed at PR review continues; postmortem-derived lessons stay in the postmortem-archive layer where reviewers don't cite them; downstream forks inherit the gap.

## Consequences

### Positive

- Critic and Judge gain citable handles (`P<n>`, `AP<n>`) for orchestration-layer review, parallel to the `H<n>` / `S<n>` handles already in use for code review.
- The God Object anti-pattern (`AP1`) has a binding home, giving sub-issue 2's decomposition work a hard floor it can cite in its ADR.
- Postmortem-derived lessons (`AP3`, `AP4`, `AP6`, `P7`) move from the postmortem-archive layer to the rules layer, where reviewers cite them at diff-gate. PM-002's lesson in particular ("Goal Substitution") was marked universal in `docs/postmortems/README.md`; this ADR is the first step toward making that label load-bearing.
- Downstream forks of the template inherit a named-vocabulary file, so the lessons learned here propagate by default rather than by reinvention.
- Pattern-naming bikeshed at PR review is reduced: there is now a canonical naming for the patterns currently in use, and reviewers converge on those names rather than relitigating each PR.

### Negative

- Adds another file Architect must own and maintain. In practice this should be low-overhead — the file changes when patterns are added/removed/recategorized, which happens at ADR cadence, not edit cadence.
- The `P<n>` / `AP<n>` numbering creates a stable-ID commitment. Renumbering after the fact would break every review citation; we accept that adding new entries gets the next available ID and removed entries leave a gap (similar to how `H1`–`H8` accommodate future Hard rules without renumbering).
- Block-vs-advisory designations can drift from actual practice over time. Mitigation: each designation is documented with its rationale; changes require an ADR; Critic and Judge can flag designations that no longer match how reviews actually run.
- The "load-bearing postmortem entries" rule (in the file's "How to extend" section) creates a one-way ratchet — deletion requires an ADR, but addition does not. This is intentional but worth surfacing: the asymmetry is what makes the rule load-bearing.

### Neutral

- This file does not change the role of postmortems. PM-NNN files remain the canonical lesson archive; the rules file is a derivative reference for diff-gate citation. Postmortem-derived entries link back to the originating postmortem; the postmortems do not need to link forward.
- This file does not change Critic or Judge role definitions in shape. Their existing review responsibilities now include citing entries from this file when applicable; the citation is a clarity improvement, not a new obligation. Both role files are updated in this PR to reference the new file alongside `domain_code_quality.md`.
- Sub-issues 2, 3, and 4 of parent epic #251 each get a named anti-pattern they can reference in their own ADRs. Specifically: sub-issue 2 cites `AP1`, sub-issue 3 may cite `AP1` or no anti-pattern, sub-issue 4 may cite no anti-pattern (the `test.sh` issue is a code-quality concern under existing `H1`, not an orchestration anti-pattern).

## Implementation

- [x] Add `.context/rules/repo_orchestration_patterns.md` with the entries specified in sub-issue #252's acceptance criteria (8 patterns + 8 anti-patterns; full content adopted from the parent epic's review materials).
- [x] Add a row to `.context/rules/agent_ownership.md` registering `.context/rules/repo_orchestration_patterns.md` as Architect-owned. (The existing `.context/rules/**` glob already covers it; an explicit row is added for citation clarity.)
- [x] Update `AGENTS.md` § "Review guidelines" to link the new patterns file so Critic and Judge encounter it during repo grounding.
- [x] Update `.github/agents/critic.agent.md` and `.github/agents/judge.agent.md` to reference `repo_orchestration_patterns.md` in their review-step lists, alongside the existing reference to `domain_code_quality.md`.
- [x] Update `test.sh` to assert the new file exists, mirroring the existing checks for `agent_ownership.md` and `domain_code_quality.md`.
- [x] Update `.context/rules/process_doc_maintenance.md` trigger table to add a row: changes to a pattern or anti-pattern entry trigger a paired check that no Critic/Judge role file or AGENTS.md reference is now stale.

The PR landing this ADR also lands the rules file content. Per Architect's plan-only constraint, the rules file is the implementation of this ADR's decision; the two ship together because the ADR's "Decision" section is incoherent without the file existing.

## References

- Parent issue #251 (architectural review epic).
- Sub-issue #252 (this ADR is its implementation).
- `.context/rules/domain_code_quality.md` — analogous file at the code layer; this ADR follows its conventions.
- `.context/rules/agent_ownership.md` — confirms Architect owns `.context/rules/**`.
- `docs/postmortems/postmortem-001-workflow-bypass.md` — origin of `AP3` (Implicit Contract).
- `docs/postmortems/postmortem-002-poc-outcome-mismatch.md` — origin of `AP4` (Goal Substitution).
- `docs/postmortems/postmortem-003-active-md-merge-conflict.md` — origin of `AP6` (Single-Writer Shared State) and `P7` (Owner-Keyed Concurrent State).
- ADR-002 — AGENTS.md ownership; this ADR does not amend it but is named in `AP1`'s remediation context.
- ADR-003 — dual-registry rationale; this ADR's `AP2` (Mirror Duplication) cites it as the current implementation.
- ADR-012 — explicit workflow preconditions; codified the lesson `AP3` generalizes.
- ADR-018 — multi-task repo-local active-state schema; codified the pattern `P7` generalizes.
- Issues #248 and #249 — role-mirror canonicalization work; tracked separately, cited by `AP2`.
