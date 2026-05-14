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
3. Post the plan as a new issue comment: `cat /tmp/plan-<N>.md | gh issue comment <N> -R <owner>/<repo> --body-file -`. **Always stdin form**, **always length-verify** (see [`/memories/gh-cli.md`](#) — `gh ... --body-file <path>` has silently dropped bodies; the workaround is stdin). Capture the comment URL + numeric ID; you'll edit this same comment for plan v2/v3 amendments rather than posting follow-up plan comments (see step 6 below).
4. Dispatch the `Judge` subagent in plan-gate mode. **Embed the full plan body verbatim in the dispatch packet** rather than relying only on the plan comment URL — subagent runtime tooling cannot reliably reach `gh api` / `curl` for remote fetches, and a Judge that cannot read the plan correctly returns `BLOCKED_ON_RUNTIME / NEEDS_CONTEXT` (the right behavior, but a wasted round-trip). Empirically observed on the Mode A dogfood test against sandbox issue #2 (May 2026): round 1 BLOCKED, round 2 with embedded body succeeded.
5. Judge returns APPROVE / REQUEST_CHANGES / BLOCK as a markdown verdict body. The parent OP posts each Judge verdict as a **separate** new comment on the issue (not an edit to a prior verdict) — verdicts are decision events whose timeline matters for the audit trail.
6. On REQUEST_CHANGES, dispatch Architect with the verdict items inlined. When the Architect returns an amendment, **edit the original plan comment in place** to fold the amendment into a new plan version (label sections `Plan v2 — amendments to v1` etc.); use `gh api --method PATCH /repos/{owner}/{repo}/issues/comments/<id> -F body=@-`. Keep Judge verdicts as separate comments per step 5. Iterate until APPROVE. **Fallback:** if the edited plan exceeds GitHub's ~65 KB single-comment limit, post the new version as a follow-up comment and edit a one-line stub into the original (`Plan superseded by v<N> at <link>`).
7. **Comment-extraction tooling note.** When extracting subagent output for posting, prefer line-number-based extraction (`grep -n` to locate boundaries, then `sed -n 'A,Bp'`) over pattern-range awk/sed (`awk '/start/,/end/'`) — embedded ` ```yaml ` fences inside the body will silently truncate range-pattern extractors. Verify byte length on disk against the post-server length immediately after each `gh ... comment` (the server normalizes newlines so values within ~50 bytes of each other are fine; orders-of-magnitude differences indicate truncation).

**Canary lifecycle:** if your plan touches anything that hardcodes the AGENTS.md version (the canary itself, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/compliance_schemas.md`, fixtures under `scripts/tests/fixtures/compliance/**`, etc.), enumerate every affected file in `doc_sync.companions.canary_lifecycle.grouped_files` so they all land in the same atomic commit. Missing one breaks the test suite the moment the canary bumps.

**Halt-gate:** Judge plan-gate APPROVE on the plan comment.

---

## Phase 4 — Branch + staged dispatch

**Goal:** execute the approved plan via the planned subagents, with live cadence updates.

**Actions:**

1. Create branch: `git checkout -b feat/<issue-number>-<short-slug> origin/main`.
2. Walk the plan's `dispatch_order` in order. For each stage, dispatch the named role via `runSubagent` with a dispatch packet containing: role, goal, expected output, plan/issue link, process files to load, owned-paths constraints, gate state, current `AGENTS_MD_VERSION`, and any allowed deviations (per [`.context/rules/process_subagent_bootstrap.md`](../../.context/rules/process_subagent_bootstrap.md)). **Self-state-tick reminder.** If the dispatch will produce or update an artifact whose own body lists items that this dispatch completes (an ADR's Implementation checklist, a plan's `dispatch_order` checkboxes, a postmortem's action items, etc.), include in the dispatch packet an explicit instruction: "If your edit completes any item listed elsewhere in your output or in the file you're editing, tick that item in the same edit batch." The Mode A dogfood test (sandbox issue #2, May 2026) caught a recurring Critic finding that mechanically-executed playbooks ship ADRs whose Implementation section disagrees with the PR they land in — this reminder closes that hole at dispatch time, not in review.
3. Each subagent returns either a real commit + push (verify via `git fetch && git log origin/<branch> -1`) OR `BLOCKED_ON_RUNTIME` with an `apply_replays` block. **Never trust a "push succeeded" claim without fetching to confirm** — runtime ghost-success is a known failure mode in some agent surfaces.
4. After every stage handoff, post a fresh `agent-state:v1` comment on the issue with `stage_completed`, `handoff: <next-role>`, `next_action`, and any process feedback. **This is the recurrence-prevention discipline** — issue #313 exists because PR #311 backfilled the entire `agent-state:v1` cadence at close-out instead of updating live. Cadence rule: [`.context/rules/process_session_state.md`](../../.context/rules/process_session_state.md).
5. **Apply_replays absorption (parent-OP path).** If a subagent's runtime is dead and it returns `BLOCKED_ON_RUNTIME` with an `apply_replays[]` block, parent OP applies it directly. The full ritual:
   1. Read the subagent's text output; locate each `=== FILE: <path> ===` block with its OLD/NEW pairs (or full-file replacement).
   2. Apply via your editor's batched-edit primitive (`multi_replace_string_in_file` is idiomatic for this) so all edits land in a single tool call — makes the diff atomic and reduces the chance of a partial apply.
   3. Stage and commit with `git add -A && git commit --no-gpg-sign -m "<role>(#<issue>): <stage> via apply_replays"`. The `--no-gpg-sign` flag is required when the worktree is in a runtime that doesn't have signing keys configured (codespaces, container sandboxes); without it the commit silently fails or hangs.
   4. Push: `git push <remote> HEAD:<branch>`.
   5. **Anti-ghost-success verification (mandatory).** Immediately run `git fetch <remote> && git log <remote>/<branch> -1 --oneline` and confirm the SHA matches your local HEAD. This is the same check as step 3 above for real-commit subagents — the apply_replays path bypasses the subagent's own push, so the parent OP must run the verification on the subagent's behalf.
   6. Note the substitution in the next agent-state comment: list the absorbed subagent role, the apply_replays summary line(s) from its compliance block, and the resulting commit SHA. This is the audit trail proving the parent didn't fabricate the work.

**Multi-PR-per-issue scenario (when the plan ships across separate PRs).** Some plans span multiple ownership boundaries that should not land atomically (e.g., Architect + DevOps + Docs ship together, but the PM-owned coordination-state cleanup ships on its own cadence; or one stage is high-risk and gets a separate review surface). The plan's `dispatch_order` should explicitly mark which stages share a PR and which split, and the Judge plan-gate (Phase 3) verifies the split is justified. When executing:

- Use a stable branch-naming convention: `<base-branch>-<scope-marker>-<role>` (e.g., `test/sandbox-mode-a-issue2-stage3-pm`). The `<scope-marker>` lets a reader scanning branch listings see which PR a branch belongs to.
- Each PR-bearing stage gets its own pre-PR Phase 5 (its own Critic + Judge diff-gate pair) on the diff that PR will ship. Do not batch multiple PRs into one Phase 5 — their owned paths and risk profiles differ.
- Each PR-bearing stage gets its own Phase 6 PR open + pr-resolve-all loop. The cadence comment trail on the parent issue links each PR as it opens (`Stage N PR opened: #MMM`).
- If one PR's prose references content that lands in another (e.g., Stage 3 references an ADR that lands on Stage 1+2's PR), add a `Depends on #MMM` line to the PR body and the same merge-order constraint to the cadence comment. See Phase 6 step 1.5 for the convention.

