# Rule Catalog

> **Purpose**: Route agents to the smallest rule set needed for the current task. This file is the catalog and load-policy surface for `.context/rules/**`; detailed rationale, examples, and long-form guidance belong in `docs/**`.

## How to use this catalog

1. Start every repo task with `AGENTS.md`, `.context/rules/process_session_start.md`, and this catalog.
2. Choose the smallest named read profile that fits the task.
3. Read every rule whose trigger fires before making the affected decision.
4. Record the loaded files in the session context receipt defined by `process_session_start.md`.
5. When in doubt, read the narrower rule file that owns the decision instead of loading all rules.

A filename, pointer, heading, search result, or summarized mention does **not** count as read credit. Full file contents already present verbatim in the current prompt context may count as `Reviewed`, subject to the limits in `process_session_start.md`.

## Load profile meanings

| Load profile | Meaning |
|---|---|
| `startup-required` | Must be loaded before repo work or repo-changing actions. |
| `high-frequency invariant` | Applies broadly; read once per session/task boundary, then follow continuously. |
| `task-triggered` | Read before the action named in the trigger. |
| `domain-triggered` | Read when the changed paths, issue topic, or requested decision intersects the rule’s domain. |
| `gate-triggered` | Read before a process gate, plan gate, diff gate, review, PR open, or merge decision. |
| `reference` | Read only when resolving a pointer, migration, compatibility issue, or citation. |

## Named read profiles

Use these names in the session handshake’s `Read profile` field.

| Profile | Use when | Minimum files |
|---|---|---|
| `startup-min` | Simple orientation or non-editing repo question. | `AGENTS.md`, `process_session_start.md`, `process_critical_thinking.md`, `process_clarification.md`, this catalog. |
| `standard` | Default for most issue/PR work before choosing a narrower task profile. | `startup-min`, `.context/00_INDEX.md`, role file if acting as a role, `agent_ownership.md`, `process_critical_thinking.md`, `process_role_selection.md`. |
| `implementation` | Implementing or modifying code, docs, config, checks, prompts, or workflows. | `standard`, `process_work_style.md`, `process_gates.md`, `process_doc_maintenance.md`, plus domain rules for changed paths. |
| `pr-review` | Reviewing a PR, preparing a PR, responding to review feedback, or checking merge readiness. | `standard`, `process_pr_completion.md`, `process_doc_maintenance.md`, `process_gates.md`, changed-path domain rules. |
| `orchestration` | Changing agents, role overlays, dispatch, handoffs, review timing, subagent behavior, or model routing. | `standard`, `process_subagent_bootstrap.md`, `process_model_tier.md`, `repo_orchestration_patterns.md`, `process_doc_maintenance.md`. |
| `policy-adr` | Writing or changing ADRs, process policy, governance docs, or rule files. | `standard`, `process_doc_maintenance.md`, `repo_orchestration_patterns.md`, relevant ADR(s), `docs/decisions/adr-template.md`. |
| `benchmark` | Changing benchmark protocol, candidates, scoring, adapters, cost math, or benchmark results. | `standard`, `.context/benchmarks/model-roi/README.md`, benchmark runbook/results as relevant, `process_model_tier.md`, `process_work_style.md`. |
| `full` | Explicit full-context audit or emergency high-risk review. | All files in `.context/rules/**` plus task-relevant docs/ADRs. Use sparingly and record why. |

Profiles define the minimum startup set. A trigger below can add files to any profile.

## Rule catalog

