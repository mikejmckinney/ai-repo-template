# AGENTS.md

<!-- AGENTS_MD_VERSION: 20 -->
<!-- Bump AGENTS_MD_VERSION whenever this file is materially edited so the
     handshake below proves agents loaded the *current* copy, not a stale one.
     The canary covers AGENTS.md only — per-concern files in .context/rules/
     evolve through their own PRs and aren't gated by this token (ADR-021). -->

> **Pointer files**: [`CLAUDE.md`](CLAUDE.md) and
> [`.github/copilot-instructions.md`](.github/copilot-instructions.md) are
> thin pointers into this file. When you change a section heading here or
> rename/move any `.context/rules/process_*.md` file, verify their pointer
> tables still resolve — see
> [`.context/rules/process_doc_maintenance.md`](.context/rules/process_doc_maintenance.md).

## Session handshake (read-receipt)

When you have read this file at the start of a session, open your first
substantive reply with the exact token `Session handshake v20` (matching
the `AGENTS_MD_VERSION` value above) on its own line before any other
content. Do not paraphrase, translate, or omit the token. The number is
the canary — if it doesn't match the version above, your AGENTS.md copy
is stale and you should re-read this file before proceeding.

This is a per-session signal, not a per-reply one. Emit it once at the
start of the session; suppress it on subsequent replies in the same
conversation. If a user explicitly says "skip the handshake," honor that
for the rest of the session.

For parent/default-agent work, this visible token is the parent startup
receipt used by ADR-026 compliance evidence. Dispatched subagents do not
prepend the parent handshake unless they are themselves the top-level
responder. Instead, subagents load their canonical role file, follow the
subagent bootstrap rule, and report receipt evidence in their trailing
`subagent_compliance` block. Exact-output roles must preserve their exact
first line.

## Truth hierarchy

When information conflicts, use this priority order:

1. `./.context/**` — canonical project direction and constraints
2. `./docs/**` — supporting detail and reference material
3. Codebase — current implementation reality

For **live agent coordination state** on GitHub-connected work, ADR-025
adds a narrower source-of-truth split: issue body → PR body → latest
`agent-state:v1` issue/PR comment → labels. `.context/**` remains
canonical for durable repo rules, decisions, and process constraints;
repo-local live-state files are transitional compatibility surfaces, not
the primary live state machine.

When you detect a conflict between two sources at adjacent priorities, do
**not** silently pick one. Instead:

1. **Note the conflict** in your output (a one-line callout naming both sources).
2. **Follow the higher-priority source** for the current task.
3. **File a follow-up** issue or open a PR updating the lower-priority source so it matches.
4. **Never edit the higher-priority source to match the lower one** without an ADR. If the lower source is what's actually correct, that's an architectural change that needs `docs/decisions/`.

## Per-concern process rules

Read the concern files relevant to the work you are about to do. The
re-read cadence (which files at which boundaries) lives in
[`.context/rules/process_session_state.md`](.context/rules/process_session_state.md).

