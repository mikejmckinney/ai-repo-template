# AGENTS.md section redirects (ADR-021 back-compat)

Pre-decomposition `AGENTS.md` section citations (for example `AGENTS.md §"Session-state cadence"`)
still appear in historical ADRs and session archives. After ADR-021, each section lives in a
focused rule file under `.context/rules/`. **New docs should cite the rule file directly.**

See also [ADR-021](../decisions/adr-021-agents-md-decomposition.md) § "Anchor-redirect approach".

| Pre-decomposition section in AGENTS.md | Now lives in |
|---|---|
| §"Template detection" | `.context/rules/process_template_detection.md` |
| §"Critical thinking and communication" | `.context/rules/process_critical_thinking.md` |
| §"Work style" | `.context/rules/process_work_style.md` § "Work style" |
| §"Clarification and ambiguity" | `.context/rules/process_clarification.md` |
| §"Truth hierarchy" | `AGENTS.md` (startup kernel) |
| §"Role selection (multi-agent workflow)" | `.context/rules/process_role_selection.md` § "Role selection (multi-agent workflow)" |
| §"Analyst pre-flight gate" | `.context/rules/process_gates.md` § "Analyst pre-flight gate (REQUIRED before implementation)" |
| §"Plan-as-comment requirement" | `.context/rules/process_gates.md` § "Plan-as-comment requirement (REQUIRED before implementation)" |
| §"Model tier dispatch convention" | `.context/rules/process_model_tier.md` |
| §"Context pack usage" | `.context/rules/process_role_selection.md` § "Context pack usage" |
| §"Onboarding procedure" | `.context/rules/process_role_selection.md` § "Onboarding procedure" |
| §"Ongoing maintenance" | `.context/rules/process_doc_maintenance.md` |
| §"Postmortem feedback loop" | `.context/rules/process_session_state.md` § "Postmortem feedback loop" |
| §"Session-state cadence" | `.context/rules/process_session_state.md` |
| §"Close-out (three actions, three triggers)" | `.context/rules/process_session_state.md` § "Close-out (three actions, three triggers)" |
| §"Testing requirements" | `.context/rules/process_work_style.md` § "Testing requirements" |
| §"PR completion criteria (interactive sessions)" | `.context/rules/process_pr_completion.md` § "PR completion criteria (interactive sessions)" |
| §"Validation" | `.context/rules/process_work_style.md` § "Validation" |
| §"Templates and conventions" | `.context/rules/process_pr_completion.md` § "Templates and conventions" |
| §"Code quality" | `.context/rules/process_pr_completion.md` § "Code quality" → `.context/rules/domain_code_quality.md` |
| §"Review guidelines" | `.context/rules/process_pr_completion.md` § "Review guidelines" |
| §"Session handshake (read-receipt)" | `.context/rules/process_session_start.md` § "Session handshake (read-receipt)" |
| §"Session context receipt" | `.context/rules/process_session_start.md` § "Session context receipt" |

Do not add new rows here. When updating a live reference, change the source doc to point at the
rule file instead of this table.
