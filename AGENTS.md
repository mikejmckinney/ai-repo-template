# AGENTS.md

<!-- AGENTS_MD_VERSION: 26 -->

Read, adhere to, and enforce domain_code_quality.md, process_clarification.md, process_critical_thinking.md, process_doc_maintenance.md, process_opportunity_feedback.md, process_session_start.md, process_session_state.md, process_work_style.md, repo_orchestration_patterns.md from disk.  skip disk read for files already verbatim in context (Load: Skipped, In context: yes).

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
3. Re-emit **Session handshake** with the current `AGENTS_MD_VERSION` from this file's HTML comment, plus **Session context receipt** using `Receipt boundary: post-compaction` and accurate `In context` values (prior-boundary `Load: Read` rows are `In context: no` until re-read this boundary).

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