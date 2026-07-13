# Troubleshooting

## Environment Failure

Run `scripts/validate-environment.sh`. Confirm `opencode`, `jq`, `perl`, and
`sqlite3` are available and that `opencode models openai` lists
`openai/gpt-5.6-sol`.

## Engine Failure

Inspect the output directory's `.err` files. The runner records failed engines
in its JSON result and automatically tries the next engine.

## Panel Failure

Fusion requires two successful panels. Inspect `panel-*.err` and `panel-*.md`.
Do not restart a panel merely because it timed out if OpenCode created a usable
session; continue that session with a narrower request when recovery has clear
value.

## Missing Session ID

Search by the unique title shown in command logs:

```bash
opencode session list --format json --max-count 100 \
  | jq -r '.[] | select(.title == "<exact-title>") | .id'
```

## Tests

Run the isolated orchestration suite:

```bash
bats --tap .opencode/skills/local-consensus/tests/orchestration.bats
```
