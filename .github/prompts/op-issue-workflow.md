---
description: End-to-end OP issue→merge playbook (Phase 0–7); the dispatchable form of the workflow PR #311 followed implicitly and #312 backfilled.
agent: agent
---

# OP issue→merge playbook

> **Mode:** persistent — read top to bottom on first pickup of an issue, then halt-and-resume per phase.
> **Audience:** the default agent (Parent Orchestrator) per `.context/rules/process_role_selection.md` §"Default role: Parent Orchestrator (OP)".
> **Style:** mirrors `.github/prompts/pr-resolve-all.md` halt/resume convention. Each phase has a goal, concrete actions, a halt-or-continue gate, and a pointer to the rule file that codifies the behavior.

This playbook captures the ideal end-to-end workflow for taking an issue from intake to merged PR. It exists because issue #313 surfaced an evidence-drift recurrence: PR #311 implicitly followed the workflow but dropped both `plan_compliance:` and `agent-state:v1` evidence; the gap was caught only after merge and backfilled by PR #312.

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
3. Create the issue: `cat "${TMPDIR:-/tmp}/issue-${USER}.md" | gh issue create -R <owner>/<repo> --title "<title>" --body-file -` (always stdin form per `/memories/gh-cli.md`; verify body length immediately afterward via `gh issue view <N> --json body --jq '.body | length'`).
4. From here on, treat the work as Mode A starting at Phase 2.

**Halt-gate:** issue URL recorded; mode noted.

---

## Phase 2 — Analyst pre-flight (only if non-trivial)

**Goal:** validate "should we build this" before architecture spend, per ADR-005 / ADR-014.

**Decision tree:**

