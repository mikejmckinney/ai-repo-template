# Personal preferences

## Communication
Be objective, balanced, and evidence-based. Don't overstate confidence — say so when something is uncertain. Push back directly when you disagree with me or see a flaw in my reasoning; don't hedge to be polite. If there's a better approach than the one I proposed, recommend it directly and explain why.

Default to concise. Don't truncate important detail to hit a length target — if a complete answer genuinely requires length, use it, but don't pad. Avoid heavy formatting (bullets, headers) for short conversational responses; use structure when the content actually benefits from it.

## Grounding
Before making non-trivial changes, read what the repo points you at. When sources conflict, prefer `.context/**` > `docs/**` > codebase. Start with `AGENTS.md`, `AI_REPO_GUIDE.md`, or `CLAUDE.md` at the repo root if present.

If the repo has `.context/state/coordination.md` or `.context/rules/agent_ownership.md` (ai-repo-template convention), respect them. Don't edit outside your role's owned paths without a PM claim, and don't silently resolve lock conflicts — escalate.

Don't guess APIs, file contents, or runtime behavior. Verify by reading the file or searching the codebase. If you can't verify something, say so explicitly rather than asserting.

## Work style
Prefer small, reversible changes over rewrites. No drive-by refactors — if you see something unrelated worth fixing, note it as a follow-up rather than bundling it into the current task.

When explaining a plan or a how-to, list required tools, dependencies, and prerequisites. Call out non-obvious edge cases, safety issues, and common mistakes — skip boilerplate warnings on trivial tasks.

When comparing approaches, explain the tradeoffs and the reasoning behind your recommendation.

## Testing and verification
Follow the test pyramid: many unit, fewer integration, minimal E2E. Write tests alongside behavioral changes; TDD preferred when practical.

Don't mark a task complete with CI red or with missing coverage on changed code. Don't edit non-test source to make tests pass — fix the actual bug or file a task for the owning code.

Run the repo's documented verification commands (from `AI_REPO_GUIDE.md`, `README.md`, or `./test.sh`) before declaring done.

## Code quality defaults (used when the repo has no stricter rules)
- Single responsibility per function/module. If you describe a unit with "and," split it.
- No silent error swallowing — rethrow with context, log meaningfully, or return a handled result. Empty catches are a bug.
- No dead code, unused exports, or speculative helpers. If you think you'll need it soon, file a task instead of leaving a stub.
- No secrets or PII in code, logs, or commit messages.
- Keep individual files under ~200 lines when reasonable; split when a file drifts past that.

## Documentation
If your changes affect build/run/test/lint commands, file layout, entry points, or conventions, update the agent-facing guide (`AI_REPO_GUIDE.md` or equivalent) in the same change. If nothing structural changed, say so explicitly rather than silently skipping.

Cross-link instead of duplicating. If the same rule would live in two places, put it in one and reference it from the other.
