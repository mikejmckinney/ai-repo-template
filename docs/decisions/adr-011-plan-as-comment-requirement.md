# ADR-011: Plan-as-comment requirement + PR-must-link-issue (v1)

## Status

Accepted (superseded in part by ADR-026)

## Date

2026-04-24

## Context

The template's existing pre-implementation gates are narrow: ADR-005's
Analyst Pre-Flight Report fires only on issues that reference
`.github/prompts/NN-*.md` paths. Every other issue — bug reports, feature
requests, ad-hoc tasks, backlog-dispatched work without an explicit prompt
reference — goes from assignment straight to code with no structured
"what am I about to do" artifact.

Three failure modes recur and are cheapest to catch pre-implementation:

1. **Wrong approach to the right problem.** Issue says "add caching";
   implementer adds a 4th caching layer when refactoring the existing one
   was correct. Caught at PR-review, expensive to revert.
2. **Hidden scope.** Issue is one bullet; resulting PR touches 12 files
   plus a database migration. Should have been a "split this PR"
   conversation before any code was written.
3. **Missing verification.** Implementer cannot articulate how they will
   prove the change works → the bug surfaces post-merge instead of
   pre-implementation.

Issue templates capture the **what** and **why** (deliberately
implementation-agnostic so the requester does not pre-commit to a
solution). They cannot catch these failure modes because the requester
does not know the implementation lens yet — only the implementer does,
after thinking.

Separately, PRs are sometimes opened without a linked issue or parent PR.
This breaks issue-tracking, history, and the "why was this changed"
audit trail. The current PR template has a `## Linked issues / ADRs`
section, but it is an HTML comment and easy to leave empty.

This ADR establishes a v1 plan-as-comment requirement and a tightened
PR-must-link-issue rule. Approval-gating, expiry rules, ADR-005 trigger
unification, and automated CI enforcement are intentionally deferred to
issue #155 to avoid bundling unresolved design questions into v1.

## Decision

We will require:

1. **Plan as a comment** — every implementer (human or agent) posts an
   Implementation Plan as a comment on the issue before writing code,
   using the template at `.github/PLAN_TEMPLATE.md`.
2. **PR-must-link-issue** — every PR body must reference an issue or
   parent PR (`Closes #NN`, `Refs #NN`, `Implements ADR-NNN`, etc.).
3. **Single template, no tiering.** The template scales with the work
   (~5 lines for trivial fixes, ~25–40 for typical work). Sections that
   don't apply are filled with `N/A — <reason>` rather than omitted.
4. **Label-based exemption only.** A `chore:no-plan` label opts an issue
   or PR out of the plan requirement (and, for PR-link, smoke-test PRs
   are also exempted via the existing `smoke-test` label, plus known
   automation bots like Renovate and Dependabot).
5. **Review-time enforcement only in v1.** Judge's diff-gate BLOCKs
   when a PR lacks a linked issue/parent PR and no exemption label is
   present. There is no CI gate in v1.

### Scope of v1

**In scope:**
- New file: `.github/PLAN_TEMPLATE.md`.
- Updated governance docs (`AGENTS.md`, `.github/copilot-instructions.md`,
  `CLAUDE.md`) describing the requirement and the exemption rule.
- Updated implementation-role agent files (analyst, architect, backend,
  frontend, devops, docs, qa, pm) and Claude mirrors with brief workflow
  pointers.
- Updated Judge role file (canonical + Claude mirror): DIFF-GATE BLOCKs
  when PR lacks a linked issue/parent PR with no exemption label.
- Updated PR template: required-text "Closes / Refs:" scaffold rather
  than the empty HTML-comment section.
- Updated `scripts/setup.sh`: creates the `chore:no-plan` label.
- Updated `test.sh`: adds `.github/PLAN_TEMPLATE.md` to `REQUIRED_FILES`.
- Updated `docs/guides/agent-pipeline.md`: adds the plan-comment step to
  the pipeline narrative.

**Out of scope (deferred to #155):**
- Approval mechanism (label, reaction, slash command, CI gate).
- Approval expiry on issue body edit.
- ADR-005 trigger re-keying so both gates share an exemption surface.
- Migrating `.github/prompts/NN-*.md` content into issue templates.
- Critic enforcement of plan-vs-diff weight mismatch.
- **Automated CI enforcement** of plan-presence and PR-link-presence.
  The trigger-condition design (which issues count as "non-trivial,"
  how to detect a valid plan comment, how to handle exemptions
  mechanically) is the same problem #155 solves for ADR-005. Doing it
  twice would mean throwing one away.

## Options Considered

### Option 1: Plan-as-comment with single template, label exemption, review-time enforcement (chosen)

- **Pros**: Catches scope/approach/verification failures pre-implementation
  at the cheapest point. Single template avoids the "default to minimal"
  failure mode that tiered templates invite. Label exemption is auditable
  and forces an explicit decision rather than hiding behind agent
  judgment. Review-time enforcement (Judge BLOCK) is mechanical to
  implement and reuses existing gate machinery.
- **Cons**: No mechanical pre-implementation block — an agent that
  ignores the rule still ships code, and the failure is caught at PR
  review (later than ideal). Mitigated by the same Judge enforcement
  that catches doc-sync violations.

### Option 2: Tiered plan template (minimal vs full)

- **Pros**: Lowers friction on borderline cases (a 60-LOC bug fix that
  feels too involved for `chore:no-plan` but doesn't really need the
  full structure).
- **Cons**: Agents will default to the lower-effort option whenever
  there's any ambiguity, and "any ambiguity" is most of the time. The
  failure mode the gate exists to catch (skipping the implementation
  thinking step) is precisely what minimal-mode invites. Rejected.

### Option 3: Size-based exemption (≤50 LOC, single-file, etc.)

- **Pros**: Objective, mechanical, no human judgment in the loop.
- **Cons**: Gameable — agent splits a 200-line change into "trivial
  49-line PRs" to skip the plan. Also creates arbitrary cliffs (a 51-LOC
  change requires a plan, a 49-LOC change does not, even if the 49-LOC
  change is architecturally riskier). Rejected.

