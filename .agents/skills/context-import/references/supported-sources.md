# Supported Context Sources

## Cursor Agent

Verified format:

```text
~/.cursor/projects/<workspace-slug>/agent-transcripts/<uuid>/<uuid>.jsonl
```

Codespaces use the same layout under the remote user's home directory, for
example `/home/codespace/.cursor/projects/<workspace-slug>/agent-transcripts/`.

Each line is one JSON object. Importable messages have:

```json
{
  "role": "user",
  "message": {
    "content": [{"type": "text", "text": "..."}]
  }
}
```

The adapter joins text blocks and ignores tool-only blocks and lifecycle events
such as `turn_ended`. Subagent transcripts are not imported implicitly; pass an
exact subagent transcript path when its context is required.

Cursor CLI chat state under `~/.cursor/chats/` is not supported in the initial
adapter because its database-backed variants have not been needed for Agent
handoff.

## OpenCode

Verified database:

```text
~/.local/share/opencode/opencode.db
```

The adapter joins `message` and `part`, imports string-valued text parts, and
filters by one exact session ID.

## Unsupported Sources

Reject unknown platforms and unverified schemas. Use a copied Cursor Agent
JSONL transcript with `--transcript-path` for remote handoffs rather than
guessing another platform's internal storage.
