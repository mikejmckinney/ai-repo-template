---
description: Classify and onboard to the current repository
---

Load the `repo-onboarding` skill and onboard to the current repository using
`$ARGUMENTS` as optional scope or task context.

Run the read-only classifier first. For Mode B, do not modify files unless the
user explicitly requested repository onboarding or confirms the bootstrap.
Read only the references selected by the classified mode, validate afterward,
and return the required status line plus a concise repository brief.