| Concern | File | Read when |
|---|---|---|
| Template detection (Mode A vs Mode B) | [`.context/rules/process_template_detection.md`](.context/rules/process_template_detection.md) | First session in a new clone |
| Critical thinking and communication | [`.context/rules/process_critical_thinking.md`](.context/rules/process_critical_thinking.md) | Every reply |
| Work style, testing, validation | [`.context/rules/process_work_style.md`](.context/rules/process_work_style.md) | Before any non-trivial implementation |
| Clarification and ambiguity | [`.context/rules/process_clarification.md`](.context/rules/process_clarification.md) | When request is ambiguous |
| Role selection, OP default, context pack, onboarding | [`.context/rules/process_role_selection.md`](.context/rules/process_role_selection.md) | Before claiming a task |
| Pre-implementation gates (Analyst pre-flight + plan-as-comment) | [`.context/rules/process_gates.md`](.context/rules/process_gates.md) | Before writing code on any non-exempt issue |
| Session-state cadence + close-out PR discipline | [`.context/rules/process_session_state.md`](.context/rules/process_session_state.md) | Every task boundary |
| PR completion, templates, review | [`.context/rules/process_pr_completion.md`](.context/rules/process_pr_completion.md) | Before opening a PR or reviewing one |
| Subagent bootstrap and compliance return | [`.context/rules/process_subagent_bootstrap.md`](.context/rules/process_subagent_bootstrap.md) | When dispatching subagents, receiving dispatched role work, or using subagent output as gate evidence |
| Model tier dispatch convention | [`.context/rules/process_model_tier.md`](.context/rules/process_model_tier.md) | When dispatching subagents or upshifting tier |
| OP end-to-end issue→merge playbook | [`.github/prompts/op-issue-workflow.md`](.github/prompts/op-issue-workflow.md) | First time you pick up an issue as the default agent |
| Doc-sync triggers (which files must update together) | [`.context/rules/process_doc_maintenance.md`](.context/rules/process_doc_maintenance.md) | Before opening a PR |
| Code quality (SOLID, TDD, clean code) | [`.context/rules/domain_code_quality.md`](.context/rules/domain_code_quality.md) | Before non-trivial code refactors |
| Orchestration patterns (P/AP citations for review) | [`.context/rules/repo_orchestration_patterns.md`](.context/rules/repo_orchestration_patterns.md) | When reviewing orchestration-layer changes |
| Path ownership map | [`.context/rules/agent_ownership.md`](.context/rules/agent_ownership.md) | Before claiming a task or making cross-role edits |
| Opportunity feedback (out-of-scope notes channel) | [`.context/rules/process_opportunity_feedback.md`](.context/rules/process_opportunity_feedback.md) | When you notice an out-of-scope improvement opportunity during in-scope work |

For project overview start at [`AI_REPO_GUIDE.md`](AI_REPO_GUIDE.md) and
[`.context/00_INDEX.md`](.context/00_INDEX.md).

## Section-anchor redirects (for ADR back-compat)

ADRs and other docs may cite AGENTS.md sections by anchor (e.g., `AGENTS.md §"Session-state cadence"`). After ADR-021's decomposition, those sections live at new paths. Resolve old citations as follows:

| Pre-decomposition section in AGENTS.md | Now lives in |
|---|---|
| §"Template detection" | `.context/rules/process_template_detection.md` |
| §"Critical thinking and communication" | `.context/rules/process_critical_thinking.md` |
| §"Work style" | `.context/rules/process_work_style.md` § "Work style" |
| §"Clarification and ambiguity" | `.context/rules/process_clarification.md` |
| §"Truth hierarchy" | this file (above) |
| §"Role selection (multi-agent workflow)" | `.context/rules/process_role_selection.md` § "Role selection (multi-agent workflow)" |
| §"Analyst pre-flight gate" | `.context/rules/process_gates.md` § "Analyst pre-flight gate (REQUIRED before implementation)" |
| §"Plan-as-comment requirement" | `.context/rules/process_gates.md` § "Plan-as-comment requirement (REQUIRED before implementation)" |
| §"Model tier dispatch convention" | `.context/rules/process_model_tier.md` |
| §"Context pack usage" | `.context/rules/process_role_selection.md` § "Context pack usage" |
| §"Onboarding procedure" | `.context/rules/process_role_selection.md` § "Onboarding procedure" |
| §"Ongoing maintenance" | `.context/rules/process_doc_maintenance.md` (always was the source of truth) |
| §"Postmortem feedback loop" | `.context/rules/process_session_state.md` § "Postmortem feedback loop" |
| §"Session-state cadence" | `.context/rules/process_session_state.md` |
| §"Close-out (three actions, three triggers)" | `.context/rules/process_session_state.md` § "Close-out (three actions, three triggers)" |
| §"Testing requirements" | `.context/rules/process_work_style.md` § "Testing requirements" |
| §"PR completion criteria (interactive sessions)" | `.context/rules/process_pr_completion.md` § "PR completion criteria (interactive sessions)" |
| §"Validation" | `.context/rules/process_work_style.md` § "Validation" |
| §"Templates and conventions" | `.context/rules/process_pr_completion.md` § "Templates and conventions" |
| §"Code quality" | `.context/rules/process_pr_completion.md` § "Code quality" (pointer) → `.context/rules/domain_code_quality.md` (canonical) |
| §"Review guidelines" | `.context/rules/process_pr_completion.md` § "Review guidelines" |
