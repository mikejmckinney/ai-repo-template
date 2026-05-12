# ADR-001: Context Pack Structure for LLM Memory

## Status

Accepted (superseded in part by ADR-025)

## Date

2025-01-25

## Context

Large Language Models (LLMs) used for coding assistance are stateless - they don't remember previous conversations or project context between sessions. This leads to:

1. **Repeated context loading**: Agents must re-read the same files every session
2. **Lost decisions**: Rationale for past choices isn't preserved
3. **Inconsistent work**: Different sessions may approach problems differently
4. **Cognitive overhead**: Developers must re-explain project state each time

We needed a structured way to provide LLMs with project context that:
- Persists across sessions (stored in git)
- Has clear priority when conflicts arise
- Supports cognitive handoff between agent sessions
- Doesn't overwhelm token limits

## Decision

We will use a `.context/` directory structure as the canonical source of project truth for AI agents, with the following hierarchy:

ADR-025 later moves **live coordination** out of repo-local task files and into GitHub issues, PRs, `agent-state:v1` comments, and labels. The durable `.context/` rules/roadmap/vision/session-retrospective structure remains canonical.

```
.context/
├── 00_INDEX.md          # Entry point, project summary
├── roadmap.md           # Phase-by-phase plan
├── rules/               # Immutable domain constraints
│   └── domain_*.md      # Specific rule files
├── state/               # Mutable progress tracking
│   ├── _active.md       # Points to current priority task
│   └── task_*.md        # Individual task files
└── vision/              # Design artifacts
    ├── mockups/         # UI/UX designs
    └── architecture/    # System diagrams
```

Priority order when conflicts arise:
1. `.context/**` (highest)
2. `docs/**`
3. Codebase (lowest)

## Options Considered

### Option 1: Single AI_REPO_GUIDE.md file
- **Pros**: Simple, single file to read
- **Cons**: Gets unwieldy for large projects, mixes mutable/immutable content, hard to update portions

### Option 2: Structured `.context/` directory
- **Pros**: Clear separation of concerns, selective loading, supports project growth
- **Cons**: More files to maintain, agents must know the structure

### Option 3: Use existing docs/ directory
- **Pros**: No new structure needed
- **Cons**: Mixes human docs with agent context, no clear priority, may contain conflicting information

## Consequences

### Positive

- **Session continuity**: Task files (`task_*.md`) enable cognitive handoff between sessions
- **Selective loading**: Agents can load only what's needed (rules vs. state vs. roadmap)
- **Clear authority**: Priority hierarchy resolves conflicting information
- **Separation of concerns**: Immutable rules vs. mutable state vs. design vision
- **Scalability**: Structure works for small and large projects

### Negative

- **Learning curve**: Agents and developers must understand the structure
- **Maintenance overhead**: More files to keep up-to-date
- **Token usage**: May use more tokens if agent reads everything

### Neutral

- Structure uses `TEMPLATE_PLACEHOLDER` markers for easy identification of stub content
- Works alongside existing `AI_REPO_GUIDE.md` (which provides quick reference)

## Implementation

- [x] Create `.context/` directory structure
- [x] Add placeholder files with documentation
- [x] Update `AGENTS.md` with usage instructions
- [x] Update `test.sh` to verify structure
- [x] Document in `AI_REPO_GUIDE.md`

## References

- [Building LLM Applications: Context Management](https://www.anthropic.com/research)
- [The Twelve-Factor App: Config](https://12factor.net/config)
- Internal discussion on agent memory patterns
