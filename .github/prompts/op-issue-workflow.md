# OP issue→merge playbook

> **Mode:** persistent — read top to bottom on first pickup of an issue, then halt-and-resume per phase.
> **Audience:** the default agent (Parent Orchestrator) per `.context/rules/process_role_selection.md` §"Default role: Parent Orchestrator (OP)".
> **Style:** mirrors `.github/prompts/pr-resolve-all.md` halt/resume convention. Each phase has a goal, concrete actions, a halt-or-continue gate, and a pointer to the rule file that codifies the behavior.

This playbook captures the ideal end-to-end workflow for taking an issue from intake to merged PR. It exists because PR #311 dropped both `plan_compliance:` and `agent-state:v1` evidence (issue #313 — recurrence-prevention).

> **Important — never hardcode the canary.** Every phase that records the AGENTS.md handshake token or version MUST read the **current** value from `AGENTS.md` at the time the work happens. Do not paste literal version numbers from this playbook into new plans, comments, or compliance blocks; the version drifts every time AGENTS.md is materially edited (ADR-021), so a hardcoded reference will silently go stale.

## Read first

- [`AGENTS.md`](../../AGENTS.md) — truth hierarchy, handshake token, per-concern table.
- [`.context/00_INDEX.md`](../../.context/00_INDEX.md) — project memory entry point.
- [`.context/rules/process_role_selection.md`](../../.context/rules/process_role_selection.md) — OP defaults and direct-implementation gate.
- [`.context/rules/process_session_state.md`](../../.context/rules/process_session_state.md) — `agent-state:v1` cadence and close-out triggers.
- [`docs/compliance_schemas.md`](../../docs/compliance_schemas.md) — `plan_compliance` / `parent_compliance` / `subagent_compliance` v1 schemas (ADR-026).

---

## Phase 0 — Session bootstrap

**Goal:** load process context and emit the per-session handshake.

**Actions:**

1. Read `AGENTS.md` end-to-end.
2. Note the **current** `AGENTS_MD_VERSION` value at the top of the file (it changes every material edit per ADR-021). Read the canary token next to it (e.g., the `Session handshake vN` line in §"Session handshake (read-receipt)").
3. Emit that exact token on its own line as the first substantive content of your reply. **This is the parent startup receipt for ADR-026.** Do not paraphrase the number — copy it verbatim from the file you just read.
4. Identify your role. Default = Parent Orchestrator (OP) unless the user explicitly assigned one of the ten canonical roles (see [`.context/rules/process_role_selection.md`](../../.context/rules/process_role_selection.md) §"Default role: Parent Orchestrator (OP)").
5. Read [`.context/rules/process_critical_thinking.md`](../../.context/rules/process_critical_thinking.md) (every reply) and [`.context/rules/process_session_state.md`](../../.context/rules/process_session_state.md) (cadence).

**Halt-gate:** handshake token emitted with the current AGENTS_MD_VERSION value; role identified.

---

## Phase 1 — Entry mode detection (Mode A vs Mode B)

**Goal:** establish whether you are picking up an existing issue or creating one from scratch.

### Mode A — issue already exists

The user gave you an issue number, link, or "work on #N". Take this path.

**Actions:**

1. `gh issue view <N> -R <owner>/<repo>` — read the body verbatim.
2. `gh issue view <N> --comments` — read every comment, especially any `agent-state:v1` blocks (latest one is authoritative live state per ADR-025).
3. Read all labels — `chore:no-plan`, `outcome-validated`, and similar gating labels change downstream behavior.
4. Identify any prior plan, plan-gate verdict, partial work, or branch claim already in the comment thread.
5. If a plan already exists and is APPROVED, jump to Phase 4 (you are resuming, not starting). If a plan exists but is REQUEST_CHANGES, jump to Phase 3 and produce a v2.
6. If no plan exists, continue to Phase 2.

### Mode B — no issue exists yet

The user described work without filing an issue ("can you fix X", "we should add Y"). Take this path.

**Actions:**

