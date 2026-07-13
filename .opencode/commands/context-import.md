---
description: Import context from an exact Cursor or OpenCode source session
---

Load the `context-import` skill and import the source described by `$ARGUMENTS`.

Expected forms:

```text
/context-import cursor --session-id <uuid>
/context-import cursor --transcript-path <path>
/context-import opencode --session-id <ses_...>
```

Run this command on the receiving agent. Require an exact source identifier;
never infer the most recent source session. Read the generated packet, re-read
current authoritative sources, report the persistent receipt path, and emit a
fresh receiving-platform handshake and context receipt before continuing work.