**Default-branch-only workflow PRs (special case).** If your plan touches a `.github/workflows/*.yml` whose triggers fire only from the default branch ref — see the [Workflow verifiability matrix](../../docs/guides/agent-pipeline.md#workflow-verifiability-matrix) for the canonical list (`pull_request_review`, `pull_request_review_comment`, `pull_request_target`, `issue_comment`, `push`, `schedule`, `workflow_run`) — the in-repo `git fetch && git log` verification above is necessary but not sufficient: the workflow itself cannot fire on a feature branch and so the change is unverifiable in this repo pre-merge. Switch to the sandbox sibling repo per [`docs/guides/sandbox-verification.md`](../../docs/guides/sandbox-verification.md): land the change there first, exercise the trigger event end-to-end, capture run links as evidence, then re-open the upstream PR with the sandbox evidence in the `parent_compliance.verification_results[]` block. ADR-016 is the durable rationale.

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
   1.5. **Cross-PR dependency convention.** If this PR's prose references content that lands in a different PR (companion PR per the multi-PR-per-issue scenario in Phase 4), add an explicit `Depends on #MMM` line near the top of the PR body and a one-line warning under it: `⚠ Do not merge before #MMM lands — references in this PR will be dangling otherwise.` The cadence comment on the parent issue should also list the dependency in plain English. There is no automated branch-protection rule enforcing this in the template repo; the Depends-on convention is the lightweight contract that Critic / Judge / human reviewers can check.
2. PR body must include the `parent_compliance` block from [`.github/pull_request_template.md`](../pull_request_template.md), with `subagents_dispatched` listing every subagent's `subagent_compliance` (including `BLOCKED_ON_RUNTIME` cases with the `apply_replays` records absorbed by parent OP).
3. PR body MUST include a "User outcome validation — PRIMARY" section per ADR-016 — a verbatim transcript of the user confirming the outcome works for them. Synthetic test runs are PRIMARY for outcome-shaped issues; for pure repo-process issues, a brief note explaining why outcome validation is structural is acceptable.
4. Run [`.github/prompts/pr-resolve-all.md`](pr-resolve-all.md) until two consecutive quiet rounds (no new bot review threads). Cap-override available via `cap-override` label or `@<agent> cap-override N` PR comment per repo variable `PR_RESOLVE_MAX_ROUNDS`.
5. **Final Judge diff-gate (post pr-resolve-all).** If pr-resolve-all changed *any* code in step 4 (not just review-thread comment replies), re-dispatch `Judge` in diff-gate mode against the **PR's current head SHA** with the original plan comment. This is a distinct event from the Phase 5 pre-PR diff-gate — pr-resolve-all rounds frequently introduce new edits in response to bot findings, and the plan-vs-final-diff invariant must hold against the SHA that will actually merge, not the one Phase 5 reviewed. If pr-resolve-all only added comment replies and resolved threads (no new commits), this re-dispatch is a no-op and the Phase 5 verdict carries; record "no code change since Phase 5" in the cadence comment instead of re-dispatching.

**Halt-gate:** 2 quiet rounds + final Judge diff-gate APPROVE on the PR's current head SHA + green CI.

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
- Sandbox verification (Phase 4 / default-branch-only workflow PRs): [`docs/guides/sandbox-verification.md`](../../docs/guides/sandbox-verification.md)
- Onboarding (precedes this playbook): [`.github/prompts/repo-onboarding.md`](repo-onboarding.md)
- ADRs: [`docs/decisions/adr-005-analyst-preflight-gate.md`](../../docs/decisions/adr-005-analyst-preflight-gate.md), [`docs/decisions/adr-011-plan-as-comment-requirement.md`](../../docs/decisions/adr-011-plan-as-comment-requirement.md), [`docs/decisions/adr-014-extend-preflight-to-adhoc-deliverables.md`](../../docs/decisions/adr-014-extend-preflight-to-adhoc-deliverables.md), [`docs/decisions/adr-016-pre-merge-verification-gate.md`](../../docs/decisions/adr-016-pre-merge-verification-gate.md), [`docs/decisions/adr-021-agents-md-decomposition.md`](../../docs/decisions/adr-021-agents-md-decomposition.md), [`docs/decisions/adr-025-github-issues-pr-comments-as-live-state.md`](../../docs/decisions/adr-025-github-issues-pr-comments-as-live-state.md), [`docs/decisions/adr-026-compliance-contracts.md`](../../docs/decisions/adr-026-compliance-contracts.md)