1. Ask the user a **single** clarifying question only if the desired outcome is genuinely ambiguous — see [`.context/rules/process_clarification.md`](../../.context/rules/process_clarification.md). Otherwise infer the most useful intent and proceed.
2. Draft an issue body using one of the templates under [`.github/ISSUE_TEMPLATE/`](../ISSUE_TEMPLATE/) (or the repo's default issue template if none matches). Include: problem statement, scope/non-goals, acceptance criteria, references.
3. Create the issue: `cat /tmp/issue.md | gh issue create -R <owner>/<repo> --title "<title>" --body-file -` (always stdin form per `/memories/gh-cli.md`; verify body length immediately afterward via `gh issue view <N> --json body --jq '.body | length'`).
4. From here on, treat the work as Mode A starting at Phase 2.

**Halt-gate:** issue URL recorded; mode noted.

---

## Phase 2 — Analyst pre-flight (only if non-trivial)

**Goal:** validate "should we build this" before architecture spend, per ADR-005 / ADR-014.

**Decision tree:**

- **Exempt** if the issue is pure repo-process / ADR / doc-sync / canary-bump work (no end-user surface, no product shape). Record the exemption explicitly in the plan_compliance block (`adr_required.required: false` + a `supersession_notes` or `exemption_reason` field).
- **Required** if the issue describes a product capability, an external contract change, or anything that could end up in the user-visible repo guide.

**Actions when required:**

1. Dispatch the `Analyst` subagent via `runSubagent` with the issue body verbatim.
2. Wait for verdict (research artifact, not implementation).
3. Post the verdict as a comment on the issue.

**Halt-gate:** Analyst verdict recorded OR exemption justified inline in the plan.

---

## Phase 3 — Plan-as-comment + Judge plan-gate

**Goal:** produce a reviewable plan and gate it before writing any code (ADR-011, ADR-026).

**Actions:**

1. Dispatch the `Architect` subagent via `runSubagent` with the issue body, prior comments, and Phase 2 verdict (or exemption rationale) as context.
2. Architect returns a plan body conforming to [`.github/PLAN_TEMPLATE.md`](../PLAN_TEMPLATE.md) and [`docs/compliance_schemas.md`](../../docs/compliance_schemas.md) §"`plan_compliance` v1". The plan_compliance block MUST include:
   - `schema_version: 1`
   - `applicable_roles: [...]`
   - `instruction_resources: [...]` (each with the canonical-rule path + evidence string)
   - `role_dispatch.decision` (one of `monolithic` / `staged-dispatch` / `parallel-dispatch`) with `planned_subagents` and (for staged) `dispatch_order` listing per-stage rationale
   - `plan_gate.status: pending`
   - `adr_required: { required: bool, link: ..., supersession_notes: ... }`
   - `doc_sync.companions: [...]` (any same-PR-atomic doc/fixture bumps; see "Canary lifecycle" below)
   - `verification: [<command>, ...]`
   - `handshake_token: <CURRENT token at plan time>` — copy from `AGENTS.md` right now; do **not** paste a literal `vN` from this playbook.
3. Post the plan as a new issue comment: `cat /tmp/plan-<N>.md | gh issue comment <N> -R <owner>/<repo> --body-file -`. **Always stdin form**, **always length-verify** (see [`/memories/gh-cli.md`](#) — `gh ... --body-file <path>` has silently dropped bodies; the workaround is stdin).
4. Dispatch the `Judge` subagent in plan-gate mode with the plan comment URL.
5. Judge returns APPROVE / REQUEST_CHANGES / BLOCK. On REQUEST_CHANGES, return to Architect with the verdict items inlined; iterate until APPROVE.

**Canary lifecycle:** if your plan touches anything that hardcodes the AGENTS.md version (the canary itself, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/compliance_schemas.md`, fixtures under `scripts/tests/fixtures/compliance/**`, etc.), enumerate every affected file in `doc_sync.companions.canary_lifecycle.grouped_files` so they all land in the same atomic commit. Missing one breaks the test suite the moment the canary bumps.

**Halt-gate:** Judge plan-gate APPROVE on the plan comment.

---

## Phase 4 — Branch + staged dispatch

**Goal:** execute the approved plan via the planned subagents, with live cadence updates.

**Actions:**

1. Create branch: `git checkout -b feat/<issue-number>-<short-slug> origin/main`.
2. Walk the plan's `dispatch_order` in order. For each stage, dispatch the named role via `runSubagent` with a dispatch packet containing: role, goal, expected output, plan/issue link, process files to load, owned-paths constraints, gate state, current `AGENTS_MD_VERSION`, and any allowed deviations (per [`.context/rules/process_subagent_bootstrap.md`](../../.context/rules/process_subagent_bootstrap.md)).
3. Each subagent returns either a real commit + push (verify via `git fetch && git log origin/<branch> -1`) OR `BLOCKED_ON_RUNTIME` with an `apply_replays` block. **Never trust a "push succeeded" claim without fetching to confirm** — runtime ghost-success is a known failure mode in some agent surfaces.
4. After every stage handoff, post a fresh `agent-state:v1` comment on the issue with `stage_completed`, `handoff: <next-role>`, `next_action`, and any process feedback. **This is the recurrence-prevention discipline** — issue #313 exists because PR #311 backfilled the entire `agent-state:v1` cadence at close-out instead of updating live. Cadence rule: [`.context/rules/process_session_state.md`](../../.context/rules/process_session_state.md).
5. If a subagent's runtime is dead, parent OP applies the `apply_replays` content directly and notes the substitution in the next agent-state comment with attribution.

**Halt-gate:** every planned subagent in `dispatch_order` has either landed a real commit or had its `apply_replays` absorbed by parent OP.

---

## Phase 5 — QA + Critic + Judge diff-gate

**Goal:** prove the diff actually does what the plan claimed, before opening the PR.

**Actions:**

1. Run every command in the plan's `verification:` block locally on the branch tip. Capture output.
2. Dispatch `QA` subagent if the plan added or changed test coverage; QA validates fixtures, coverage thresholds, and the test plan walkthrough.
3. Dispatch `Critic` subagent with the diff. Critic reads as a devil's advocate — surfaces hidden assumptions, AI clichés ("comprehensive", "robust", "production-grade" without evidence), unjustified abstractions, scope creep beyond the plan.
4. Dispatch `Judge` in diff-gate mode with the diff and the original plan comment. Judge confirms: every plan deliverable landed, no out-of-scope changes, ownership respected, verification evidence sufficient.
5. On any REQUEST_CHANGES: cycle back through stage 4 with a focused dispatch to the relevant role.

**Halt-gate:** Judge diff-gate APPROVE.

---

## Phase 6 — Open PR + pr-resolve-all loop

**Goal:** ship the change through the public review surface.

**Actions:**

1. `cat /tmp/pr-body.md | gh pr create -R <owner>/<repo> --title "<title>" --base main --head feat/<issue>-<slug> --body-file -` (stdin form; length-verify per [`/memories/gh-cli.md`](#)).
2. PR body must include the `parent_compliance` block from [`.github/pull_request_template.md`](../pull_request_template.md), with `subagents_dispatched` listing every subagent's `subagent_compliance` (including `BLOCKED_ON_RUNTIME` cases with the `apply_replays` records absorbed by parent OP).
3. PR body MUST include a "User outcome validation — PRIMARY" section per ADR-016 — a verbatim transcript of the user confirming the outcome works for them. Synthetic test runs are PRIMARY for outcome-shaped issues; for pure repo-process issues, a brief note explaining why outcome validation is structural is acceptable.
4. Run [`.github/prompts/pr-resolve-all.md`](pr-resolve-all.md) until two consecutive quiet rounds (no new bot review threads). Cap-override available via `cap-override` label or `@<agent> cap-override N` PR comment per repo variable `PR_RESOLVE_MAX_ROUNDS`.

**Halt-gate:** 2 quiet rounds + final Judge diff-gate APPROVE on the PR diff (re-run if any code changed during pr-resolve-all rounds) + green CI.

---

## Phase 7 — Merge + close-out

**Goal:** land the change and close the loop per [`.context/rules/process_session_state.md`](../../.context/rules/process_session_state.md) §"Close-out (three actions, three triggers)".

**Actions:**

1. Squash-merge the PR. Use the issue title (or a refinement) as the squash subject; preserve the PR description in the squash body.
2. Verify the issue auto-closed via the PR body's `Closes #N` keyword. If not auto-closed, close manually.
3. Post a final `agent-state:v1` comment on the issue with `status: closed`, `merge_commit: <sha>`, `closeout_note:` (one-paragraph retrospective).
4. If the work surfaced a new lesson (canary ripple files missed by a plan, runtime quirk, doc drift), file a follow-up: postmortem under [`docs/postmortems/`](../../docs/postmortems/) per ADR-015, or a fresh issue using the same playbook.

**Halt-gate:** PR merged + issue closed + final `agent-state:v1` posted.

---

## Anti-patterns (recurrence-prevention)

These are the failure modes #313 exists to prevent. Read them once; check yourself against them before each halt-gate.

- **Backfilling cadence at close-out.** Posting a single `agent-state:v1` at the end of the work instead of one per stage handoff. The point of cadence is live coordination, not historical narration.
- **Hardcoding the canary.** Pasting `Session handshake v17` (or whatever today's value happens to be) into a plan, ADR, or downstream prompt instead of "the current handshake token in AGENTS.md". The canary drifts.
- **Trusting runtime ghost-success.** Claiming a subagent push succeeded without `git fetch && git log origin/<branch> -1` to confirm. Real failure mode this session: Architect and Docs both ghost-succeeded; PM actually pushed.
- **Absorbing role-owned work into the default agent.** "Just doing it directly" because dispatch overhead feels heavy. Direct implementation is gated by [`.context/rules/process_role_selection.md`](../../.context/rules/process_role_selection.md) §"Default role: Parent Orchestrator (OP)" — ≤ ~20 LOC, single file, single role, no role-sensitive surfaces.
- **`gh ... --body-file <path>` without length verification.** Has silently dropped bodies more than once (see [`/memories/gh-cli.md`](#)). Always pipe via stdin AND verify length.
- **Skipping plan-gate on a "small change".** ADR-011 has explicit exemptions (`chore:no-plan` label); use them rather than skipping the gate informally.

---

## Cross-references

- Truth hierarchy and handshake: [`AGENTS.md`](../../AGENTS.md)
- Project memory: [`.context/00_INDEX.md`](../../.context/00_INDEX.md)
- Role defaults / OP gate: [`.context/rules/process_role_selection.md`](../../.context/rules/process_role_selection.md)
- Cadence / close-out: [`.context/rules/process_session_state.md`](../../.context/rules/process_session_state.md)
- Pre-implementation gates: [`.context/rules/process_gates.md`](../../.context/rules/process_gates.md)
- Subagent bootstrap + compliance: [`.context/rules/process_subagent_bootstrap.md`](../../.context/rules/process_subagent_bootstrap.md)
- PR completion: [`.context/rules/process_pr_completion.md`](../../.context/rules/process_pr_completion.md)
- Plan template: [`.github/PLAN_TEMPLATE.md`](../PLAN_TEMPLATE.md)
- PR template: [`.github/pull_request_template.md`](../pull_request_template.md)
- pr-resolve-all (Phase 6): [`.github/prompts/pr-resolve-all.md`](pr-resolve-all.md)
- Onboarding (precedes this playbook): [`.github/prompts/repo-onboarding.md`](repo-onboarding.md)
- ADRs: [`docs/decisions/adr-005-analyst-preflight-gate.md`](../../docs/decisions/adr-005-analyst-preflight-gate.md), [`docs/decisions/adr-011-plan-as-comment-requirement.md`](../../docs/decisions/adr-011-plan-as-comment-requirement.md), [`docs/decisions/adr-014-extend-preflight-to-adhoc-deliverables.md`](../../docs/decisions/adr-014-extend-preflight-to-adhoc-deliverables.md), [`docs/decisions/adr-016-pre-merge-verification-gate.md`](../../docs/decisions/adr-016-pre-merge-verification-gate.md), [`docs/decisions/adr-021-agents-md-decomposition.md`](../../docs/decisions/adr-021-agents-md-decomposition.md), [`docs/decisions/adr-025-github-issues-pr-comments-as-live-state.md`](../../docs/decisions/adr-025-github-issues-pr-comments-as-live-state.md), [`docs/decisions/adr-026-compliance-contracts.md`](../../docs/decisions/adr-026-compliance-contracts.md)
