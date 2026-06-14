# AGENTS.md

<!-- AGENTS_MD_VERSION: 26 -->

read:

1. `.context/rules/process_session_start.md`
2. `.context/rules/README.md`

A pointer or filename reference alone does not count as read credit.
Full content already present verbatim in prompt context may count as `In context: yes` with `Load: Skipped` unless freshness, cadence, explicit dispatch, citations, or compliance evidence require reading from disk.

Truth hierarchy:

1. `./.context/**`
2. `./docs/**`
3. Codebase

Pre-decomposition `AGENTS.md` section citations are mapped in [`docs/guides/agents-md-section-redirects.md`](docs/guides/agents-md-section-redirects.md) (ADR-021).

## Task boundary (re-run startup)

Treat each of these as a **task boundary** — re-read `process_session_start.md` and `.context/rules/README.md`, choose the **most relevant named read profile** for the new task, load its mandatory files for the profile, plus any triggered rules from the catalog, and **re-emit the session handshake** when the profile changed or the prior handshake/receipt is missing:

- new issue, PR, or feature branch work;
- switching from Q&A/planning to repo-changing implementation (or the reverse);
- role or dispatch mode change;
- **context compaction, summarization, or resumed session** (see below).

`Read profile` is **per task boundary**, not per conversation. Do not carry `startup-min` into implementation work.

## After context compaction

If the runtime summarized/compacted context, or you see a conversation summary instead of full prior turns, assume the handshake, read profile, and context receipt are **stale**. Must do the following:

1. Re-read `process_session_start.md` and `.context/rules/README.md`.
2. Re-select the read profile and load remaining mandatory files and triggered rules that were not loaded in the previous step.
3. Re-emit **Session handshake** with the current `AGENTS_MD_VERSION` from this file's HTML comment, plus **`## Session context receipt (stale)`** using `Receipt boundary: post-compaction`, `Load: —`, and `In context: no` on every row until each mandatory file is re-read this boundary (then set `Load: Read` and `In context: yes` for re-read rows).

Do not rely on memory of rule files read before compaction. Do not replay a prior receipt table from transcript or summary without re-read.

## Read profile routing

Choose the most relevant profile from `.context/rules/README.md` § "Named read profiles":

| When | Profile |
|---|---|
| Non-editing repo questions | `startup-min` |
| Most issue/PR coordination | `standard` |
| Code, scripts, workflows, checks, prompts, config | `implementation` |
| PR open/review/merge readiness | `pr-review` |
| Agents, dispatch, routing, overlays | `orchestration` |
| ADRs, policy, rule files | `policy-adr` |

Record the profile in the handshake. List loaded files in the context receipt.

Repo-changing work with `Read profile: none` or a profile below what the task requires is out of compliance; stop and re-run startup.
