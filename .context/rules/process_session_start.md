# Process: Session Start

## Load profile

Read this file at the start of a new repo task, at a task boundary, or before repo-changing work.

This file defines startup evidence, read-credit semantics, and parent/subagent receipt positioning. It does not replace task-triggered rules from `.context/rules/README.md`.

## Required startup sequence

1. Read `AGENTS.md`.
2. Read `.context/rules/process_session_start.md`.
3. Read `.context/rules/README.md`.
4. Choose the smallest named read profile from `.context/rules/README.md`.
5. Read task-triggered rules from the catalog before making the affected decision.
6. Emit the session handshake and context receipt.

If startup cannot be completed, do not perform repo-changing work. Explain what could not be loaded and what action is blocked.

## Session handshake (read-receipt)

When you have read this file at the start of a session, open your first substantive repo-work reply with the following:

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

Replace `AGENTS_MD_VERSION` with the version number specified in the HTML comment at the top of `AGENTS.md`.

The session handshake should be on its own line before any other content for parent/default agents. See the subagent rule below for exact-output roles.

`Dispatch mode`: dispatched subagents record the mode from the dispatch packet (`plan-gate` or `diff-gate`). Parent/default agents and non-exact-output subagents use `n/a`. Required for Judge and Critic; see `.context/rules/process_subagent_bootstrap.md` § "Positional output contract".

`Read profile`: record the named profile from `.context/rules/README.md`, `full` if all standard startup/rule files were loaded, or `none` only when no rule profile was loaded and no repo-changing work is being performed.

This is a per-session signal, not a per-reply one. Emit it once at the start of the session and suppress it on later replies in the same conversation unless the task, role, or repo boundary changes materially.

For parent/default-agent work, this token is the parent startup receipt required by ADR-026 compliance evidence. Follow the handshake with a `## Session context receipt` section.

For dispatched subagents, emit role-specific output **first** so exact-output contracts are satisfied:

- Judge: `DECISION:` is the literal first line.
- Critic: `CRITIC DECISION:` is the literal first line.

After the role body, append in order:

1. `## Subagent session handshake` — the 7-field table above.
2. `## Subagent context receipt` — the file table from `## Session context receipt`.
3. `subagent_compliance` YAML block.

`subagent_compliance` is required for all dispatched subagents. The heading sections are required for exact-output roles and encouraged for all other roles; see `.context/rules/process_subagent_bootstrap.md` § "Positional output contract".

## Session context receipt

Parent agents follow the session handshake with this section. Dispatched subagents emit it as `## Subagent context receipt` after `## Subagent session handshake`.

```text
## Session context receipt

| File | Status | Why it was read | Decision affected |
|---|---|---|---|
| `AGENTS.md` | Read | Startup contract | Loaded handshake, truth hierarchy, rule catalog pointer |
| `.context/rules/process_session_start.md` | Read | Startup receipt contract | Loaded read-credit and receipt rules |
| `.context/rules/README.md` | Read | Rule catalog | Selected read profile and triggered rules |
| `<path>` | <Read / Reviewed / Skipped> | <reason> | <decision, gate, or output affected> |
```

Use one row per file that was required, triggered, explicitly dispatched, or intentionally skipped. You do not need to list every non-triggered rule file.

## Prompt-context read credit

If the full contents of a referenced rule file are already present verbatim in the current prompt context, you may treat that file as `Reviewed` for orientation and avoid re-reading it from disk.

A pointer, filename, path, heading, excerpt, search result, or summary alone does **not** count as read credit.

You must still read the on-disk file when any of the following apply:

- freshness matters;
- the rule's cadence requires a read or re-read;
- a dispatch packet explicitly names the file;
- line-accurate citations are needed;
- compliance evidence requires a disk/current-source read;
- the prompt content may be stale, partial, or transformed;
- the file is the object being edited or reviewed.

## Canary / version handling

Bump `AGENTS_MD_VERSION` whenever `AGENTS.md` is materially edited so the handshake proves agents loaded the current copy, not a stale one.

The canary covers `AGENTS.md` only. Per-concern files in `.context/rules/` evolve through their own PRs and are not gated by this token unless a future ADR assigns them their own canary.

## Read / Reviewed / Skipped definitions

Use these exact meanings in the session context receipt.

### `Read`

Use `Read` when you loaded the current full contents of the file from the repo or another authoritative current source during this session or task boundary.

`Read` is required when the file is:

- part of the startup-required set;
- explicitly named by a dispatch packet;
- required by the selected read profile;
- required by a triggered rule before the affected decision;
- being edited, reviewed, cited by line, or used as compliance evidence.

Examples:

| File | Status | Why it was read | Decision affected |
|---|---|---|---|
| `.context/rules/process_pr_completion.md` | Read | PR readiness rule triggered | PR checklist and review response |
| `.context/rules/process_model_tier.md` | Read | Model routing policy edit | ADR-019 amendment recommendation |
| `docs/decisions/adr-016-pre-merge-verification-gate.md` | Read | Workflow-risk change | Sandbox verification requirement |

### `Reviewed`

Use `Reviewed` when the full file contents were already available in the current prompt context, or were read earlier in the same session and no re-read trigger fired.

`Reviewed` is weaker than `Read`. It is acceptable for orientation, continuity, and non-line-specific reasoning. It is not sufficient when the task requires current on-disk evidence, line-accurate citations, explicit dispatch compliance, or editing/reviewing that file.

Examples:

| File | Status | Why it was read | Decision affected |
|---|---|---|---|
| `.context/rules/repo_orchestration_patterns.md` | Reviewed | Full content was already present in prompt context | Advisory orchestration recommendation |
| `.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md` | Reviewed | Previously read in same session; no freshness trigger fired | ROI summary continuity |

### `Skipped`

Use `Skipped` when the file was considered but intentionally not loaded because its trigger did not apply, the chosen profile did not require it, or the task was blocked before the file could be read.

Every `Skipped` row must explain why. Do not use `Skipped` for startup-required files unless work is blocked and no repo-changing action is being taken.

Examples:

| File | Status | Why it was read | Decision affected |
|---|---|---|---|
| `.context/rules/domain_code_quality.md` | Skipped | Docs-only change; no code/refactor trigger | No code-quality gate applied |
| `.context/rules/process_subagent_bootstrap.md` | Skipped | No subagents dispatched or evaluated | No subagent compliance needed |
| `.context/rules/process_template_detection.md` | Skipped | Existing repo mode already known; not onboarding a new clone | No Mode A/B decision |

### Invalid status claims

Do not claim:

- `Read` from a filename, pointer, heading, excerpt, search result, or summary.
- `Read` for stale prompt context.
- `Reviewed` for a file whose trigger requires a fresh disk/current-source read.
- `Skipped` for a required file while still performing the action that required it.
- `none` read profile for repo-changing work.

If a required read is impossible, mark the task blocked, explain the missing source, and stop before repo-changing work.
