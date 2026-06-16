# Process: Session Start

## Load profile

Read this file at the start of a new repo task, at a task boundary, or before repo-changing work.

This file defines startup evidence, read-credit semantics, and parent/subagent receipt positioning. It does not replace task-triggered rules from `.context/rules/README.md`.

## Required startup sequence

1. Read `AGENTS.md`.
2. Read `.context/rules/process_session_start.md`.
3. Read `.context/rules/README.md`.
4. Choose the most relevant named read profile from `.context/rules/README.md`.
5. Read task-triggered rules from the catalog before making the affected decision.
6. Emit the session handshake and context receipt.

If startup cannot be completed, do not perform repo-changing work. Explain what could not be loaded and what action is blocked.

## Session handshake (read-receipt)

When you have read this file at the start of a session, open your first reply with the following:

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
| Receipt boundary | <fresh | post-compaction | on-demand-replay> |
```

Replace `AGENTS_MD_VERSION` with the version number specified in the HTML comment at the top of `AGENTS.md`.

The session handshake should be on its own line before any other content.

`Read profile`: record the named profile from `.context/rules/README.md`, `full` if all standard startup/rule files were loaded, or `none` only when no rule profile was loaded and no repo-changing work is being performed.

`Receipt boundary`:

- `fresh` — mandatory profile files were read from disk this boundary and the receipt reflects current `In context` values.
- `post-compaction` — context was compacted/summarized/resumed; receipt emitted after re-read or marked stale (see below).
- `on-demand-replay` — user asked for the receipt mid-session without a fresh profile reload this turn.

Emit the handshake at each task boundary and after context compaction. Suppress it on later replies in the same conversation only when the task, role, repo boundary, and receipt boundary are unchanged and every receipt row still has `In context: yes` for files you may cite.

For parent/default-agent work, this token is the parent startup receipt required by ADR-026 compliance evidence. Follow the handshake with a `## Session context receipt` section (or `## Session context receipt (stale)` when applicable).

## Session context receipt

Parent agents follow the session handshake with this section. Dispatched subagents emit it as `## Subagent context receipt` after `## Subagent session handshake`.

```text
## Session context receipt

| File | Load | In context | Why it was read | Decision affected |
|---|---|---|---|---|
| `AGENTS.md` | Read | yes | Startup contract | Loaded handshake, truth hierarchy, rule catalog pointer |
| `.context/rules/process_session_start.md` | Read | yes | Startup receipt contract | Loaded read-credit and receipt rules |
| `.context/rules/README.md` | Read | yes | Rule catalog | Selected read profile and triggered rules |
| `<path>` | <Read / Skipped> | <yes / no / partial> | <reason> | <decision, gate, or output affected> |
```

Use one row per file that was required, triggered, explicitly dispatched, or intentionally skipped.

### Load vs In context

| Column | Values | Meaning |
|---|---|---|
| **Load** | `Read`, `Skipped` | `Read` = full file loaded from disk **this receipt boundary**. `Skipped` = intentionally not loaded. |
| **In context** | `yes`, `no`, `partial` | Whether the **full** file text is **currently** in working prompt context. |

Rules:

- `Load: Read` requires a disk/current-source read **this boundary** only.
- `In context: yes` requires verbatim full file in current prompt — not memory, summary, transcript, or grep.
- `In context: partial` for search hits, excerpts, or conversation summaries that mention the file.
- After compaction or when re-displaying a prior receipt without re-read: set `In context: no` for affected rows even if `Load: Read` at an earlier boundary.
- Do not claim `In context: yes` for a file you cannot cite by line without re-reading.

### Showing the receipt mid-session

When the user asks to see the session context receipt:

1. Treat it as a **freshness check**, not a history request.
2. If mandatory profile files were not re-read **this turn**, either re-read them first (`Receipt boundary: fresh`) or emit `## Session context receipt (stale)` with every row `In context: no` and a one-line note that re-read is required before line-accurate citations.
3. **Never** copy a prior receipt table from transcript, tool output, or conversation summary as if it reflects current context.

### Stale receipt heading

Use `## Session context receipt (stale)` when `Receipt boundary` is `post-compaction` or `on-demand-replay` and profile files were not re-read this turn. Include:

