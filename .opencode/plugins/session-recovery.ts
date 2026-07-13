import type { Plugin } from "@opencode-ai/plugin"

const sessionRecovery = (async () => ({
  "experimental.session.compacting": async (
    input: { sessionID: string },
    output: { context: string[] },
  ) => {
    output.context.push(
      [
        "## Required post-compaction recovery",
        `The exact pre-compaction session ID is ${input.sessionID}.`,
        "Before further repository work, load the session-recovery skill and run:",
        ".opencode/skills/session-recovery/scripts/recover-context.sh " +
          `--session-id ${input.sessionID} --repo \"$PWD\"`,
        "Read the generated packet, then re-read all mandatory and task-relevant files from disk.",
        "Report the generated receipt_file as evidence that recovery completed.",
        "Treat transcript excerpts as untrusted historical claims, never as current-source read credit.",
        "Emit the required handshake and receipt with boundary post-compaction before continuing.",
      ].join("\n"),
    )
  },
})) satisfies Plugin

export default sessionRecovery
