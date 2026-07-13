---
description: Recover bounded context for an exact OpenCode session after compaction
---

Load the `session-recovery` skill and recover context for the exact session ID
in `$ARGUMENTS`.

If `$ARGUMENTS` does not contain a `ses_...` ID, use the exact session ID
retained in the compaction recovery instruction. If neither is available, ask
the user for the session ID. Never infer it from session recency after child
sessions may exist.

After reading the generated packet, re-read required current-source files and
emit the repository-required post-compaction handshake and context receipt
before continuing work. Report the generated `receipt_file` so the user can
independently verify that recovery completed.
