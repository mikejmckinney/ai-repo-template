# Copilot Fleet — Parallel Agent Dispatch

> **Usage**: Use the `/fleet` slash command in Copilot CLI to dispatch
> multiple sub-agents in parallel. Each sub-agent gets its own context
> window but shares the same filesystem.
>
> ```bash
> # Interactive
> /fleet <YOUR OBJECTIVE PROMPT>
>
> # Non-interactive (CI / scripting)
> copilot -p "/fleet <YOUR TASK>" --no-ask-user
> ```
>
> For background on how `/fleet` works, see
> [Run multiple agents at once with /fleet in Copilot CLI](https://github.blog/ai-and-ml/github-copilot/run-multiple-agents-at-once-with-fleet-in-copilot-cli/).

---

## How Fleet maps to this template

This template ships 10 role-specialized agents in `.github/agents/`:

| Agent file | Role | Writes code? |
|---|---|---|
| `architect.agent.md` | Plans + ADRs | No |
| `analyst.agent.md`   | Research + analysis | No |
| `judge.agent.md`     | Plan-gate + diff-gate | No |
| `critic.agent.md`    | Subjective quality review | No |
| `pm.agent.md`        | Task dispatch + ownership | No |
| `frontend.agent.md`  | UI layer | Yes |
| `backend.agent.md`   | Server layer | Yes |
| `qa.agent.md`        | Tests | Yes |
| `devops.agent.md`    | CI, infra, scripts | Yes |
| `docs.agent.md`      | Documentation | Yes |

Fleet's orchestrator can reference these agents by name in your prompt
using the `@<filename>` syntax (e.g., `@backend.agent.md`). Each agent
already declares `owned_paths` in its frontmatter, which tells Fleet
(and you) exactly which files that agent should touch.

---

## Writing effective Fleet prompts

### 1. Map deliverables to agents and files

Be explicit about which agent owns which files. This prevents two
sub-agents from writing to the same file (last writer wins — silently).

```text
/fleet Implement user registration:

1. @backend.agent.md — POST /api/register endpoint
   Files: src/api/auth/register.ts, migrations/006_users.sql
   Tests: tests/api/register.test.ts

2. @frontend.agent.md — RegistrationForm component
   Files: src/components/RegistrationForm.tsx, src/pages/register.tsx
   Tests: tests/components/RegistrationForm.test.tsx

3. @docs.agent.md — Registration guide
   Files: docs/guides/registration.md

Tracks 1, 2, 3 are independent — run in parallel.
No changes outside assigned files.
```

### 2. Declare dependencies

If one track depends on another, say so. Fleet serializes dependent
items and parallelizes the rest.

```text
/fleet Migrate the payments module:

1. Write new schema — migrations/007_payments.sql
2. Update ORM models — src/models/payment.ts (depends on 1)
3. Update API handlers — src/api/payments.ts (depends on 2)
4. Write integration tests — tests/api/payments.test.ts (depends on 2)
5. Update docs — docs/guides/payments.md (depends on 2)

Items 3, 4, 5 can run in parallel after item 2 completes.
```

### 3. Set validation criteria

Tell Fleet what "done" means for each track:

```text
/fleet Refactor auth module in three tracks:

1. @backend.agent.md — Refactor token validation in src/api/middleware/
   Constraint: no dependency upgrades
   Validation: all existing tests pass, no new lint warnings

2. @qa.agent.md — Add missing test coverage for src/api/middleware/
   Constraint: only add tests, do not modify source
   Validation: coverage for middleware/ increases

3. @docs.agent.md — Update auth documentation in docs/guides/auth.md
   Constraint: no code changes
   Validation: all links resolve, examples match current API

Run tracks 1 and 3 in parallel. Track 2 starts after track 1 finishes.
```

---

## Example: full feature with Fleet + template agents

This example mirrors the "Worked Example" in
`docs/guides/multi-agent-coordination.md`, but uses `/fleet` instead of
manual PM dispatch.

```text
/fleet Add a login feature across API, UI, and docs:

1. @backend.agent.md — POST /auth/login endpoint
   Files: src/api/auth/login.ts, migrations/005_sessions.sql
   Tests: tests/api/auth/login.test.ts
   Depends on: nothing

2. @frontend.agent.md — LoginForm component + login page
   Files: src/components/LoginForm.tsx, src/pages/login.tsx
   Tests: tests/components/LoginForm.test.tsx
   Depends on: track 1 (needs API contract)

3. @docs.agent.md — Auth guide
   Files: docs/guides/auth.md
   Depends on: track 1 (needs endpoint docs)

Track 1 runs first. Tracks 2 and 3 run in parallel after track 1 finishes.
Each track must lint clean and pass its tests before completing.
No changes outside assigned files.
```

---

## Monitoring and steering

While Fleet is running:

- **Check decomposition**: Review the plan Fleet shares before it starts
  working. If it merged your tracks into one linear plan, stop and
  rephrase with more explicit file boundaries.
- **Inspect running tasks**: Run `/tasks` to see active sub-agents.
- **Steer in-flight**: Send follow-up prompts like:
  - `Prioritize failing tests first, then complete remaining tasks.`
  - `List active sub-agents and what each is currently doing.`
  - `Mark done only when lint, type check, and all tests pass.`

---

## Common pitfalls

| Pitfall | Fix |
|---|---|
| Two agents write the same file | Assign each agent distinct files in your prompt. Use `owned_paths` from agent frontmatter as a guide. |
| Sub-agent missing context | Fleet sub-agents can't see the orchestrator's conversation history. Include everything the sub-agent needs in the `/fleet` prompt, or reference files it can read. |
| Linear execution despite parallel intent | Be explicit: list deliverables as numbered tracks, state which can run in parallel, and name the files each track owns. |
| Agent uses wrong model | Specify `model:` in the agent's frontmatter (e.g., `model: claude-sonnet-4`) or reference it in your prompt. |

---

## When to use Fleet vs. manual multi-agent coordination

| Scenario | Recommendation |
|---|---|
| Multi-file feature with clear file boundaries | **Fleet** — natural parallelism, less coordination overhead |
| Complex cross-cutting refactor with shared state | **Manual** (PM dispatch via `coordination.md`) — explicit lock management |
| Quick single-file change | **Regular Copilot CLI** — Fleet adds unnecessary overhead |
| Long-running multi-day feature | **Manual** — session handoff and lock expiry need human oversight |

---

## See also

- `docs/guides/multi-agent-coordination.md` — full multi-agent workflow
- `.github/agents/*.agent.md` — individual agent definitions
- `.context/rules/agent_ownership.md` — canonical path ownership map
- `docs/guides/agent-best-practices.md` — token limits, session handoff
