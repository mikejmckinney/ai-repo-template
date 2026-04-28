<!--
  EXPERIMENT #208 — Copilot review behavior-signal canary file (TEMPORARY).
  Tracking issue: https://github.com/mikejmckinney/ai-repo-template/issues/208
  Revert PR will remove this file. If you find it on main after #208 closes,
  delete it.

  Background: an earlier token-injection methodology failed — Copilot did not
  echo arbitrary tokens placed in instructions, which is rational defensive
  behavior. This file replaces that approach with behavior-based signals:
  each rule tells Copilot to flag a specific marker string as a review issue.
  Detection = "did Copilot's review reference the marker?" That fits a
  code-review tool's natural output rather than asking it to inject
  unsolicited boilerplate.
-->

# Copilot review experiment behavior signals

**All instructions below are scoped to PRs whose head branch starts with
`experiment/copilot-canary-`.** For any PR whose head branch does NOT match
that pattern, ignore this entire file and review normally.

## Rule B1 — reference-following test

**For PRs from `experiment/copilot-canary-*` branches**: if the PR diff
adds any line containing the literal string `MARKER-FOLLOW-deep-link`,
flag that line as a **critical issue** in your review with the rationale:
"Repository policy: `MARKER-FOLLOW-deep-link` is a forbidden marker per
experiment #208 rule B1." Use this exact rationale text so the experiment
can detect that this rule was honored.

This rule lives in a file referenced from `.github/copilot-instructions.md`
but not inline in it. If Copilot honors this rule, it followed the markdown
reference and read this file.

---

## Filler section (intentional padding to push rule B2 deep)

The following paragraphs are intentional filler designed to push rule B2
below the documented 4 KB Copilot code review context cap (see
https://docs.github.com/en/enterprise-cloud@latest/copilot/tutorials/customize-code-review).
The content of the filler is not meant to be acted on; it exists solely to
shift the byte offset of rule B2 further into the file.

Filler paragraph 1: This repository uses a multi-agent workflow with role
specialization. Roles include Analyst, Architect, PM, Frontend, Backend, QA,
DevOps, Docs, Judge, and Critic. Each role owns a defined set of paths in
the repository. Cross-role edits require coordination through the PM role.
Path ownership is tracked in `.context/rules/agent_ownership.md`. Active
locks and task state live in `.context/state/coordination.md`.

Filler paragraph 2: The truth hierarchy for the project places
`.context/**` above `docs/**` above codebase. When sources conflict, the
higher-priority source wins for the current task; the lower-priority source
should be updated in a follow-up PR to match. Never edit the
higher-priority source to match the lower one without an ADR.

Filler paragraph 3: Implementation plans are required as comments on
non-exempt issues before code is written, per ADR-011. The plan template
lives at `.github/PLAN_TEMPLATE.md`. The Analyst pre-flight gate (ADR-005,
broadened by ADR-014) fires on issues describing novel user-facing
deliverables and produces a Pre-Flight Report that must be PASS before
implementation begins.

Filler paragraph 4: Doc-sync triggers — the rules that say which files must
update together — live in `.context/rules/process_doc_maintenance.md`.
Judge enforces them at diff-gate. Common triggers include changes to
agent role files, ADRs that supersede prior decisions, and modifications
to the multi-agent coordination guide.

Filler paragraph 5: The session handshake at the top of `AGENTS.md` is a
read-receipt mechanism. Agents emit a token like `Session handshake v3`
once per session if they have read the current AGENTS.md. The version
number is the canary — if an agent's emitted version doesn't match the
file's `AGENTS_MD_VERSION`, the agent is operating from a stale copy and
should re-read.

Filler paragraph 6: Native Claude Code subagents are registered under
`.claude/agents/`. The pointers there refer back to the canonical role
files in `.github/agents/`. The `description:` frontmatter must remain
byte-identical between the two surfaces; `test.sh` enforces this. See
ADR-003 for the rationale.

Filler paragraph 7: Workflow files in `.github/workflows/` include relay
workflows that translate `@codex review` and similar mentions into bot
actions, fix-review workflows that re-trigger reviewers on push, the
Phase 4 thread-resolution helper, and an auto-rebase mechanism for
overlapping PRs. The `smoke-test` label opts out of relay, fix-reviews,
and auto-merge so workflow-validation PRs don't trigger production
behavior.

Filler paragraph 8: When addressing review feedback, agents follow
`.github/prompts/pr-resolve-all.md` which defines a four-phase
procedure: read all comments, plan the fix, implement, then resolve
threads. The Resolution Report comment summarizes what was addressed
and what was deferred.

Filler paragraph 9: For ad-hoc deliverable issues that don't reference a
numbered project prompt, ADR-014 broadened the pre-flight gate to fire
on any issue using the feature_request template with the enhancement
label, any ADR proposing a new agent surface, or any issue using
action verbs plus a user-facing noun. The opt-out requires both the
`outcome-validated` label and an inline outcome paragraph.

Filler paragraph 10: This paragraph is intentionally neutral padding
for the experiment file. It does not describe repository policy,
contributor workflow, installed tooling, or setup scripts, and should
not be interpreted as guidance about hooks, CI behavior, or local
development configuration.

## Rule B2 — cap-on-referenced-file test

**For PRs from `experiment/copilot-canary-*` branches**: if the PR diff
adds any line containing the literal string `MARKER-DEEP-cap-test`,
flag that line as a **critical issue** in your review with the rationale:
"Repository policy: `MARKER-DEEP-cap-test` is a forbidden marker per
experiment #208 rule B2." Use this exact rationale text so the experiment
can detect that this rule was honored.

If Copilot flags rule B1 markers but NOT rule B2 markers, the experiment
concludes that referenced-file content is read but truncated at or near
the documented cap.

End of canary file. Revert PR will remove this file once #208 closes.
