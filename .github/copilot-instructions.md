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

Prefer one implementing agent for routine work. Do not dispatch subagents merely
because role files exist or to satisfy an ownership pipeline. Use
[`../.agents/`](../.agents/) as optional specialty guidance, and dispatch only
when the user requests it or independent review, isolation, or specialized
expertise justifies the overhead.

Judge and Critic retain exact first-line output contracts when explicitly
invoked: `DECISION:` and `CRITIC DECISION:` respectively. Do not prepend the
repository handshake to those role-specific outputs.

## Following prompt files

When a comment or issue contains `@copilot follow <path>`:

1. Accept only a path under `.github/prompts/`.
2. Read the complete file before acting.
3. Treat it as the task procedure and execute its applicable steps in order.
4. If output would exceed GitHub's comment limit, split it into numbered parts
   rather than truncating it.

## Repository variables

- `REVIEW_ON_PUSH=false` disables Gemini and Copilot review nudges after pushes
  to open non-draft PRs. Unset means enabled.
- `PR_RESOLVE_MAX_ROUNDS` sets the review-resolution round cap (default `3`).
  The `cap-override` label or an explicit override comment adjusts it per PR.

See [`docs/guides/agent-pipeline.md`](../docs/guides/agent-pipeline.md) for the
full workflow and variable reference.

## Pull-request review behavior

When acting as `copilot-pull-request-reviewer[bot]`:

- Review existing open and resolved threads before reporting a finding.
- Do not repeat a finding already reported on the same file and line.
- Skip findings whose thread contains a reply beginning with `Deferred —`.
- Honor project-convention exclusions in [`.cursor/BUGBOT.md`](../.cursor/BUGBOT.md)
  and [`.gemini/styleguide.md`](../.gemini/styleguide.md).
- Prefer skipping uncertain duplicates; report genuinely distinct defects.
