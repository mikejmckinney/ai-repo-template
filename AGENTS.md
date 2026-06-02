# AGENTS.md

<!-- AGENTS_MD_VERSION: 22 -->
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
substantive reply with the following:

```text
Session handshake vAGENTS_MD_VERSION

| Field | Value |
|---|---|
| Agent | <copilot | claude | codex | cursor | gemini | other: name | unknown> |
| Role | <OP | architect | devops | docs | qa | judge | critic | analyst | pm | other> |
| Model | <exact model if exposed by runtime; otherwise `unknown — not exposed by runtime`> |
| AGENTS.md version | <version number> |
| Session type | <parent/default agent | dispatched subagent | other> |
| Dispatch mode | <plan-gate | diff-gate | n/a> |
| Read profile | <profile-name | full | none> |
```

Replace AGENTS_MD_VERSION with the version number specified in the HTML comment
at the top of this file. The session handshake should be on its own line before
any other content for parent agents; see the subagent rule below.

`Dispatch mode`: dispatched subagents record the mode from the dispatch packet
(`plan-gate` or `diff-gate`). Parent/default agents and non-exact-output
subagents use `n/a`. Required for Judge and Critic — see
`.context/rules/process_subagent_bootstrap.md` § "Positional output
contract".

`Read profile`: record the named profile used, `full` if all standard startup
files were loaded, or `none` if only AGENTS.md was loaded. Named profiles will
be defined in R4; use `full` until then.

This is a per-session signal, not a per-reply one. Emit it once at the start of
the session; suppress it on subsequent replies in the same conversation.

For parent/default-agent work, this token is the parent startup receipt required
by ADR-026 compliance evidence. Follow the handshake with a
`## Session context receipt` section (see below).

For dispatched subagents: emit your role-specific output **first**, so
exact-output contracts are satisfied (`DECISION:` is the literal first line for
Judge; `CRITIC DECISION:` for Critic). After the role body, append in order:

1. `## Subagent session handshake` — the 7-field table above.
2. `## Subagent context receipt` — the file table from `## Session context receipt`.
3. `subagent_compliance` YAML block.

**`subagent_compliance` (item 3) is required for all dispatched subagents.**
The heading sections (items 1–2) are **required** for exact-output roles (Judge,
Critic) and **encouraged but not required** for all other roles; see
`.context/rules/process_subagent_bootstrap.md` § "Positional output contract".

## Session context receipt

Parent agents follow the `## Session handshake (read-receipt)` with this section. Dispatched
subagents emit it as `## Subagent context receipt` at the end of their response,
after `## Subagent session handshake`.

Parent agent form (use `## Subagent context receipt` heading when emitting as a dispatched subagent):

```text
## Session context receipt

| File | Status | Why it was read | Decision affected |
|---|---|---|---|
| `AGENTS.md` | Read | Startup contract | Loaded handshake, truth hierarchy, per-concern read list |
| `<path>` | <Read / Reviewed / Skipped> | <reason> | <decision, gate, or output affected> |
```

### Prompt-context read credit

If the full contents of a referenced rule file are already present verbatim in the current prompt context, you may treat that file as `Reviewed` for orientation and avoid re-reading it from disk. A pointer or filename reference alone does not count as read credit. You must still read the on-disk file when freshness matters, when the rule's cadence requires a read or re-read, when a dispatch packet explicitly names it, or when you need line-accurate citations or compliance evidence.

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

## Cursor Cloud specific instructions

This repository is the **AI repo template** itself — a scaffolding/meta-product, not a
runnable web app or API. Local development means validating template integrity via shell
automation and CI-parity linters. See `AI_REPO_GUIDE.md` for the full command catalog.

### What runs here

No long-running services (no `npm run dev`, no Docker Compose stack) are required for this
template repo. The VM update script refreshes Python deps and repo-required CLI tools only.

### One-time VM tools (not in the update script)

Install these once per fresh VM if missing (matches `.github/workflows/ci-tests.yml` and
`lint-and-format.yml`):

```bash
sudo apt-get update -qq
sudo apt-get install -y bats parallel shellcheck ripgrep jq
SHFMT_VERSION="3.8.0"
curl -sSL "https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64" \
  -o /tmp/shfmt && chmod +x /tmp/shfmt && sudo mv /tmp/shfmt /usr/local/bin/shfmt
ACTIONLINT_VERSION="1.7.7"
curl -sSL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz" \
  | sudo tar -xz -C /usr/local/bin actionlint
npm install --prefix "$HOME/.local" markdownlint-cli2@0.17.2
export PATH="$HOME/.local/node_modules/.bin:$PATH"
```

Add the `PATH` export to your shell profile if you use `markdownlint-cli2` in later sessions.

### Verify / lint / test (CI parity)

```bash
./scripts/verify-env.sh          # or --fix to auto-install rg, shellcheck, jq
bash scripts/setup.sh            # first-run env stub + verify-env (gh label steps skip without auth)
./test.sh                        # primary template verification (~550+ checks)
bats scripts/tests/              # shell script unit tests
bash scripts/lint-shell-conventions.sh scripts/
find . \( -name '.git' -o -name 'node_modules' \) -prune -o -name '*.sh' -print0 \
  | xargs -r -0 shellcheck --severity=warning --exclude=SC1091
find .github/workflows -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) -print0 \
  | xargs -r -0 actionlint -ignore 'SC2016' -ignore 'SC2086' -ignore 'SC2129' \
    -ignore 'SC2153' -ignore 'SC2018' -ignore 'SC2019'
```

### Bootstrap smoke (Codespaces Dotfiles equivalent)

Simulate copying the multi-agent kit into a fresh project workspace:

```bash
TMP_WS=$(mktemp -d) DOTFILES="$PWD" WORKSPACE="$TMP_WS" bash install.sh
```

Expect `AGENTS.md`, `.context/00_INDEX.md`, and role files under `.agents/` in `$TMP_WS`.

### Gotchas

- `./test.sh` warnings about `TEMPLATE_PLACEHOLDER` and missing `.env` are **expected** in
  the template repo itself.
- `scripts/setup.sh` steps that call `gh` (labels, variables, secrets) require authenticated
  GitHub CLI; they warn and skip when `gh` is unavailable.
- `install.sh` skips VS Code extension installation when the `code` CLI is absent (normal in
  Cursor Cloud VMs).
