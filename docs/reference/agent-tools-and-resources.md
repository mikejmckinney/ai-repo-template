# Agent Tools and Resources

> **Purpose**: Curated list of external tools, plugins, and resources that enhance AI agent workflows. These are optional — the template works without them, but they add value for specific tools or workflows.

## Code Quality Skills

### solid-skills (Claude Code)

**What**: A Claude Code skills plugin that enforces SOLID principles, TDD, clean code, and design patterns automatically.  
**Best for**: TypeScript and NestJS projects, but applicable to any OOP codebase.  
**Install**: `npx skills add ramziddin/solid-skills`  
**Repository**: [github.com/ramziddin/solid-skills](https://github.com/ramziddin/solid-skills)

**What it provides**:
- Enforces TDD workflow (write failing test first)
- Detects and fixes code smells automatically
- Applies SOLID principles to every class and function
- Reference documentation for SOLID, TDD, clean code, design patterns, and architecture

**Note**: This is Claude Code-specific. For cross-tool quality rules, see `.context/rules/domain_code_quality.md` which distills these principles in a tool-agnostic format.

---

## Comprehensive Agent Systems

### Everything Claude Code (ECC)

**What**: A large-scale agent harness performance system with 38+ agents, 156+ skills, hooks, memory optimization, and cross-harness support.  
**Best for**: Teams wanting a full agent operating system, primarily for Claude Code but with Cursor, Codex, and OpenCode support.  
**Repository**: [github.com/affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code)

**Key concepts worth studying** (cherry-picked for this template):
- **Memory optimization**: Model selection, system prompt slimming, lazy-load context patterns
- **Session hooks**: Automated save/load of context on session start/stop
- **Verification loops**: Checkpoint evaluations at intermediate steps, not just final output
- **Parallelization**: Git worktree-based parallel agent execution
- **Multi-language rules**: Language-specific rules architecture (TypeScript, Python, Go, etc.)

**Note**: ECC is a full product, not a template. This dotfiles template takes a lighter, tool-agnostic approach. Use ECC if you want maximum Claude Code optimization; use this template for a simpler, cross-tool foundation.

---

## Multi-Agent Orchestration References

### 13-Agent Pattern

**What**: An architecture where a coordinator agent routes tasks to specialized agents (architect, implementer, validator, adversary) with shared state coordination and adversarial review loops.  
**Source**: Community patterns from Claude AI users and software engineering teams.

**Key concepts** (implemented in this template):
- Hub-and-spoke coordination (see `.context/rules/domain_orchestration.md`)
- Role-based agent assignment (see `.context/vision/architecture/agent-roles.md`)
- Task routing by complexity (trivial → solo, moderate → pair, complex → full team)
- Adversarial review as a quality gate
- Shared state coordination via task files

**Reference articles**:
- [I Built a 13-Agent AI System That Reviews Its Own Decisions — Architecture Deep Dive](https://dev.to/jarradbermingham/i-built-a-13-agent-ai-system-that-reviews-its-own-decisions-heres-the-architecture-pbd) — DEV Community
- [Multi-Agent Orchestration: When AI Teams Beat Solo Acts](https://sjramblings.io/multi-agent-orchestration-claude-code-when-ai-teams-beat-solo-acts/) — SJRamblings

---

## Agent Skills Format

### Anthropic Agent Skills

**What**: A standardized format for packaging reusable agent instructions as installable skills.  
**Repository**: [github.com/anthropics/agent-skills](https://github.com/anthropics/agent-skills)  
**Best for**: Claude Code users who want to share and reuse agent behaviors.

---

## Tool-Specific Configuration

This template includes configuration for multiple AI tools. Here's where to find tool-specific guidance:

| Tool | Config File | Purpose |
|------|------------|---------|
| GitHub Copilot | `.github/copilot-instructions.md` | Auto-loaded instructions |
| GitHub Copilot Agents | `.github/agents/*.agent.md` | Specialized agent definitions |
| Cursor | `.cursor/BUGBOT.md` | PR review rules |
| Gemini Code Assist | `.gemini/styleguide.md` | Code review style guide |
| Claude Code | Use `AGENTS.md` + optional skills | Root instructions |
| Codex | Use `AGENTS.md` | Root instructions |

## Contributing Resources

If you know of a tool or resource that would benefit this template, consider:
1. Adding it to this reference document with a brief description
2. If it contains universal principles, distill them into a `.context/rules/domain_*.md` file
3. Keep the template tool-agnostic — add references, not hard dependencies
