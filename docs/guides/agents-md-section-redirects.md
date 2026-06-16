# AGENTS.md section redirects (ADR-021 back-compat)

Pre-decomposition `AGENTS.md` section citations (for example `AGENTS.md §"Session-state cadence"`)
still appear in historical ADRs and session archives. After ADR-021, each section lived in a
focused rule file under `.context/rules/`. **ADR-031 Amendment 2026-06-15** removed several of
those rule files from the production catalog; redirects below point at the current durable
surface. **New docs should cite the current surface directly.**

See also [ADR-021](../decisions/adr-021-agents-md-decomposition.md) § "Anchor-redirect approach"
and [ADR-031](../decisions/adr-031-agent-model-roi-benchmark-policy.md) Amendment 2026-06-15.

| Pre-decomposition section in AGENTS.md | Now lives in |
|---|---|
| §"Template detection" | [`.github/prompts/repo-onboarding.md`](../../.github/prompts/repo-onboarding.md) Step 1 |
| §"Critical thinking and communication" | [`.context/rules/process_critical_thinking.md`](../../.context/rules/process_critical_thinking.md) |
| §"Work style" | [`.context/rules/process_work_style.md`](../../.context/rules/process_work_style.md) § "Work style" |
| §"Clarification and ambiguity" | [`.context/rules/process_clarification.md`](../../.context/rules/process_clarification.md) |
| §"Truth hierarchy" | [`AGENTS.md`](../../AGENTS.md) (startup kernel) |
| §"Role selection (multi-agent workflow)" | [ADR-031](../decisions/adr-031-agent-model-roi-benchmark-policy.md); historical detail in [`multi-agent-coordination.md`](./multi-agent-coordination.md) |
| §"Analyst pre-flight gate" | [`.agents/analyst.md`](../../.agents/analyst.md) § "Pre-Flight Validation"; [ADR-005](../decisions/adr-005-analyst-preflight-gate.md) |
| §"Plan-as-comment requirement" | [ADR-011](../decisions/adr-011-plan-as-comment-requirement.md); [`.github/PLAN_TEMPLATE.md`](../../.github/PLAN_TEMPLATE.md) |
| §"Model tier dispatch convention" | [ADR-019](../decisions/adr-019-per-role-model-tiering.md) |
| §"Context pack usage" | [`.context/rules/README.md`](../../.context/rules/README.md) § "Named read profiles"; [`.context/benchmarks/model-roi/README.md`](../../.context/benchmarks/model-roi/README.md) |
| §"Onboarding procedure" | [`.github/prompts/repo-onboarding.md`](../../.github/prompts/repo-onboarding.md) |
| §"Ongoing maintenance" | [`.context/rules/process_doc_maintenance.md`](../../.context/rules/process_doc_maintenance.md) |
| §"Postmortem feedback loop" | [`.context/rules/process_session_state.md`](../../.context/rules/process_session_state.md) § "Postmortem feedback loop" |
| §"Session-state cadence" | [`.context/rules/process_session_state.md`](../../.context/rules/process_session_state.md) |
| §"Close-out (three actions, three triggers)" | [`.context/rules/process_session_state.md`](../../.context/rules/process_session_state.md) § "Close-out (three actions, three triggers)" |
| §"Testing requirements" | [`.context/rules/process_work_style.md`](../../.context/rules/process_work_style.md) § "Testing requirements" |
| §"PR completion criteria (interactive sessions)" | [`.github/pull_request_template.md`](../../.github/pull_request_template.md); [`.github/prompts/pr-resolve-all.md`](../../.github/prompts/pr-resolve-all.md) |
| §"Validation" | [`.context/rules/process_work_style.md`](../../.context/rules/process_work_style.md) § "Validation" |
| §"Templates and conventions" | [`.github/pull_request_template.md`](../../.github/pull_request_template.md); [`.github/PLAN_TEMPLATE.md`](../../.github/PLAN_TEMPLATE.md) |
| §"Code quality" | [`.context/rules/domain_code_quality.md`](../../.context/rules/domain_code_quality.md) |
| §"Review guidelines" | [`.context/rules/repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md); [`.agents/critic.md`](../../.agents/critic.md) / [`.agents/judge.md`](../../.agents/judge.md) |
| §"Session handshake (read-receipt)" | [`.context/rules/process_session_start.md`](../../.context/rules/process_session_start.md) § "Session handshake (read-receipt)" |
| §"Session context receipt" | [`.context/rules/process_session_start.md`](../../.context/rules/process_session_start.md) § "Session context receipt" |

Do not add new rows here. When updating a live reference, change the source doc to point at the
current surface instead of this table.
