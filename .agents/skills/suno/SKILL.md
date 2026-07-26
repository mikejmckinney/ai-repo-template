---
name: suno
description: |
  Create and manage Suno-backed music through Ace Data Cloud's third-party MCP.
  Use whenever a user asks to generate a song, write lyrics for generation,
  extend, remix, cover, remaster, separate stems, convert, or inspect Suno music,
  even when they mention only Suno or an AI song. Require explicit approval
  before chargeable operations and never describe this as an official Suno API.
---

# Suno Through Ace Data Cloud

Use the configured `suno` MCP as a third-party integration. It runs Ace Data
Cloud's open-source client and sends requests to Ace Data Cloud's API; Suno does
not publish this repository's skill or MCP server. Never imply that Ace's
proprietary upstream access mechanism is known or endorsed by Suno.

## Establish the request

Confirm only details needed for the requested operation:

- intended result: instrumental, vocal song, lyrics, extension, cover, remix,
  remaster, stems, conversion, or task lookup;
- prompt, lyrics, title, style, duration, vocals, and source audio identifiers;
- output constraints and how the user will judge success;
- rights to any uploaded audio, lyrics, voice, or persona material;
- the user's acceptable provider spend for chargeable calls.

Do not imitate a living artist or clone a person's voice without authorization.
For uploads and derivative operations, proceed only when the user confirms they
own the material or have permission to use it.

## Authentication and service boundary

The local MCP launcher requires `ACEDATACLOUD_API_TOKEN`. Never request that the
user paste the token into chat, print it, write it to repository files, or place
it in command arguments. If authentication fails, ask the user to set or replace
the environment variable outside the conversation.

Ace Data Cloud controls pricing, quotas, available models, retention, and API
behavior. Check the current MCP schemas and provider documentation instead of
guessing parameter names, model IDs, credit costs, or completion times.

## Approval boundary

Treat music generation, lyrics generation, extension, cover, remix, remaster,
stems, section replacement, upload-based generation, persona creation, and media
conversion as potentially chargeable. Before the first such call, state the
specific operation and requested bound, then obtain explicit approval. A token
being configured is authentication, not spending approval.

Read-only calls such as `suno_list_models`, `suno_list_actions`,
`suno_get_lyric_format_guide`, `suno_get_task`, and `suno_get_tasks_batch` may be
used without spending approval when they do not initiate provider work. If the
current tool description or provider pricing indicates otherwise, stop and ask.

## Workflow

1. Inspect available tools and their current input schemas. Use
   `suno_list_models` or `suno_list_actions` when model or capability selection
   affects the request.
2. Explain the third-party boundary and identify any potentially chargeable
   operation. Obtain explicit approval before invoking it.
3. Select the narrowest tool that performs the requested operation. For a basic
   prompt-based song, prefer `suno_generate_music`; for user-supplied lyrics and
   style control, prefer `suno_generate_custom_music`.
4. Preserve the returned task identifier. Use `suno_get_task` to retrieve status
   and results rather than resubmitting when processing is incomplete.
5. Prefer the documented terminal signal: top-level `state` is `complete` and
   `response.success` is true. In pinned `mcp-suno==2026.7.4.0`, Ace may omit the
   top-level state after successful generation; accept the result as complete
   only when `response.success` is true, `response.data` is non-empty, every data
   item has `state` equal to `succeeded`, and every item has a final `audio_url`.
6. Report the provider-observed status and returned media metadata. Do not claim
   completion from MCP startup, request acceptance, or a task identifier alone.
7. Redact credentials, account identifiers, and signed or expiring media query
   parameters from durable evidence. Tell the user when provider URLs may expire.

For multi-step transformations, complete and verify each prerequisite task before
starting the next chargeable operation. Never retry a chargeable call merely
because polling is slow; query the existing task first and ask before a new paid
attempt after a terminal failure.

## Validation

Validate the user's requested outcome, not only transport health:

- startup and tool listing prove configuration only;
- request acceptance proves only that Ace received the task;
- a completed task with the requested playable or downloadable result is the
  minimum evidence for generation success;
- an `unknown` MCP polling status is not authoritative when the pinned server's
  raw result satisfies the strict `response.success`/`succeeded` fallback above;
- subjective music quality remains the user's judgment.

When repository evidence is required, retain a redacted task/result record and
media metadata rather than a secret-bearing transcript or signed URL.

## Sources

- [Reviewed AceDataCloud/SunoMCP commit](https://github.com/AceDataCloud/SunoMCP/commit/0473b0ba5d454e2dd1eafdd06828627d06c23774)
- [Ace Data Cloud Suno API documentation](https://platform.acedata.cloud/documents/4da95d9d-7722-4a72-857d-bf6be86036e9)
- [Suno terms](https://suno.com/terms)

## Ownership and freshness

This is a repository-owned skill and is excluded from external refresh
automation. Revalidate Ace's tool schemas, pricing boundary, release provenance,
API documentation, and Suno's terms whenever the pinned MCP changes or this
skill is materially edited.
