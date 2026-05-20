# ADR-021: Decompose AGENTS.md into thin contract + per-concern process_*.md files

## Status

Accepted (superseded in part by ADR-025; §"Per-file cadence bump" scope
narrowed by ADR-029 §7 — canary covers `AGENTS.md` content only,
per-concern `.context/rules/process_*.md` files evolve through their own
PRs without bumping the canary)

## Date

2026-05-08

## Context

`AGENTS.md` had grown to 341 lines and version 13 of the per-edit canary handshake, covering 18+ distinct concerns: handshake, template detection, critical thinking, work style, clarification, truth hierarchy, role selection, two pre-implementation gates (Analyst pre-flight, plan-as-comment), model tier dispatch, context pack usage, onboarding, doc maintenance, session-state cadence, testing, PR completion, validation, templates, code quality, review.

The repo's own H1 single-responsibility rule (`.context/rules/domain_code_quality.md:13`) forbids units with multiple unrelated reasons to change. AGENTS.md violated this by every metric: it had had 13 substantive versions, edits routinely landed in unrelated sections, and the version-canary handshake mechanism existed *because* mid-session edits were common enough that staleness was a real risk. The handshake was a workaround for the file's God Object shape, not a fix for it.

Re-reading AGENTS.md takes ~15 minutes. The §"Session-state cadence" rule mandates re-reading at every task boundary. That is prohibitive load — agents in practice skim and miss rule changes, which is the exact failure mode the handshake was designed to detect.

Issue #253 (sub-issue of #251) authorized the decomposition. Issue #263 — filed in the same session that ratified this ADR — is the workflow-automation follow-up that eliminates the post-merge close-out PR overhead introduced as a *new* discipline rule in this PR (see "Scope addition: close-out PR discipline" below).

## Decision

Split `AGENTS.md` into two layers:

1. **Thin top-level `AGENTS.md`** (~93 lines, down from 341): the contract every agent must read at session start. Contains only:
   - `AGENTS_MD_VERSION` canary + session handshake (retained — see "Handshake decision" below)
   - Pointer-files note
   - Truth hierarchy (3-line core)
   - Per-concern link table (one row per `process_*.md`)
   - Section-anchor redirect table for ADR back-compat (see "Anchor-redirect approach" below)
2. **Per-concern files in `.context/rules/process_*.md`**: each major concern from the prior AGENTS.md becomes a focused file. Files added in this PR:
   - `process_template_detection.md` — Mode A vs Mode B template-detection rules
   - `process_critical_thinking.md` — push-back, calibrated confidence, citation discipline
   - `process_work_style.md` — branching, commit cadence, no drive-by refactors, pre-push review, **plus** Testing requirements + Validation (consolidated)
   - `process_clarification.md` — when to ask, question budget, low-stakes escape hatch
   - `process_role_selection.md` — Role selection (multi-agent workflow) + Context pack usage + Onboarding procedure (consolidated)
   - `process_gates.md` — Analyst pre-flight gate + Plan-as-comment requirement
   - `process_session_state.md` — Re-read cadence + handoffs + multi-task `_active.md` schema + Close-out (three actions, three triggers) + **new** "Close-out PR discipline (interim, until #263)" rule + Postmortem feedback loop
   - `process_pr_completion.md` — PR completion criteria + Templates and conventions + Code quality (pointer) + Review guidelines (consolidated)
   - `process_model_tier.md` — Model tier dispatch convention
   - `process_doc_maintenance.md` — already existed; absorbed AGENTS.md §"Ongoing maintenance" pointer + new doc-sync row for `process_*.md` heading renames

The decomposition is **content-preserving with one documented exception**: the new "Close-out PR discipline (interim, until #263)" subsection in `process_session_state.md` is authored fresh in this PR. See "Scope addition" below.

## Scope addition: close-out PR discipline

