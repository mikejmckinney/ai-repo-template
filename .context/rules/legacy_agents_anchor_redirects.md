# Section-anchor redirects (for ADR back-compat)

This file exists only for ADR/backlink compatibility after AGENTS.md decomposition. Do not add new anchors here. Remove an entry after all references are updated.

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
