# PR completion, templates, review

> Extracted from AGENTS.md §"PR completion criteria", §"Templates and conventions", §"Review guidelines", and §"Code quality" in PR for #253 (ADR-021).
> Read before opening a PR or reviewing one.

## PR completion criteria (interactive sessions)

Opening a PR is **not** "done" when the same agent that opened the PR is still running in an interactive session. The PR is done when CI is green AND every bot-authored review thread is either resolved or explicitly deferred. Merging is the maintainer's call, not the agent's — do not wait on merge to declare the work complete, but do not declare it complete before the loop below converges.

After pushing the PR, run this loop until it converges:

1. **Wait for the CI rollup.** If anything red, read logs, fix the underlying issue, push, and re-enter the loop. Do not weaken tests or add `--no-verify` to dodge a real failure (see [`process_work_style.md`](process_work_style.md)).
2. **Pre-merge verification (sandbox-class PRs).** If your Implementation Plan declared `Change class: default-branch-only workflow` (or `mixed` with a default-branch-only path), the PR is **not** done until the change has been verified end-to-end in the sandbox sibling repo per [`docs/guides/sandbox-verification.md`](../../docs/guides/sandbox-verification.md). Paste the green sandbox-run URL into a comment on the PR. The trigger constraint (workflows pinned to default-branch execution can't be exercised on the PR branch) is structural — see ADR-016 and `docs/guides/agent-pipeline.md` § "Workflow verifiability matrix". Skipping this for sandbox-class PRs is the failure mode that produced the 11-round PR #225 cycle.
3. **Check bot-authored reviews** (Copilot review, Gemini, etc.). If any are present, address them following `.github/prompts/pr-resolve-all.md` Phases 1–4. That prompt defines what counts as "addressed" (Phase 2 status set: `✅ Fixed`, `✅ Already resolved`, `⚠️ Needs clarification`, `⚠️ Partial fix`, `❌ Not reproducible`, `❌ Out of scope`); do not invent labels or redefine the set here.
4. **After your fix-commit lands, re-check.** Bot re-review on push is opportunistic today (the re-review-on-push automation tracked in #205 — distinct from the existing thread-resolution relay in `agent-relay-reviews.yml` — is not yet shipped); if a re-review didn't fire, re-read the PR yourself before declaring done. Loop until clean.

**Stop condition.** PR is clean when:

- CI is green.
- Every bot thread is either auto-resolved by `pr-resolve-all.md` Phase 4 (only when its Phase 2 status is `✅ Fixed`) or left open with a deferral reply (for `❌ Out of scope` / `❌ Not reproducible` / `⚠️` outcomes — humans expect to acknowledge those themselves).
- Your Resolution Report is posted per `pr-resolve-all.md` Phase 3.

**Escape valve.** If a bot finding is intentionally out-of-scope or wrong:

1. Post a one-line deferral reply on the thread explaining why.
2. **Leave the thread open** for human acknowledgement (per `pr-resolve-all.md` → "Safety rules": never resolve a thread whose Phase 2 item is not `✅ Fixed`).

"Deferred with comment, awaiting human acknowledgement" counts as addressed. Silently ignoring a bot finding does not.

**Does NOT apply to**:

- **Copilot's cloud SWE agent.** Its session ends at PR creation; the loop is handled out-of-band by `agent-fix-reviews.yml` + `agent-relay-reviews.yml` via webhook events. See [docs/guides/multi-agent-coordination.md](../../docs/guides/multi-agent-coordination.md#branch-per-role-model).
- **Bot-authored PRs** (Renovate, Dependabot, etc.). Maintainer reviews those.
- **PRs marked `draft`.** These are explicitly not "ready for review yet."

## User outcome validation — PRIMARY

Before requesting review, the PR body must include a `## User outcome validation — PRIMARY`
section for non-exempt work.

The section must include:

1. **Steps performed** — the concrete manual or automated steps used to perform
   the issue's `User outcome (15-minute test)`.
2. **Evidence** — links, excerpts, transcripts, screenshots, PR/issue citations,
   command output, or other concrete evidence. Bash output alone is insufficient
   unless the user outcome was itself a script.
3. **Result** — one of:
   - `problem statement resolved`
   - `not resolved`
   - `framing disconnect`
   - `blocked`
4. **Explanation** — a brief note tying the evidence to the result, especially
   when the result is anything other than `problem statement resolved`.

If the result is `not resolved`, `framing disconnect`, or `blocked`, the PR is
not ready for normal review until the issue, plan, or implementation is revised.

### Meta/process issue validation example

For issues where the user outcome is reviewability — for example, "a reviewer
can inspect the plan and PR body and answer these questions" — the validation is
not a product demo or a shell command.

The correct evidence is a checklist walk-through against the actual plan and PR
body, with citations or links for each answer.

Example:

- Question: Did the parent/default agent emit the current AGENTS.md handshake?
  Evidence: PR `parent_compliance.handshake_token`.
  Result: yes/no.

- Question: Which subagents were planned and which actually ran?
  Evidence: plan `role_dispatch.planned_subagents` and PR
  `parent_compliance.subagents_dispatched`.
  Result: yes/no.

## Templates and conventions

GitHub auto-populates issue and PR templates only in the browser flow, not when an agent uses `gh` / MCP / API. Agents must apply them explicitly. The issue templates start with a YAML front-matter block delimited by `---`; that block is metadata for GitHub's template chooser, not body text. Strip the front-matter and copy only the Markdown content after the closing `---` into the issue/PR body.

- **Creating issues programmatically** — use the body skeleton from the matching `.github/ISSUE_TEMPLATE/{feature_request,bug_report,agent_init}.md` file (Markdown body only; strip the leading YAML front-matter).
- **Creating PRs programmatically** — use the body skeleton from [`.github/pull_request_template.md`](../../.github/pull_request_template.md) (no front-matter to strip in this file). The **Doc sync** checklist is REQUIRED; Judge enforces it at diff-gate.
- **Addressing review feedback on a PR you authored** — follow `.github/prompts/pr-resolve-all.md` (Phases 1–4) so the Resolution Report and Phase 4 thread-resolution land consistently. This applies even when no `@<agent> follow` mention has been posted; ad-hoc fixes skip the audit trail.
- **Bundling small follow-ups vs. splitting** — see `docs/guides/agent-best-practices.md` → "Issue and PR Granularity."
- If a section the work needs is missing from a template, **update the template in the same PR** rather than skipping the section.
- **Compliance evidence (ADR-026)** — when a PR uses dispatched subagents or
	claims compliance evidence, include a `parent_compliance` block in the PR
	body. If the current PR template lacks a dedicated section, add it manually.
	Copy parsed `subagent_compliance` objects into
	`parent_compliance.subagents_dispatched`; do not paste raw YAML-in-YAML as
	the only evidence.

## Code quality

Universal SOLID / TDD / clean-code rules are defined as Hard rules H1–H8 and Soft rules S1–S6 in [`domain_code_quality.md`](domain_code_quality.md). Secrets hygiene (no secrets in code or logs) and the ~200-line file guideline live in `docs/guides/agent-best-practices.md`. Do not duplicate these in AGENTS.md or role agent files — link to the relevant rule IDs or guide sections instead.

## Review guidelines

- Block on failing CI/tests or missing test coverage for changed behavior.
- Require exact repro/verification commands for any functional change.
- Prefer minimal diffs; avoid drive-by refactors.
- No secrets/PII in logs.
- Call out risk areas: authz, data migrations, concurrency, perf regressions.
- For changes to the orchestration layer (`AGENTS.md`, `.context/rules/**`, `.github/agents/**`, `.github/workflows/**`, `scripts/**`), cite entries from [`repo_orchestration_patterns.md`](repo_orchestration_patterns.md) by ID (`P1`–`P9`, `AP1`–`AP9`) when flagging or blocking. The `H<n>`/`S<n>` rules in `domain_code_quality.md` cover code-layer review; `P<n>`/`AP<n>` cover orchestration-layer review.
- For ADR-026 compliance evidence, Judge and Critic challenge missing or
	malformed `parent_compliance`, missing `subagent_compliance`, generic
	evidence such as "read all docs", use of `overlay_version`, skipped pointers
	with vague reasons, and any claim that CI or the repo can prove runtime
	dispatch behavior. Missing compliance evidence is `REQUEST_CHANGES` in v1
	unless the same omission also violates an existing hard gate.
