#!/usr/bin/env node

import { readFile, readdir, writeFile } from "node:fs/promises"
import { homedir } from "node:os"
import path from "node:path"
import { pathToFileURL } from "node:url"
import Ajv2020 from "../../../.github/agent-runtime/node_modules/ajv/dist/2020.js"
import { Agent, setGlobalDispatcher } from "../../../.github/agent-runtime/node_modules/undici/index.js"

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
const schema = schemaPath ? JSON.parse(await readFile(schemaPath, "utf8")) : undefined
const validate = schema ? new Ajv2020({ allErrors: true }).compile(schema) : undefined

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
setGlobalDispatcher(new Agent({ headersTimeout: timeoutMs, bodyTimeout: timeoutMs }))

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

async function writeRetrievalTrace(sessionID) {
  const outputPath = process.env.OPENCODE_RETRIEVAL_TRACE_FILE
  if (!outputPath) return
  const logDir = process.env.OPENCODE_LOG_DIR || path.join(homedir(), ".local/share/opencode/log")
  let content = ""
  try {
    const files = (await readdir(logDir, { withFileTypes: true }))
      .filter((entry) => entry.isFile())
      .map((entry) => entry.name)
      .sort()
    const latest = files.at(-1)
    if (latest) content = await readFile(path.join(logDir, latest), "utf8")
  } catch (error) {
    if (error.code !== "ENOENT") {
      console.error(`OpenCode: retrieval_trace_unavailable error=${redacted(error.message)}`)
    }
  }

  const paths = [...content.matchAll(/message=evaluated permission=read pattern=(.*?) action\.permission=read action\.action=allow/g)]
    .map((match) => match[1].replace(/^"|"$/g, ""))
  const uniquePaths = [...new Set(paths)]
  await writeFile(
    outputPath,
    `${JSON.stringify({ session_id: sessionID, paths: uniquePaths }, null, 2)}\n`,
  )
  console.log(`OpenCode: retrieval_trace paths=${uniquePaths.length}`)
}

function modelRef(model) {
  const separator = model.indexOf("/")
  if (separator < 1) throw new Error(`Invalid OpenCode model: ${model}`)
  return {
    providerID: model.slice(0, separator),
    modelID: model.slice(separator + 1),
  }
}

function responseText(result) {
  return (result.parts || [])
    .filter((part) => part.type === "text" && typeof part.text === "string")
    .map((part) => part.text)
    .join("\n")
    .trim()
}

function hasDerivedPriority(value) {
  if (Array.isArray(value)) return value.some(hasDerivedPriority)
  if (!value || typeof value !== "object") return false
  if (Object.hasOwn(value, "priority_band")) return true
  return Object.values(value).some(hasDerivedPriority)
}

function validatedOutput(result) {
  if (result.info?.error) {
    throw new Error(`${result.info.error.name}: ${JSON.stringify(result.info.error.data || {})}`)
  }
  const text = responseText(result)
  if (!text) return { error: "response omitted text output" }
  if (!validate) return { output: `${text}\n` }

  const candidate = text.replace(/^```(?:json)?\s*([\s\S]*?)\s*```$/i, "$1")
  let parsed
  try {
    parsed = JSON.parse(candidate)
  } catch (error) {
    return { error: `invalid JSON: ${error.message}` }
  }
  if (hasDerivedPriority(parsed)) {
    return { error: "priority_band is derived by automation; do not emit it" }
  }
  if (!validate(parsed)) {
    return { error: `schema validation failed: ${JSON.stringify(validate.errors)}` }
  }
  return { output: `${JSON.stringify(parsed, null, 2)}\n` }
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
    let result
    let checked
    for (let attempt = 0; attempt < 2; attempt += 1) {
      const text = attempt === 0
        ? prompt
        : `Your previous response failed deterministic validation: ${checked.error}\n` +
          `Return only JSON matching this schema, with no code fence:\n${JSON.stringify(schema)}`
      result = responseData(
        await opencode.client.session.prompt({
          sessionID,
          model: modelRef(requestedModel),
          parts: [{ type: "text", text }],
        }),
      )
      checked = validatedOutput(result)
      if (checked.output) break
      console.error(
        `OpenCode: output_validation_failed model=${requestedModel} attempt=${attempt + 1} ` +
        `error=${redacted(checked.error)}`,
      )
    }
    if (!checked.output) throw new Error(checked.error)
    const observedModel = result.info?.modelID || "unknown"
    const tokens = result.info?.tokens || {}
    console.log(
      `OpenCode: observed_model=${observedModel} requested_model=${requestedModel} ` +
      `input_tokens=${tokens.input ?? "unknown"} output_tokens=${tokens.output ?? "unknown"}`,
    )
    await writeRetrievalTrace(sessionID)
    await writeFile(outputPath, checked.output)
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
