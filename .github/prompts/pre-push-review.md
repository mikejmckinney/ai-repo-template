---
description: Dispatch Critic and linters locally against working tree before push.
agent: agent
---

# Pre-Push Review — Verify Working Tree Before Commit/Push

> **Usage**: You SHOULD post one of these to your prompt interface before pushing any non-trivial diff:
>   - `@claude follow .github/prompts/pre-push-review.md`
>   - `@copilot follow .github/prompts/pre-push-review.md`
>
> If you are the **DevOps** role touching shell, regex, or workflows, you MUST run this before pushing.

This prompt runs a local sanity check combining the Critic agent with `shellcheck`, `actionlint`, and the test suite, presenting a single summary for you (the implementer) to review.

## Phase 1: Local Linters and Tests

Run the following commands in the terminal. Do NOT stop if they fail; simply collect the output:

```bash
# 1. Shellcheck on modified shell scripts
git diff --name-only origin/main...HEAD | grep '\.sh$' | xargs -r shellcheck || true

# 2. Actionlint on modified workflow files
git diff --name-only origin/main...HEAD | grep -E '\.(yml|yaml)$' | xargs -r actionlint -ignore || true

# 3. Test suite
./test.sh || true
```

*Note: adjust `origin/main...HEAD` to use your actual base branch if it isn't `main`.*

## Phase 2: Dispatch Critic (PRE-PUSH)

Dispatch the **Critic** role (as defined in `.github/agents/critic.agent.md`) against your local diff. Provide Critic with the `git diff origin/<base>...HEAD` output.

Instruct Critic to operate in **PRE-PUSH** mode. Critic will use the DIFF-GATE checklist but will provide a lighter, consolidated output tailored for a local implementer rather than a formal PR review.

## Phase 3: Single Summary

After the tests and Critic review complete, output a **Single Summary** that includes:

1. **Linter/Test Status**: A concise report of any failures from `shellcheck`, `actionlint`, or `./test.sh`.
2. **Critic Feedback**: The raw (but lightweight) output from the Critic agent.
3. **Next Steps**: A short bulleted list of what you (the implementer) must fix before pushing, vs. what you can safely ignore.

Do not automatically commit or push. Wait for the user to review the summary.
