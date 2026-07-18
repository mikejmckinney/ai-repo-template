# Model Selection

The deterministic fallback order is:

| Priority | Role | Provider and model |
|---|---|---|
| 1 | Judge/Advisor | OpenAI `openai/gpt-5.6-sol` |
| 2 | Judge/Advisor | Claude CLI `fable` |
| 3 | Judge/Advisor | Cursor CLI `cursor-grok-4.5-medium` |
| 4 | Judge/Advisor | OpenRouter `openrouter/z-ai/glm-5.2@preset/default` |

Fusion primary panels use:

| Panel | Provider and model |
|---|---|
| Kimi | OpenRouter `openrouter/moonshotai/kimi-k3` |
| Fable | Claude CLI `fable` |
| Grok | Cursor CLI `cursor-grok-4.5-medium` |

Failed primary slots are backfilled without duplication in this order:

| Priority | Provider and model |
|---|---|
| 1 | `openai/gpt-5.6-sol` |
| 2 | `openrouter/z-ai/glm-5.2@preset/default` |
| 3 | `openrouter/minimax/minimax-m3@preset/default` |
| 4 | `openrouter/xiaomi/mimo-v2.5-pro@preset/default` |
| 5 | `openrouter/deepseek/deepseek-v4-pro@preset/default` |

Because the Judge uses the same Sol/Fable/Grok/GLM fallback chain, its selected
engine may overlap with a panelist. Fusion reports this as `judge_overlap` and
anonymizes panel labels before judging.

Override Kimi, Sol, Grok, or GLM for controlled testing with
`MULTI_MODEL_CONSENSUS_KIMI_MODEL`, `MULTI_MODEL_CONSENSUS_SOL_MODEL`,
`MULTI_MODEL_CONSENSUS_GROK_MODEL`, or `MULTI_MODEL_CONSENSUS_GLM_MODEL`. Do not override
production model selection without a task-specific reason.