The triggering incident was commit `f63f728` on `main` after PR #261 merged. That commit moved the trigger-3 lock to Recent History + stripped the `_active.md` `## Task:` section + bumped `latest_summary.md` `Status: done` — three close-out edits, pushed directly to `main`. The agent rationalized "branch first" away because the alternative (a single-line follow-up PR) felt heavyweight.

This decomposition PR creates `process_session_state.md` from scratch. The marginal cost of authoring the close-out PR discipline rule in the same edit is ~5 lines of content; deferring to a follow-up PR after this lands would re-edit a brand-new file immediately for no orchestration benefit. So the rule is folded in here.

The new rule says: trigger-3 lock release (and any orphaned trigger-2 cleanup that survived past PR merge) goes through a `chore(closeout): PR #NNN` follow-up PR. Direct commits to `main` are not allowed even for one-line state edits. Issue #263 will eventually automate this via an opt-in `auto-coordinate` label on `agent-coordination-sync.yml`; until then, the manual follow-up PR is required.

This is the only non-content-preserving change in the decomposition. The AGENTS.md issue (#253) was updated in the same session to acknowledge the scope addition.

## Handshake decision

The pre-decomposition handshake (`Session handshake v13`) was a per-edit canary that detected stale `AGENTS.md` copies when tools cached an old version. After decomposition, `AGENTS.md` is a thin contract that should rarely change — the canary's value drops because most material rule changes now live in `process_*.md` files which have no equivalent canary.

Three options considered:

1. **Retain on the thin file (chosen).** Bump `AGENTS_MD_VERSION` only when the contract layer materially changes. Cost is essentially zero (one number bump per material edit). Catches the case where a tool's auto-load cache predates a contract-layer edit. The canary's scope explicitly **does not** cover `process_*.md` files — that limitation is documented inline in the AGENTS.md canary comment.
2. **Per-process-file canary.** Rejected — high overhead (one bump per file per edit, multiplied across ~10 files), complicates the handshake protocol, and provides marginal value because per-concern files are loaded on-demand rather than at session start.
3. **Remove entirely.** Rejected for now — losing the per-edit staleness signal during the decomposition transition period (when tool caches are most likely to be out of sync) is the exact wrong moment to drop it. Revisit after 6 months of post-decomposition stability if the canary fires near-zero.

The version is bumped to `14` in this PR to reflect the decomposition itself.

## Anchor-redirect approach

The repo has 21 ADRs and many guides that reference AGENTS.md sections by anchor (e.g., `AGENTS.md §"Session-state cadence"`). Two options for handling those:

- **Option (a): Update every reference in lockstep with this PR.** Cleaner long-term but high diff size, high risk of missing a reference, and creates churn in unrelated ADR files.
- **Option (b): Add a redirect mapping in the thin AGENTS.md.** Lower-effort, append-only, ADRs continue to read as written, the resolver lives in the file the citations already point to.

**Chose option (b).** The thin AGENTS.md ends with a "Section-anchor redirects (for ADR back-compat)" table mapping each pre-decomposition section name to its new file location. ADR readers who follow a citation land in AGENTS.md, see the redirect table, and resolve the anchor without code archaeology. New ADRs should cite the new file paths directly. Existing ADRs are not edited.

## Doc-sync trigger update

`.context/rules/process_doc_maintenance.md` gains one new row: "Rename or restructure a section heading in any `.context/rules/process_*.md` file" → must update the link table in `AGENTS.md` and any cross-file references. The existing "Rename or restructure a section heading in `AGENTS.md`" row is preserved (still applies to the thin contract layer).

## Files Changed

- `AGENTS.md` — replaced (341 → 93 lines)
- `.context/rules/process_template_detection.md` — NEW
- `.context/rules/process_critical_thinking.md` — NEW
- `.context/rules/process_work_style.md` — NEW
- `.context/rules/process_clarification.md` — NEW
- `.context/rules/process_role_selection.md` — NEW
- `.context/rules/process_gates.md` — NEW
- `.context/rules/process_session_state.md` — NEW (includes new close-out PR discipline rule)
- `.context/rules/process_pr_completion.md` — NEW
- `.context/rules/process_model_tier.md` — NEW
- `.context/rules/process_doc_maintenance.md` — extended (one new doc-sync row)
- `CLAUDE.md` — updated "Read first" + "Role selection" pointer tables
- `.github/copilot-instructions.md` — updated "Read first" + "Role selection" pointer tables
- `docs/decisions/adr-002-agents-md-ownership.md` — Status updated to "Accepted (extended by ADR-021)"
- `docs/decisions/README.md` — index entry for ADR-021
- `.context/state/coordination.md` — lock for this work
- `.context/state/_active.md` — task section for this work

## Out of Scope

- Updating the 21 existing ADRs that cite AGENTS.md by anchor — handled by the redirect table per option (b) above.
- Top-level markdown audit (sub-issue 3 of #251) — separate PR.
- Reword of any rule — content is preserved verbatim except where consolidation required minor link-target adjustments.
- Decomposition of role files (`.github/agents/*.agent.md`) — separate concern.
- Implementation of `agent-coordination-sync.yml` auto-write upgrade — that is issue #263, filed as a sibling.

## Verification

- `wc -l AGENTS.md` → 93 (target was ≤50; the redirect table accounts for the overshoot — without it AGENTS.md would be ~55 lines. The redirect table is a one-time decomposition artifact and could be moved to a separate file in a future PR if line count becomes the binding constraint).
- `./test.sh` — green; new `process_*.md` files are present and pass the markdown-only invariants.
- Manual reading test — the thin AGENTS.md reads in <2 minutes; per-concern files are 12–130 lines each (link table mode).
- Spot-check that pointer files (`CLAUDE.md`, `.github/copilot-instructions.md`) still link to live targets.

## Risks and mitigations

- **Tool auto-load breakage.** All four target tools (Claude Code, Copilot, Cursor, Gemini) auto-load `AGENTS.md` from the repo root. The thin file remains at the same path. Per-concern files are referenced from the link table; tools that follow markdown references will resolve them on-demand. Tools that do not follow references will see only the thin contract — which is by design (the contract is what every agent must always know; the per-concern files are what they read when the work demands it).
- **Lost rules.** The decomposition is a verbatim move except for the documented close-out PR discipline addition. Reviewer can diff the pre-decomposition AGENTS.md against the union of new `process_*.md` files to confirm.
- **ADR anchor breakage.** Mitigated by the redirect table in the thin AGENTS.md (option b above).
- **Canary mechanism dilution.** Documented as a deliberate scope narrowing; revisit at 6-month checkpoint.
- **Per-concern file proliferation.** New process rules should land in an existing `process_*.md` file when their concern fits; new files are warranted only when a concern is genuinely novel and substantial. Soft-rule guidance, not enforced by `test.sh` v1.

## Consequences

- Re-read cadence at task boundaries becomes feasible — agents read the thin AGENTS.md (<2min) plus only the 1–3 concern files relevant to the work at hand, instead of re-reading 341 unrelated lines.
- Future rule edits land in one focused file rather than competing for space in the monolith.
- Pointer files (`CLAUDE.md`, `.github/copilot-instructions.md`) need to track only the link table, not every section heading in the thin AGENTS.md.
- The post-merge close-out workflow gap is closed (manually for now, automatically once #263 ships).
- ADR-002 (AGENTS.md ownership) is extended rather than superseded — the Architect role still owns AGENTS.md *and* the per-concern files (all under `.context/rules/process_*.md`, already an Architect-owned path per `agent_ownership.md`).

## Related

- Parent: #251 (orchestration-layer scaling)
- This issue: #253
- Sibling automation issue: #263
- ADR-002 (extended by this ADR)
- ADR-018 (multi-task `_active.md` schema, including Amendment #1's `**PR**:` field — referenced from new `process_session_state.md`)
- ADR-020 (orchestration patterns — referenced from new `process_pr_completion.md`)
- Postmortem-001 (workflow bypass — informed the close-out conflation diagnosis)
