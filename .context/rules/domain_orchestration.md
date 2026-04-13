# Domain: Agent Orchestration

> **Purpose**: Rules governing how agents are coordinated, how tasks are routed, and how quality is enforced in multi-agent workflows.

## Hard Rules (Never Violate)

1. **Coordinator never implements on complex tasks**: When using a coordinator/PM agent, the coordinator must route complex work to specialist agents. The coordinator tracks, synthesizes, and resolves blockers — it does not write code for complex tasks.

2. **Adversarial review is mandatory for 3+ agents**: When three or more agents work in parallel, at least one must be assigned the Reviewer/Adversary role to review all changes before merge.

3. **Shared state is the only communication channel**: Agents coordinate through `.context/state/` files and PR comments. Agents must not assume knowledge of another agent's work unless it is written in a state file or merged to a shared branch.

4. **Task routing must match complexity**: Use the complexity classification to determine agent count:

   | Complexity | Examples | Agent Count |
   |-----------|----------|-------------|
   | **Trivial** | Typo fix, config change, dependency bump | 1 (solo) |
   | **Moderate** | Single feature, bug with known cause, refactor | 1-2 + reviewer |
   | **Complex** | Multi-component feature, new system, major refactor | 3-5 + adversary |
   | **Critical** | Security fix, data migration, breaking change | Full team + mandatory adversarial review |

5. **Verification at every checkpoint**: Agents must run verification commands (tests, linting, build) after completing each subtask — not only at the end.

## Orchestration Patterns

### Pattern 1: Hub-and-Spoke (Recommended for Most Work)

```
           ┌─────────────┐
           │ Coordinator  │
           │   (PM/Lead)  │
           └──────┬───────┘
        ┌─────────┼──────────┐
        ▼         ▼          ▼
   ┌─────────┐ ┌─────────┐ ┌──────────┐
   │ Agent A  │ │ Agent B  │ │ Reviewer │
   │(Frontend)│ │(Backend) │ │(Adversary│
   └─────────┘ └─────────┘ └──────────┘
```

- Coordinator decomposes work and creates task files
- Specialist agents claim and execute tasks
- Reviewer validates all outputs before merge
- Coordinator synthesizes results and tracks progress

### Pattern 2: Pair Programming (For Moderate Complexity)

```
   ┌─────────────┐     ┌──────────────┐
   │ Implementer  │────▶│   Reviewer    │
   └─────────────┘     └──────────────┘
```

- One agent implements, one reviews
- Reviewer actively challenges assumptions
- Fast feedback loop via PR comments

### Pattern 3: Pipeline (For Sequential Dependencies)

```
   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
   │ Architect │───▶│ Backend  │───▶│ Frontend │───▶│ Testing  │
   └──────────┘    └──────────┘    └──────────┘    └──────────┘
```

- Each agent completes and hands off to the next
- Use when work is inherently sequential
- Each handoff includes verification

## Quality Gates

Before any agent's work is considered complete:

1. **Self-verification**: Agent runs all relevant tests and linting
2. **Peer review**: At least one other agent (or reviewer) examines the changes
3. **Integration check**: Changes are merged to a shared branch and tests pass
4. **Adversarial pass** (for complex/critical work): Adversary agent actively tries to break the implementation

## Soft Rules (Prefer Unless Justified)

1. **Start with interfaces**: The architect (or first agent) should define shared contracts before implementers begin
2. **Minimize agent count**: Use the fewest agents needed — coordination overhead is real
3. **Time-box agent work**: Set expected duration in task files to prevent runaway sessions
4. **Prefer feature branches**: Each agent works on a feature branch; merge to main only after review

## Rationale

Without orchestration rules, multi-agent work devolves into chaos: conflicting changes, duplicated effort, and no quality control. These patterns mirror how effective human engineering teams coordinate.

## Exceptions Process

If the coordinator needs to bypass the routing rules (e.g., only one agent available for a critical task):
1. Document the reason in the task file
2. Add extra verification steps to compensate for missing review
3. Flag the exception in `_active.md` for the next session
