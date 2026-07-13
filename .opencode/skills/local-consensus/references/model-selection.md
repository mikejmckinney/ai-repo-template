# Model Selection

The deterministic fallback order is:

| Priority | Role | Provider and model |
|---|---|---|
| 1 | Judge/Advisor | OpenAI `openai/gpt-5.6-sol` |
| 2 | Judge/Advisor | Claude CLI `fable` |
| 3 | Judge/Advisor | OpenRouter `openrouter/z-ai/glm-5.2@preset/default` |

Fusion primary panels use:

| Panel | Provider and model |
|---|---|
| Sol | OpenAI `openai/gpt-5.6-sol` |
| Fable | Claude CLI `fable` |
| GLM | OpenRouter `openrouter/z-ai/glm-5.2@preset/default` |

Failed primary slots are backfilled without duplication in this order:

| Priority | Provider and model |
|---|---|
| 1 | `openrouter/minimax/minimax-m3@preset/default` |
| 2 | `openrouter/xiaomi/mimo-v2.5-pro@preset/default` |
| 3 | `openrouter/deepseek/deepseek-v4-pro@preset/default` |

Because the Judge uses the same Sol/Fable/GLM fallback chain, its selected
engine may overlap with a panelist. Fusion reports this as `judge_overlap` and
anonymizes panel labels before judging.

Override Sol or GLM for controlled testing with
`LOCAL_CONSENSUS_SOL_MODEL` or `LOCAL_CONSENSUS_GLM_MODEL`. Do not override
production model selection without a task-specific reason.
