<!-- TEMPLATE_PLACEHOLDER: This file must be regenerated for the actual project repo. -->

# Gemini Codespace Instructions

Before taking any action in a new session, you MUST execute the onboarding sequence defined in the "New agent session" section of `AI_REPO_GUIDE.md`.

Specifically, you must:
1. Read `AGENTS.md` for universal rules and the current handshake canary.
2. Read `AI_REPO_GUIDE.md` for the onboarding sequence.
3. Read `.context/rules/agent_ownership.md` to know which files your role may touch.
4. Read your specific `.agents/<your-role>.md` file (or `.agents/pm.md` if picking up an untriaged task).

**Truth hierarchy:**
When information conflicts, use this priority order:
1. `./.context/**` — canonical project direction and constraints
2. `./docs/**` — supporting detail and reference material
3. Codebase — current implementation reality

For live agent coordination state, the order is: issue body → PR body → latest `agent-state:v1` comment → labels.