| Rule file | Load profile | Trigger | Re-read cadence | Evidence expected |
|---|---|---|---|---|
| [`process_session_start.md`](./process_session_start.md) | `startup-required` | New session, task boundary, or before repo-changing work. | Every session; re-read at a task boundary if the session changes role, issue, or PR. | Session handshake and context receipt. |
| [`README.md`](./README.md) | `startup-required` | New session, task boundary, or context-profile selection. | Every session/task boundary that requires rule routing. | Chosen read profile and triggered-rule list in context receipt. |
| [`process_template_detection.md`](./process_template_detection.md) | `task-triggered` | First session in a new clone, downstream template onboarding, or Mode A/Mode B uncertainty. | Once per repo clone/onboarding event, or when template mode is ambiguous. | Mode claim and downstream/template scope decision. |
| [`process_critical_thinking.md`](./process_critical_thinking.md) | `startup-required` | Any substantive answer, factual claim, review, recommendation, or uncertainty. | Every session; re-read when giving high-impact factual or review conclusions. | Cited claims, explicit assumptions, conflict callouts, uncertainty where warranted. |
| [`process_clarification.md`](./process_clarification.md) | `startup-required` | User request is ambiguous, conflicting, under-specified, or risks invented facts. | Before choosing a path when ambiguity affects outcome. | Clarifying question or stated assumption with bounded scope. |
| [`process_role_selection.md`](./process_role_selection.md) | `task-triggered` | Before claiming a task, selecting a role, dispatching subagents, or choosing OP/default-agent behavior. | Task boundary; re-read when ownership or role changes. | Role claim, OP/default rationale, selected profile. |
| [`agent_ownership.md`](./agent_ownership.md) | `task-triggered` | Before touching files, claiming an issue, coordinating cross-role edits, or reviewing path ownership. | Task boundary; re-read when changed paths expand. | Owned-path rationale, cross-role escalation/PM claim if needed. |
| [`process_work_style.md`](./process_work_style.md) | `task-triggered` | Before editing code, docs, prompts, config, scripts, workflows, or tests. | Task boundary; re-read before switching from planning/review to implementation. | Branch/commit discipline, verification plan, validation evidence. |
| [`process_gates.md`](./process_gates.md) | `gate-triggered` | Before non-exempt issue implementation, plan-as-comment work, Analyst pre-flight, or gate decision. | Before plan/code and whenever gate state changes. | Plan comment, gate state, exemption reason, acceptance criteria. |
| [`process_session_state.md`](./process_session_state.md) | `task-triggered` | Task boundary, handoff, close-out, or live-state update. | Every task boundary and close-out. | `agent-state:v1` or equivalent state/close-out evidence. |
| [`process_pr_completion.md`](./process_pr_completion.md) | `gate-triggered` | Before opening a PR, marking ready, reviewing, resolving feedback, or preparing merge. | Before PR open/review/merge; re-read after large feedback cycles. | PR checklist, issue link, test evidence, review/merge readiness. |
| [`process_subagent_bootstrap.md`](./process_subagent_bootstrap.md) | `domain-triggered` | Dispatching subagents, receiving dispatched role work, or using subagent output as gate evidence. | Before dispatch and before evaluating subagent return. | Dispatch packet, positional output compliance, `subagent_compliance`. |
| [`process_model_tier.md`](./process_model_tier.md) | `domain-triggered` | Model selection, model upshift/downshift, routing policy, benchmark conclusion, or agent overlay change. | Before model/routing decision; re-read when benchmark or ADR evidence is cited. | Model/routing rationale, ADR/benchmark reference, cost/ROI caveat. |
| [`process_doc_maintenance.md`](./process_doc_maintenance.md) | `gate-triggered` | Before PR open when docs, ADRs, prompts, workflows, rule files, checks, or generated surfaces may need sync. | Before PR open and after scope expands. | Doc-sync checklist, paired-file updates, stale-pointer checks. |
| [`domain_code_quality.md`](./domain_code_quality.md) | `domain-triggered` | Non-trivial code changes, refactors, tests, architecture-shaping implementation, or code review. | Before implementation/review; re-read when code scope changes materially. | TDD/quality rationale, hard-rule compliance, exception justification. |
| [`repo_orchestration_patterns.md`](./repo_orchestration_patterns.md) | `domain-triggered` | Changes or reviews touching agents, orchestration, rule files, workflows, prompts, handoffs, context loading, or governance. | Before orchestration-layer review and before ADR/policy edits. | Pattern/anti-pattern citations, block/advisory severity rationale. |
| [`process_opportunity_feedback.md`](./process_opportunity_feedback.md) | `task-triggered` | Out-of-scope improvement opportunity noticed during in-scope work. | When adding opportunity notes or filing follow-up suggestions. | Capped opportunity note with evidence, impact, recommendation, scope, next action. |

## Guides and durable references commonly reached from rules

| Reference | Read when |
|---|---|
| [`AI_REPO_GUIDE.md`](../../AI_REPO_GUIDE.md) | Need project overview, architecture map, or human-readable context beyond rules. |
| [`.context/00_INDEX.md`](../00_INDEX.md) | Default orientation after startup, profile selection, or context-pack routing. |
| [`docs/decisions/README.md`](../../docs/decisions/README.md) | ADR lookup, policy history, or decision provenance. |
| [`docs/decisions/adr-template.md`](../../docs/decisions/adr-template.md) | Creating or amending an ADR. |
| [`docs/guides/agent-pipeline.md`](../../docs/guides/agent-pipeline.md) | Workflow-level behavior, review/fix/merge automation, labels, or setup. |
| [`docs/guides/agents-md-section-redirects.md`](../../docs/guides/agents-md-section-redirects.md) | Resolving historical `AGENTS.md §"…"` citations after ADR-021 decomposition. |
| [`docs/guides/repo-orchestration-patterns-reference.md`](../../docs/guides/repo-orchestration-patterns-reference.md) | Long-form `P*` / `AP*` "where it appears," remediation, and history (normative contract in `repo_orchestration_patterns.md`). |
| [`docs/guides/opportunity-feedback-examples.md`](../../docs/guides/opportunity-feedback-examples.md) | Worked opportunity-note examples and 9-field schema rationale. |
| [`docs/guides/subagent-bootstrap-reference.md`](../../docs/guides/subagent-bootstrap-reference.md) | Pass-back narrative, ghost-success detail, and schema-variance handling (ADR-026). |
| [`docs/guides/multi-agent-coordination.md`](../../docs/guides/multi-agent-coordination.md) | Cross-agent workflow, coordination model, and role handoff details. |
| [`docs/guides/sandbox-verification.md`](../../docs/guides/sandbox-verification.md) | Default-branch-only workflow verification or sandbox proof. |
| [`.context/benchmarks/model-roi/README.md`](../benchmarks/model-roi/README.md) | Benchmark protocol, candidate isolation, scoring, and artifact model. |
| [`.context/benchmarks/model-roi/benchmark-runbook.md`](../benchmarks/model-roi/benchmark-runbook.md) | Reproducing or extending model/context/orchestration benchmarks. |

## Catalog maintenance rules

- Keep this file as a routing table, not a tutorial.
- Add a row whenever a new `.context/rules/*.md` file is created.
- Remove or update rows in the same PR that renames, deletes, or splits a rule file.
- Put long examples in `docs/**` and link them from the rule file, not from this catalog unless they are common cross-rule references.
- If a rule becomes high-frequency and expensive to load, split it into a short normative rule and a longer guide.
- If a trigger is unclear, prefer a narrower explicit trigger over `Always`.
