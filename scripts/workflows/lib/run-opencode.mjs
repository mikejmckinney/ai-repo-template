#!/usr/bin/env node

import { readFile, readdir, writeFile } from "node:fs/promises"
import { homedir } from "node:os"
import path from "node:path"
import { pathToFileURL } from "node:url"

const [promptPath, outputPath, schemaPath] = process.argv.slice(2)
if (!promptPath || !outputPath) {
  console.error("Usage: run-opencode.mjs <prompt-file> <output-file> [schema-file]")
  process.exit(2)
}

const defaultModels = [
  "openrouter/z-ai/glm-5.2@preset/default",
  "openrouter/minimax/minimax-m3@preset/default",
]
const models = (process.env.OPENCODE_MODELS || defaultModels.join(","))
  .split(",")
  .map((model) => model.trim())
  .filter(Boolean)
if (models.length === 0) throw new Error("OPENCODE_MODELS resolved to an empty model list")
const prompt = await readFile(promptPath, "utf8")
const schema = schemaPath
  ? JSON.parse(await readFile(schemaPath, "utf8"))
  : {
      type: "object",
      properties: { output: { type: "string" } },
      required: ["output"],
      additionalProperties: false,
    }

const mode = process.env.OPENCODE_MODE === "fix" ? "fix" : "review"
const defaultConfig = path.resolve(`.github/agent-runtime/${mode}.json`)
const configPath = process.env.OPENCODE_CONFIG_FILE || defaultConfig
const config = JSON.parse(await readFile(configPath, "utf8"))
const sdkSpecifier = process.env.OPENCODE_SDK_MODULE || "@opencode-ai/sdk/v2"
const sdk = await import(
  path.isAbsolute(sdkSpecifier) ? pathToFileURL(sdkSpecifier).href : sdkSpecifier
)
const timeoutMs = Number.parseInt(process.env.OPENCODE_TIMEOUT_MS || "900000", 10)
if (!Number.isSafeInteger(timeoutMs) || timeoutMs <= 0) {
  throw new Error("OPENCODE_TIMEOUT_MS must be a positive integer")
}

function responseData(response) {
  if (response?.error) throw new Error(JSON.stringify(response.error))
  return response?.data ?? response
}

function redacted(message) {
  let result = String(message)
  for (const name of [
    "OPENAI_API_KEY",
    "OPENROUTER_API_KEY",
    "OPENCODE_GITHUB_TOKEN",
    "CURSOR_API_KEY",
    "GEMINI_API_KEY",
  ]) {
    const value = process.env[name]
    if (value && value.length >= 8) result = result.replaceAll(value, "[REDACTED]")
  }
  return result
}

async function latestServerLog() {
  const logDir = process.env.OPENCODE_LOG_DIR || path.join(homedir(), ".local/share/opencode/log")
  try {
    const files = (await readdir(logDir, { withFileTypes: true }))
      .filter((entry) => entry.isFile())
      .map((entry) => entry.name)
      .sort()
    const latest = files.at(-1)
    if (!latest) return ""
    return redacted((await readFile(path.join(logDir, latest), "utf8")).slice(-12000))
  } catch (error) {
    if (error.code === "ENOENT") return ""
    return `diagnostic_log_unavailable error=${redacted(error.message)}`
  }
}

function modelRef(model) {
  const separator = model.indexOf("/")
  if (separator < 1) throw new Error(`Invalid OpenCode model: ${model}`)
  return {
    providerID: model.slice(0, separator),
    modelID: model.slice(separator + 1),
  }
}

let lastError
for (const requestedModel of models) {
  const abortController = new AbortController()
  const timer = setTimeout(() => abortController.abort(), timeoutMs)
  let opencode
  let sessionID
  try {
    console.log(`OpenCode: requested_model=${requestedModel} mode=${mode}`)
    opencode = await sdk.createOpencode({
      port: 0,
      signal: abortController.signal,
      timeout: Math.min(timeoutMs, 30000),
      config,
    })
    if (opencode.client.global?.health) {
      const health = responseData(await opencode.client.global.health())
      console.log(`OpenCode: runtime_version=${health.version || "unknown"}`)
    }
    const session = responseData(
      await opencode.client.session.create({
        title: `workflow:${process.env.GITHUB_WORKFLOW || "local"}:${process.env.GITHUB_RUN_ID || "none"}`,
      }),
    )
    sessionID = session.id
    const result = responseData(
      await opencode.client.session.prompt({
        sessionID,
        model: modelRef(requestedModel),
        parts: [{ type: "text", text: prompt }],
        format: { type: "json_schema", schema, retryCount: 1 },
      }),
    )
    if (result.info?.error) {
      throw new Error(`${result.info.error.name}: ${JSON.stringify(result.info.error.data || {})}`)
    }
    const structured = result.info?.structured
    if (structured === undefined) throw new Error("OpenCode response omitted structured output")
    const observedModel = result.info?.modelID || "unknown"
    const tokens = result.info?.tokens || {}
    console.log(
      `OpenCode: observed_model=${observedModel} requested_model=${requestedModel} ` +
      `input_tokens=${tokens.input ?? "unknown"} output_tokens=${tokens.output ?? "unknown"}`,
    )
    const output = typeof structured.output === "string"
      ? structured.output
      : `${JSON.stringify(structured, null, 2)}\n`
    await writeFile(outputPath, output)
    process.exitCode = 0
    lastError = undefined
    break
  } catch (error) {
    lastError = error
    console.error(`OpenCode: model_failed=${requestedModel} error=${redacted(error.message)}`)
    const serverLog = await latestServerLog()
    if (serverLog) console.error(`OpenCode: server_log_tail\n${serverLog}`)
  } finally {
    clearTimeout(timer)
    if (sessionID && opencode?.client?.session) {
      await opencode.client.session.delete({ sessionID }).catch((error) => {
        console.error(`OpenCode: session_cleanup_failed error=${redacted(error.message)}`)
      })
    }
    opencode?.server?.close()
  }
}

if (lastError) {
  console.error(`OpenCode model cascade exhausted: ${redacted(lastError.message)}`)
  process.exit(1)
}