- **Exempt** if the issue is pure repo-process / ADR / doc-sync / canary-bump work (no end-user surface, no product shape). Record the exemption explicitly in the plan_compliance block: set `adr_required.required: false` with a `supersession_notes` line explaining the exemption, AND set `plan_gate.gate_status: {triggered: false, applied: false}` (the schema-approved way to record that the gate didn't fire). The rationale itself goes in plan prose, not in the YAML block — ADR-029 §6 removed the free-form `exemption_reason` field because it was a self-exemption escape hatch. See [`docs/compliance_schemas.md`](../../docs/compliance_schemas.md) §`plan_compliance` v1.
- **Required** if the issue describes a product capability, an external contract change, or anything that could end up in the user-visible repo guide.

**Actions when required:**

1. Dispatch the `Analyst` subagent via `runSubagent` with the issue body verbatim.
2. Wait for verdict (research artifact, not implementation).
3. Post the verdict as a comment on the issue.

**Halt-gate:** Analyst verdict recorded OR exemption justified inline in the plan.

---

## Phase 3 — Plan-as-comment + Critic + Judge plan-gate

**Goal:** produce a reviewable plan and gate it before writing any code (ADR-011, ADR-026). Critic runs **before** Judge, mirroring the Phase 5 diff-gate ordering (ADR-029 §"Critic-before-Judge plan-gate ordering convention"). Critic surfaces hidden assumptions, AI clichés ("comprehensive", "robust", "production-grade" without evidence), unjustified abstractions, and scope creep on the *plan* so Judge renders APPROVE / REQUEST_CHANGES / BLOCK with full information rather than having to render twice when a later Critic pass surfaces issues.

**Actions:**

1. Dispatch the `Architect` subagent via `runSubagent` with the issue body, prior comments, and Phase 2 verdict (or exemption rationale) as context.
2. Architect returns a plan body conforming to [`.github/PLAN_TEMPLATE.md`](../PLAN_TEMPLATE.md) and [`docs/compliance_schemas.md`](../../docs/compliance_schemas.md) §"`plan_compliance` v1". The plan_compliance block MUST include exactly the v1-defined keys (the validator strictly rejects unknown keys — see `scripts/lib/compliance_schema.py` `_reject_unknown_keys`):
   - `applicable_roles: [...]`
   - `instruction_resources: [...]` (each object: `resource`, `why_applicable`, `evidence`, `decision_affected`)
   - `role_dispatch: { decision, planned_subagents, monolithic_justification }` — `decision` is one of `monolithic` / `staged-dispatch` / `parallel-dispatch`. Per-stage ordering and rationale belong in the plan's prose (e.g., a numbered "Dispatch order" section), NOT inside `role_dispatch` — the v1 schema does not accept a `dispatch_order` key.
   - `plan_gate: { status: pending, link: <plan-comment-url-when-known>, gate_status: { triggered: bool, applied: bool } }` — `gate_status` is descriptive only (per ADR-029 §6). If the issue is exempt from Analyst pre-flight, use `gate_status: {triggered: false, applied: false}` and put the rationale in plan prose.
   - `adr_required: { required: bool, link: ..., supersession_notes: [...] }`
   - `doc_sync: { triggered: bool, companions: [<path>, ...], no_change_justifications: [...] }` — `companions` is a flat list of non-empty path strings (the v1 validator's `_validate_doc_sync` calls `_require_string_list`; `{path, reason}` objects or any other shape will fail). Canary-lifecycle file groupings belong in the plan's prose, not in a nested `companions.canary_lifecycle.grouped_files` shape — that key is not in v1.
   - `verification: [<command>, ...]`

   **Out-of-schema concerns (capture in plan prose, not in the YAML block).** The following hold first-class authority for the plan but are NOT plan_compliance v1 keys; document them in the plan's prose, the plan-gate audit trail, or the related `parent_compliance` block at PR open time:

   - **Current handshake token.** Copy the literal `Session handshake v<N>` from `AGENTS.md` at plan time and quote it in the plan's introductory paragraph. The `parent_compliance` block at PR open time carries the structured `handshake_token` field (parent_compliance v1 owns it; plan_compliance v1 does not).
   - **Plan quality self-checks.** Architect MUST satisfy each before posting (Mode B dogfood test, sandbox issue #18 May 2026, surfaced both as MAJOR diff-gate findings that mechanical plan-checks missed). Record the result as a one-line note in the plan prose (e.g., under a "Plan quality" heading); do not invent a `plan_quality_checks` YAML key.
     - **Claims vs evidence.** Every prose verb in the plan ("verify", "prove", "validate", "demonstrate", "end-to-end") is supported by a verification command that actually demonstrates the claimed behavior. Existence checks (`ls`, `head`, `grep`) prove file presence, not behavior — match the verb to the evidence.
     - **Shell snippet portability.** Every shell snippet in the plan and in the deliverable's prose contains zero hardcoded values that won't survive template instantiation or fork-rename (no hardcoded repo names, user names, paths, or sandbox-specific identifiers in `cd`, `clone`, `cp`, `URL`, etc.). Use `$(basename <repo-url> .git)`, `${REPO}`, or explicit `<placeholder>` tokens with prose substitution notes.
3. Post the plan as a new issue comment: `cat "${TMPDIR:-/tmp}/plan-${USER}-<N>.md" | gh issue comment <N> -R <owner>/<repo> --body-file -`. **Always stdin form**, **always length-verify** (see `/memories/gh-cli.md` (agent user-memory note) — `gh ... --body-file <path>` has silently dropped bodies; the workaround is stdin). Capture the comment URL + numeric ID; you'll edit this same comment for plan v2/v3 amendments rather than posting follow-up plan comments (see step 7 below).
4. Dispatch the `Critic` subagent in plan-gate mode with the plan body inlined verbatim in the dispatch packet (same embed-don't-fetch rule as Judge in step 5). Critic returns a devil's-advocate review of the plan itself — hidden assumptions, AI clichés, unjustified abstractions, scope creep beyond the issue's acceptance criteria, conflated claims-vs-evidence in the plan's verification block. Post Critic's plan-review as a separate issue comment (stdin form + length-verify). If Critic surfaces blocking items, dispatch Architect with those items inlined and edit the plan comment in place (same in-place-edit discipline as step 7) before continuing to Judge. Critic before Judge avoids forcing Judge to render twice when a later Critic pass surfaces issues (ADR-029 §"Critic-before-Judge plan-gate ordering convention"; matches Phase 5 ordering).
5. Dispatch the `Judge` subagent in plan-gate mode. **Embed the full plan body verbatim in the dispatch packet** rather than relying only on the plan comment URL — subagent runtime tooling cannot reliably reach `gh api` / `curl` for remote fetches, and a Judge that cannot read the plan correctly returns `BLOCKED_ON_RUNTIME / NEEDS_CONTEXT` (the right behavior, but a wasted round-trip). Empirically observed on the Mode A dogfood test against sandbox issue #2 (May 2026): round 1 BLOCKED, round 2 with embedded body succeeded. Also embed the Critic plan-review from step 4 so Judge sees the upstream concerns and can either confirm them in its verdict or explicitly disagree.
6. Judge returns APPROVE / REQUEST_CHANGES / BLOCK as a markdown verdict body. The parent OP posts each Judge verdict as a **separate** new comment on the issue (not an edit to a prior verdict) — verdicts are decision events whose timeline matters for the audit trail.
7. On REQUEST_CHANGES, dispatch Architect with the verdict items inlined. When the Architect returns an amendment, **edit the original plan comment in place** to fold the amendment into a new plan version (label sections `Plan v2 — amendments to v1` etc.); use `gh api --method PATCH /repos/{owner}/{repo}/issues/comments/<id> -F body=@-`. Then re-dispatch Critic (step 4) on the amended plan before re-dispatching Judge (step 5) — the Critic-before-Judge ordering applies to every iteration, not only round 1. Keep Critic and Judge verdicts as separate comments per steps 4 and 6. Iterate until APPROVE. **Fallback:** if the edited plan exceeds GitHub's ~65 KB single-comment limit, post the new version as a follow-up comment and edit a one-line stub into the original (`Plan superseded by v<N> at <link>`).
8. **Comment-extraction tooling note.** When extracting subagent output for posting, prefer line-number-based extraction (`grep -n` to locate boundaries, then `sed -n 'A,Bp'`) over pattern-range awk/sed (`awk '/start/,/end/'`) — embedded ` ```yaml ` fences inside the body will silently truncate range-pattern extractors. Verify byte length on disk against the post-server length immediately after each `gh ... comment` (the server normalizes newlines so values within ~50 bytes of each other are fine; orders-of-magnitude differences indicate truncation).

**Canary lifecycle:** if your plan touches anything that hardcodes the AGENTS.md version (the canary itself, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/compliance_schemas.md`, fixtures under `scripts/tests/fixtures/compliance/**`, etc.), enumerate every affected file flatly in `doc_sync.companions: [<path>, ...]` so they all land in the same atomic commit. Group them in the plan's prose under a "Canary-lifecycle group" heading for human readers; the YAML block stays a flat list because v1 does not accept `companions.canary_lifecycle.grouped_files`. Missing one breaks the test suite the moment the canary bumps.

**Halt-gate:** Critic plan-review posted **and** Judge plan-gate APPROVE on the (post-Critic) plan comment.

---

## Phase 4 — Branch + staged dispatch

**Goal:** execute the approved plan via the planned subagents, with live cadence updates.

**Actions:**

1. Create branch following the documented convention in [`.context/rules/process_work_style.md`](../../.context/rules/process_work_style.md) §"Work style": `feature/<role>-<task-id>` for role-driven work, or `fix/<issue>-<slug>` for bug-fix branches. Example role-work form: `git checkout -b feature/architect-313-op-workflow origin/main`. Example bug-fix form: `git checkout -b fix/313-op-workflow-evidence origin/main`. The exact slug is author choice; the prefix and shape follow the rule.
2. Walk the plan's prose dispatch ordering (the "Dispatch order" section in the plan body, not a YAML field) in declared order. For each stage, dispatch the named role via `runSubagent` with a dispatch packet containing: role, goal, expected output, plan/issue link, process files to load, owned-paths constraints, gate state, current `AGENTS_MD_VERSION`, and any allowed deviations (per [`.context/rules/process_subagent_bootstrap.md`](../../.context/rules/process_subagent_bootstrap.md)). **Self-state-tick reminder.** If the dispatch will produce or update an artifact whose own body lists items that this dispatch completes (an ADR's Implementation checklist, a plan's `dispatch_order` checkboxes, a postmortem's action items, etc.), include in the dispatch packet an explicit instruction: "If your edit completes any item listed elsewhere in your output or in the file you're editing, tick that item in the same edit batch." The Mode A dogfood test (sandbox issue #2, May 2026) caught a recurring Critic finding that mechanically-executed playbooks ship ADRs whose Implementation section disagrees with the PR they land in — this reminder closes that hole at dispatch time, not in review.
3. Each subagent returns either a real commit + push (verify via `git fetch && git log origin/<branch> -1`) OR `BLOCKED_ON_RUNTIME` with an `apply_replays` block. **Never trust a "push succeeded" claim without fetching to confirm** — runtime ghost-success is a known failure mode in some agent surfaces.
4. After every stage handoff, **update the latest `agent-state:v1` comment on the issue** following the canonical template at [`.context/state/agent_state_comment_template.md`](../../.context/state/agent_state_comment_template.md): refresh the `Status:` enum value, the `Since last update` bullets, the `Next 1–3 actions` list, and the `Handoff` `To:` field. The comment is a **mutable baton** (ADR-025, [`.context/rules/process_session_state.md`](../../.context/rules/process_session_state.md)) — update it in place rather than scattering live state across multiple new comments per stage; only post a new comment when the previous one would otherwise be too far back in the timeline to find. **This is the recurrence-prevention discipline** — issue #313 exists because PR #311 backfilled the entire `agent-state:v1` cadence at close-out instead of updating live.
5. **Apply_replays absorption (parent-OP path).** If a subagent's runtime is dead and it returns `BLOCKED_ON_RUNTIME` with an `apply_replays[]` block, parent OP applies it directly. The full ritual:
   1. Read the subagent's text output; locate each `=== FILE: <path> ===` block with its OLD/NEW pairs (or full-file replacement).
   2. **Triple-backtick escape convention.** When a subagent's `apply_replays` payload contains content that itself includes triple-backtick code fences (e.g., a docs subagent inserting a fenced bash block into README), the inner fences will terminate the subagent's outer chat-reply code block prematurely, corrupting the payload. Convention: subagents prefix each inner fence with U+200B (zero-width space, `\u200B`) so the chat renderer doesn't treat them as fence terminators; parent OP **MUST strip U+200B from every fence line before applying** so the resulting file contains exactly ` ```bash ` and ` ``` ` (not `\u200B```bash`). Verify post-apply: `grep -P '\x{200B}' <file>` must return zero hits. Empirically observed on the Mode B dogfood test (sandbox issue #18 → PR #19, May 2026) when the Docs subagent inserted a Quick Start section with a fenced bash block.
   3. Apply via your editor's batched-edit primitive (`multi_replace_string_in_file` is idiomatic for this) so all edits land in a single tool call — makes the diff atomic and reduces the chance of a partial apply.
   4. Stage and commit with `git add -A && git commit --no-gpg-sign -m "<role>(#<issue>): <stage> via apply_replays"`. The `--no-gpg-sign` flag is required when the worktree is in a runtime that doesn't have signing keys configured (codespaces, container sandboxes); without it the commit silently fails or hangs.
   5. Push: `git push <remote> HEAD:<branch>`.
   6. **Anti-ghost-success verification (mandatory).** Immediately run `git fetch <remote> && git log <remote>/<branch> -1 --oneline` and confirm the SHA matches your local HEAD. This is the same check as step 3 above for real-commit subagents — the apply_replays path bypasses the subagent's own push, so the parent OP must run the verification on the subagent's behalf.
   7. Note the substitution in the next agent-state comment: list the absorbed subagent role, the apply_replays summary line(s) from its compliance block, and the resulting commit SHA. This is the audit trail proving the parent didn't fabricate the work.

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

1. `cat "${TMPDIR:-/tmp}/pr-body-${USER}.md" | gh pr create -R <owner>/<repo> --title "<title>" --base main --head <branch> --body-file -` (stdin form; length-verify per `/memories/gh-cli.md` (agent user-memory note)). The `<branch>` value MUST exactly match the branch you created in Phase 4 step 1 (one of `feature/<role>-<task-id>` or `fix/<issue>-<slug>`); a typo'd or guessed `--head` will fail at PR creation time.
   1.5. **Cross-PR dependency convention.** If this PR's prose references content that lands in a different PR (companion PR per the multi-PR-per-issue scenario in Phase 4), add an explicit `Depends on #MMM` line near the top of the PR body and a one-line warning under it: `⚠ Do not merge before #MMM lands — references in this PR will be dangling otherwise.` The cadence comment on the parent issue should also list the dependency in plain English. There is no automated branch-protection rule enforcing this in the template repo; the Depends-on convention is the lightweight contract that Critic / Judge / human reviewers can check.
2. PR body must include the `parent_compliance` block from [`.github/pull_request_template.md`](../pull_request_template.md), with `subagents_dispatched` listing every subagent's `subagent_compliance` (including `BLOCKED_ON_RUNTIME` cases with the `apply_replays` records absorbed by parent OP).
3. PR body MUST include a "User outcome validation — PRIMARY" section per ADR-016 and [`.context/rules/process_work_style.md`](../../.context/rules/process_work_style.md) §"Validation". The canonical form is concrete steps + evidence + result tied to the issue's `User outcome (15-minute test)`; tests/CI/lint are *supporting* evidence unless the user-outcome itself is a scripted command. A verbatim user transcript is one valid form of evidence but not the required form — for pure repo-process issues with no end-user-visible surface, a brief structural-validation note explaining why an outcome run is not applicable is acceptable.
4. Run [`.github/prompts/pr-resolve-all.md`](pr-resolve-all.md) until two consecutive quiet rounds (no new bot review threads in 6 minutes). Cap-override available via `cap-override` label or `@<agent> cap-override N` PR comment per repo variable `PR_RESOLVE_MAX_ROUNDS`.
5. **Final Judge diff-gate (post pr-resolve-all).** If pr-resolve-all changed *any* code in step 4 (not just review-thread comment replies), re-dispatch `Judge` in diff-gate mode against the **PR's current head SHA** with the original plan comment. This is a distinct event from the Phase 5 pre-PR diff-gate — pr-resolve-all rounds frequently introduce new edits in response to bot findings, and the plan-vs-final-diff invariant must hold against the SHA that will actually merge, not the one Phase 5 reviewed. If pr-resolve-all only added comment replies and resolved threads (no new commits), this re-dispatch is a no-op and the Phase 5 verdict carries; record "no code change since Phase 5" in the cadence comment instead of re-dispatching.

**Halt-gate:** 2 quiet rounds + final Judge diff-gate APPROVE on the PR's current head SHA + green CI.

---

## Phase 7 — Merge + close-out

**Goal:** land the change and close the loop per [`.context/rules/process_session_state.md`](../../.context/rules/process_session_state.md) §"Close-out (three actions, three triggers)".

**Actions:**

1. Ask the user for approval then Squash-merge the PR. Use the issue title (or a refinement) as the squash subject; preserve the PR description in the squash body.
2. Verify the issue auto-closed via the PR body's `Closes #N` keyword. If not auto-closed, close manually. **Auto-close caveat:** GitHub's `Closes #N` / `Fixes #N` / `Resolves #N` keywords only fire on PRs whose **base is the repository's default branch** ([reference docs](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue#linking-a-pull-request-to-an-issue-using-a-keyword)). PRs that target a non-default branch (long-lived integration branch, sandbox mainline, stacked-PR base, etc.) silently no-op the keyword on merge. If your PR base is non-default, plan for a manual `gh issue close <N> -R <owner>/<repo> --reason completed --comment "<link to merge commit>"` immediately after merge \u2014 don't assume the keyword fired. Empirically caught on the Mode A sandbox dogfood test (May 2026): PR #17 against `feat/313-op-issue-workflow` base merged cleanly but left sandbox issue #2 open until manual close.
3. Post a final `agent-state:v1` comment on the issue with `status: closed`, `merge_commit: <sha>`, `closeout_note:` (one-paragraph retrospective). **Mirror to the PR.** Also post a short closeout breadcrumb on the merged PR linking back to the issue's final cadence comment — by default GitHub leaves merged PRs without any closeout comment trail, so a reader landing on the PR has no pointer to the cadence/process feedback that lives on the issue. Minimum breadcrumb: one paragraph naming the merge SHA, the auto-close keyword outcome (fired or manual-closed), and a deep link to the issue's final `agent-state:v1` comment. Empirically caught on the Mode A sandbox dogfood test (May 2026): PRs #16 and #17 had no closeout trail; only the issue did. Mode B (sandbox PR #19) confirmed the breadcrumb is cheap and high-signal.
4. If the work surfaced a new lesson (canary ripple files missed by a plan, runtime quirk, doc drift), file a follow-up: postmortem under [`docs/postmortems/`](../../docs/postmortems/) per ADR-015, or a fresh issue using the same playbook.

**Halt-gate:** PR merged + issue closed + final `agent-state:v1` posted.

---

## Anti-patterns (recurrence-prevention)

These are the failure modes #313 exists to prevent. Read them once; check yourself against them before each halt-gate.

- **Backfilling cadence at close-out.** Posting a single `agent-state:v1` at the end of the work instead of one per stage handoff. The point of cadence is live coordination, not historical narration.
- **Hardcoding the canary.** Pasting `Session handshake v17` (or whatever today's value happens to be) into a plan, ADR, or downstream prompt instead of "the current handshake token in AGENTS.md". The canary drifts.
- **Trusting runtime ghost-success.** Claiming a subagent push succeeded without `git fetch && git log origin/<branch> -1` to confirm. Real failure mode this session: Architect and Docs both ghost-succeeded; PM actually pushed.
- **Absorbing role-owned work into the default agent.** "Just doing it directly" because dispatch overhead feels heavy. Direct implementation is gated by [`.context/rules/process_role_selection.md`](../../.context/rules/process_role_selection.md) §"Default role: Parent Orchestrator (OP)" — ≤ ~20 LOC, single file, single role, no role-sensitive surfaces.
- **`gh ... --body-file <path>` without length verification.** Has silently dropped bodies more than once (see `/memories/gh-cli.md` (agent user-memory note)). Always pipe via stdin AND verify length.
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