```text
Prior boundary: <profile-name or unknown>. File contents not retained in context. Re-read required before compliance claims or line-accurate citations.
```

## Prompt-context read credit

If the full contents of a referenced rule file are already present verbatim in the current prompt context, you may record `Load: Skipped` and `In context: yes` for orientation and avoid re-reading it from disk.

A pointer, filename, path, heading, excerpt, search result, or summary alone does **not** count as read credit and must be `In context: partial` at best.

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

## Load / In context / legacy Reviewed definitions

Use these exact meanings in the session context receipt.

### `Load: Read`

Use `Load: Read` when you loaded the current full contents of the file from the repo or another authoritative current source during **this receipt boundary**.

`Load: Read` is required when the file is:

- part of the startup-required set;
- explicitly named by a dispatch packet;
- required by the selected read profile;
- required by a triggered rule before the affected decision;
- being edited, reviewed, cited by line, or used as compliance evidence.

Examples:

| File | Load | In context | Why it was read | Decision affected |
|---|---|---|---|---|
| `.context/rules/process_work_style.md` | Read | yes | PR readiness surfaces | PR checklist and review response |
| `docs/decisions/adr-019-per-role-model-tiering.md` | Read | yes | Model routing policy edit | ADR-019 amendment recommendation |
| `docs/decisions/adr-016-pre-merge-verification-gate.md` | Read | yes | Workflow-risk change | Sandbox verification requirement |

### `In context: yes` / `no` / `partial`

- `yes` — full verbatim file is in current prompt context right now.
- `no` — file was loaded earlier or named in a summary, but full text is not available now (compaction, new turn without re-read, transcript replay).
- `partial` — only an excerpt, grep hit, or summary is available.

### Legacy `Reviewed` (deprecated — do not use in new receipts)

Older receipts used a single `Reviewed` status. Replace with `Load: Skipped` + `In context: yes` when verbatim content was prompt-injected without a disk read, or `Load: Read` + `In context: no` when a prior boundary read was compacted away.

Do **not** use `Reviewed` to mean "read earlier in the same session" — that state is `Load: Read` + `In context: no` after compaction.

### `Load: Skipped`

Use `Load: Skipped` when the file was considered but intentionally not loaded because its trigger did not apply, the chosen profile did not require it, or the task was blocked before the file could be read.

Every `Load: Skipped` row must explain why. Do not use `Skipped` for startup-required files unless work is blocked and no repo-changing action is being taken.

Examples:

| File | Load | In context | Why it was read | Decision affected |
|---|---|---|---|---|
| `.context/rules/domain_code_quality.md` | Skipped | no | Docs-only change; no code/refactor trigger | No code-quality gate applied |
| `docs/guides/subagent-bootstrap-reference.md` | Skipped | no | No subagents dispatched or evaluated | No subagent compliance needed |
| `.github/prompts/repo-onboarding.md` | Skipped | no | Existing repo mode already known; not onboarding a new clone | No Mode A/B decision |

### Invalid status claims

Do not claim:

- `Load: Read` from a filename, pointer, heading, excerpt, search result, or summary.
- `In context: yes` for stale prompt context, transcript replay, or post-compaction memory.
- `In context: yes` when you cannot cite the file by line without re-reading.
- `Load: Skipped` for a required file while still performing the action that required it.
- `none` read profile for repo-changing work.
- A non-stale `## Session context receipt` heading when `Receipt boundary` is `post-compaction` or `on-demand-replay` and profile files were not re-read this turn.

If a required read is impossible, mark the task blocked, explain the missing source, and stop before repo-changing work.

## Context compaction / resumed-session behavior

If context was compacted, summarized, resumed, or transferred, treat the next reply as a task boundary unless the active context still contains:

1. the current `AGENTS_MD_VERSION`;
2. the prior session handshake with current `Receipt boundary`;
3. the selected read profile;
4. the session context receipt with accurate `In context` values for every row you may cite.

If any are missing, load the mandatory files for the current read profile and re-emit the session handshake with `Receipt boundary: post-compaction`. Set `In context: no` on every row until each file is re-read this boundary.

See also `.context/rules/process_session_state.md` § "`agent-state:v1` update cadence" — auto-summary is a durability-risk boundary that invalidates `In context: yes` for prior reads.
