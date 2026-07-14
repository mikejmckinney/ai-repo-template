# GitHub Copilot repository instructions

GitHub Copilot automatically loads this file. The repository-wide operating
contract is [`AGENTS.md`](../AGENTS.md); follow it without rereading it unless
the user explicitly requests a freshness check.

## Useful references

- [`AI_REPO_GUIDE.md`](../AI_REPO_GUIDE.md) documents repository structure and
  verified commands.
- [`.context/00_INDEX.md`](../.context/00_INDEX.md) maps current project state,
  benchmarks, roadmap, and design artifacts.
- [`.github/PLAN_TEMPLATE.md`](PLAN_TEMPLATE.md) is the implementation-plan
  template for issue-backed work.
- [`.github/prompts/op-issue-workflow.md`](prompts/op-issue-workflow.md) is the
  end-to-end issue-to-merge playbook.

## Execution model

Use one monolithic implementing agent. Use the OpenCode `local-consensus` skill
only when the user requests it or consequential uncertainty justifies independent
multi-model review. Advisory review is optional and never blocks implementation.

## Following prompt files

When a comment or issue contains `@copilot follow <path>`:

1. Accept only a path under `.github/prompts/`.
2. Read the complete file before acting.
3. Treat it as the task procedure and execute its applicable steps in order.
4. If output would exceed GitHub's comment limit, split it into numbered parts
   rather than truncating it.

See [`docs/guides/agent-pipeline.md`](../docs/guides/agent-pipeline.md) for the
active advisory, CI, and retro lifecycle.
- Skip findings whose thread contains a reply beginning with `Deferred —`.
- Honor project-convention exclusions in [`.cursor/BUGBOT.md`](../.cursor/BUGBOT.md)
  and [`.gemini/styleguide.md`](../.gemini/styleguide.md).
- Prefer skipping uncertain duplicates; report genuinely distinct defects.
