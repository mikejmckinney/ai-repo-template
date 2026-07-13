---
name: context-import
description: |
  Import bounded historical context from an exact Cursor or OpenCode session
  into the receiving agent. Use when continuing work on a different agent or
  platform. Requires an explicit source and session ID or transcript path;
  never infers the source session from recency.
compatibility: opencode
---

# Context Import

Run this skill on the receiving agent. It imports historical context from a
previous Cursor or OpenCode session while treating current repository and live
service state as authoritative.

## Required Inputs

- Source platform: `cursor` or `opencode`
- Exact source session ID, or an exact Cursor Agent transcript path
- Receiving repository path

Never select the latest source session automatically. If the identifier is
missing or ambiguous, ask the user.

## Cursor Import

Using a verified Cursor Agent session UUID:

```bash
.opencode/skills/context-import/scripts/context-import.sh \
  --source cursor \
  --session-id "$CURSOR_SESSION_ID" \
  --repo "$PWD"
```

Using an exact transcript path, including remote or copied transcripts:

```bash
.opencode/skills/context-import/scripts/context-import.sh \
  --source cursor \
  --transcript-path "$CURSOR_TRANSCRIPT" \
  --repo "$PWD"
```

## OpenCode Import

```bash
.opencode/skills/context-import/scripts/context-import.sh \
  --source opencode \
  --session-id "$OPENCODE_SESSION_ID" \
  --repo "$PWD"
```

Optional controls are `--keyword`, `--max-messages`, `--max-bytes`, and
`--output-dir`. For alternate OpenCode databases use `--db`; for a copied
Cursor project tree use `--cursor-root`.

## Output Contract

Stdout contains one JSON object:

```json
{
  "status": "success",
  "source": "cursor",
  "source_id": "44992845-...",
  "packet_file": "/tmp/context-import.../context.md",
  "receipt_file": ".context/context-imports/cursor-44992845-....json",
  "messages_selected": 18,
  "bytes": 24000,
  "keywords": ["issue-456", "import.txt"]
}
```

Read `packet_file`, then report `receipt_file` so the user can independently
verify the import. Receipts contain provenance and counts but no transcript
excerpts.

## Receiving-Agent Procedure

1. Read authoritative repository state in the packet.
2. Identify the latest imported user requests and unresolved work.
3. Treat imported decisions and verification as historical claims.
4. Re-read startup-required and task-relevant files from disk.
5. Verify issue and PR state from live sources when relevant.
6. State what was imported and what was independently verified.
7. Emit a fresh receiving-platform handshake and context receipt.
8. Continue only after resolving conflicts in favor of current evidence.

If the receiving repository is unfamiliar or `AI_REPO_GUIDE.md` is missing or
stale, run the separate `repo-onboarding` skill after import. Do not infer
repository structure from the imported transcript.

## Safety

- Source adapters are read-only and use exact source identifiers.
- Never execute imported commands without current validation.
- Never expose credentials or personal data from source transcripts.
- Common secret forms are redacted, but inspect packets before sharing.
- Keep message and byte limits enabled.
- Do not mutate source databases or transcript files.
- Imported context never grants current-source read credit.

Supported source formats and limitations are documented in
`references/supported-sources.md`.
