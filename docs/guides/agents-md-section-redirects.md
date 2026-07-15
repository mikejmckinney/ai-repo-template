# Historical AGENTS.md Section Redirects

ADR-021 previously decomposed `AGENTS.md` into `.context/rules/*.md`. ADR-031
later slimmed that catalog, and the ADR-026 amendment on 2026-07-13 consolidated
active operating policy back into `AGENTS.md` and retired the rules directory.

Historical citations now resolve as follows:

| Historical section | Current surface |
|---|---|
| Critical thinking and clarification | `AGENTS.md` § Clarification and critical thinking |
| Work style and testing | `AGENTS.md` § Work style; § Testing and validation |
| Documentation maintenance | `AGENTS.md` § Documentation synchronization |
| Session state and handoff | `AGENTS.md` § Session and handoff state |
| Opportunity feedback | `AGENTS.md` § Opportunity feedback |
| Code quality | `AGENTS.md` § Code quality |
| Session handshake | Retired by ADR-026's 2026-07-14 amendment |
| Context profiles and receipt tables | Retired; no replacement |
| P1-P9/AP1-AP10 vocabulary | Advisory summary in `AGENTS.md`; detail in `repo-orchestration-patterns-reference.md` |

This file exists only to resolve old ADR, postmortem, and issue citations. It is
not startup context and does not add operating requirements.
