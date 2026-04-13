# Domain: Multi-Agent Coordination

> **Purpose**: Rules for safely running multiple AI agents on the same codebase simultaneously. These conventions prevent file conflicts, duplicated work, and integration failures.

## Hard Rules (Never Violate)

1. **Claim before modifying.** Before starting work, an agent must create or update a `task_*.md` file in `.context/state/` with its assigned scope and files. If another agent's task file already claims those files, stop and coordinate.

2. **Respect file ownership.** Never modify files listed in another agent's `files_owned` section without explicit coordination (documented in both task files).

3. **Shared files require coordination.** Files in the project's declared shared zone (see `vision/architecture/agent-boundaries.md`) must not be modified by any agent without first checking all active task files for conflicts. When modifying shared files, the agent must note the change in its task file so other agents can see it.

4. **One migration at a time.** Database migrations, schema changes, and package dependency additions are serialized. Only one agent may modify migration files, `package.json` / `requirements.txt` / equivalent, or shared configuration at a time.

5. **Interfaces before implementation.** When multiple agents depend on a shared contract (API endpoint, type definition, function signature), the Architect agent (or whoever owns the shared zone) must define the interface first. Implementing agents code against the interface, not each other's internals.

## Soft Rules (Prefer Unless Justified)

1. **Vertical slices over horizontal layers.** When possible, assign agents feature-complete vertical slices (e.g., "user registration end-to-end") rather than horizontal layers (e.g., "all database code"). Vertical slices have fewer cross-agent dependencies.

2. **Prefer additive changes.** Agents should add new files rather than heavily modifying existing shared files. New files cannot conflict; edits to the same file will.

3. **Communicate via task files, not assumptions.** If Agent A needs something from Agent B, Agent A should document the dependency in its task file under `Blockers / Open Questions`. Don't assume the other agent will notice.

4. **Stagger shared-zone work.** If two agents both need to touch shared files, sequence the work: Agent A finishes its shared-zone changes first, Agent B pulls/rebases, then Agent B makes its changes.

5. **Small, frequent commits.** Agents working in parallel should commit early and often to their branches to reduce merge conflict surface area.

## Task File Requirements for Multi-Agent Work

Every active agent must maintain a task file with these additional fields:

```markdown
## Agent Role
[e.g., Frontend Agent, Backend Agent, Architect]

## Scope
[Which directories/features this agent owns for this task]

## Files Owned
| File/Directory | Access Level |
|----------------|-------------|
| `src/components/auth/` | Exclusive - only this agent modifies |
| `src/types/auth.ts` | Shared - coordinate before modifying |

## Dependencies on Other Agents
| Agent | What I Need | Status |
|-------|-------------|--------|
| Backend Agent | `/api/auth/login` endpoint ready | Pending |

## Shared Zone Changes
[List any changes this agent made to shared files, so other agents can rebase]
```

## Conflict Resolution

If two agents discover they need to modify the same file:

1. Check which agent's task was created first — that agent has priority
2. The second agent should document the conflict in its task file
3. Resolve by: (a) one agent delegates that file to the other, (b) sequential access with documented handoff, or (c) escalate to the Architect/PM agent

## Rationale

- Multi-agent file conflicts are the #1 cause of wasted work in parallel AI development
- Convention-level prevention is cheaper than merge-conflict resolution
- These rules work regardless of orchestration tool (Agent Teams, Gas Town, manual terminals)

## Exceptions Process

- If a hard rule must be violated, document the reason in the agent's task file and note it in `sessions/latest_summary.md`
- Emergency hotfixes to production-critical shared files override ownership rules but must be documented immediately