### Option 4: CI enforcement in v1

- **Pros**: Mechanical, hard to bypass.
- **Cons**: The trigger-condition design is the same problem #155 must
  solve for the broader plan-and-approve system. Building CI in v1
  commits to a trigger shape before #155 has resolved it; either #155
  later overrides v1 (wasted work) or v1 constrains #155 (reverse
  causation). Defer to #155 — Judge enforcement covers v1.

### Option 5: Critic enforcement of plan-vs-diff weight mismatch

- **Pros**: Catches the "agent posted a one-line plan and shipped a
  massive diff" failure mode that's hard to catch otherwise.
- **Cons**: Soft gate (Critic comment, not block). Filed as a v2
  enhancement; not in v1 scope.

## Consequences

### Positive

- Implementer thinking happens before code is written, when redirection
  is cheap.
- PR audit trail is complete: every PR points back to a documented intent.
  The PR template's `## Plan` section (added post-PR-#189) makes that
  pointer specific — a permalink to the plan comment plus a one-line
  summary — so reviewers don't have to scan the issue thread to find
  the latest revision. Judge advises (REQUEST_CHANGES, not BLOCK) at
  diff-gate when this section is empty or stale; this stays in the
  v1 advisory tier alongside the plan-comment-presence check.
- The `chore:no-plan` label creates explicit, auditable exemption
  decisions rather than silent skips.
- Judge's existing diff-gate machinery enforces both rules with no new
  CI workflow to maintain.
- The template artifact is immediately reusable by #155 once approval
  gating is added; the same `chore:no-plan` label can suppress the
  future approval gate.

### Negative

- Adds a comment-posting step to the implementation workflow for every
  non-exempt issue. Mitigated by the template scaling to ~5 lines for
  trivial work.
- Three governance docs (`AGENTS.md`, `.github/copilot-instructions.md`,
  `CLAUDE.md`) must stay aligned on the requirement. Mitigated by
  AGENTS.md being the canonical source and the others being brief
  pointers.
- ADR-005 (Analyst Pre-Flight Gate) and this ADR establish two
  overlapping gates with different trigger conditions until #155
  unifies them. Documented as a known temporary state.

### Neutral

- ADR-005 stays in force unchanged. The Pre-Flight Report runs in
  addition to the plan requirement on prompt-referenced project issues.
- Existing `.github/prompts/NN-*.md` files and `.context/backlog.yaml`
  dispatch are unaffected by v1.
- This ADR's own implementation produces the first reference example of
  what a real plan comment looks like (posted on issue #164).

## Implementation

- [x] Create `.github/PLAN_TEMPLATE.md`.
- [x] Add new `## Plan-as-comment requirement` section to `AGENTS.md`
  after `### Analyst pre-flight gate`.
- [x] Add condensed mirror section to `.github/copilot-instructions.md`.
- [x] Add brief pointer in `CLAUDE.md` "Read first" routing.
- [x] Update `.github/agents/judge.agent.md` DIFF-GATE checklist with
  PR-link enforcement; mirror in `.claude/agents/judge.md`.
- [x] Update `.github/pull_request_template.md`: required-text scaffold
  for issue/PR link.
- [x] Update implementation-role agent files (analyst, architect,
  backend, frontend, devops, docs, qa, pm) and `.claude/agents/*.md`
  mirrors with brief workflow pointers.
- [x] Update `scripts/setup.sh`: add `chore:no-plan` label.
- [x] Update `test.sh`: add `.github/PLAN_TEMPLATE.md` to REQUIRED_FILES.
- [x] Update `docs/guides/agent-pipeline.md`: add plan-comment step and
  `chore:no-plan` label to the pipeline narrative.
- [x] Update `docs/decisions/README.md`: add ADR-011 row.

## References

- Issue #164 — implementing this ADR.
- Issue #155 — broader plan-and-approve enhancement; receives the
  deferred decisions (approval mechanism, expiry, CI enforcement,
  ADR-005 trigger unification).
- ADR-005 — Analyst Pre-Flight Gate. Stays in force; runs in addition
  to this ADR's plan requirement on prompt-referenced project issues.
- ADR-002 — AGENTS.md ownership. This ADR's governance updates respect
  AGENTS.md as the canonical source for cross-tool agent rules.
- ADR-003 — Claude Code subagent registration. Role file changes here
  follow the canonical-plus-mirror pattern with byte-identical
  description frontmatter.
- `.context/rules/process_doc_maintenance.md` — doc-sync triggers
  applied: new ADR, pipeline label addition, role file changes,
  governance doc changes, new template file, pipeline narrative
  changes.
