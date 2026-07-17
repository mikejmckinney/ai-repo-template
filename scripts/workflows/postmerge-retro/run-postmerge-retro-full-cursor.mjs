#!/usr/bin/env node
/**
 * Full-evidence post-merge retro via Cursor SDK (tool-enabled read of diff.patch + HEAD paths).
 * Requires: npm install @cursor/sdk@<pinned>, CURSOR_API_KEY.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { Agent, Cursor } from "@cursor/sdk";

const [promptFile, outFile] = process.argv.slice(2);
if (!promptFile || !outFile) {
  console.error(
    "Usage: run-postmerge-retro-full-cursor.mjs <prompt-file> <output-file>",
  );
  process.exit(2);
}

const apiKey = process.env.CURSOR_API_KEY;
if (!apiKey) {
  console.error("CURSOR_API_KEY required for full-evidence cursor retro");
  process.exit(1);
}

const modelId = process.env.CURSOR_ADVISORY_MODEL || "cursor-grok-4.5-medium";
const prompt = readFileSync(promptFile, "utf8");

/** @param {string} id */
async function buildCursorModelConfig(id) {
  if (id === "cursor-grok-4.5-medium") {
    const catalog = await Cursor.models.list({ apiKey });
    const grok = catalog.find((candidate) => candidate.id === "grok-4.5");
    const medium = grok?.variants?.find(
      (variant) => /medium/i.test(variant.displayName) && !/fast/i.test(variant.displayName),
    );
    if (!grok || !medium) {
      throw new Error("Cursor SDK catalog does not expose Grok 4.5 Medium non-fast");
    }
    return { id: grok.id, params: medium.params };
  }
  if (id === "composer-2.5-fast") {
    return { id: "composer-2.5", params: [{ id: "fast", value: "true" }] };
  }
  if (id === "composer-2.5") {
    return { id: "composer-2.5", params: [{ id: "fast", value: "false" }] };
  }
  return { id };
}

let model;
try {
  model = await buildCursorModelConfig(modelId);
} catch (err) {
  const message = err instanceof Error ? err.message : String(err);
  console.error(`::error::Cursor model resolution failed: ${message}`);
  process.exit(1);
}

function sanitizedErrorDetails(value) {
  const details = {
    status: value?.status ?? "unknown",
    error: value?.error ?? null,
    message: value?.message ?? null,
    keys: value && typeof value === "object" ? Object.keys(value).sort() : [],
  };
  let text = JSON.stringify(details);
  for (const secret of [process.env.CURSOR_API_KEY, process.env.OPENROUTER_API_KEY]) {
    if (secret && secret.length >= 8) text = text.replaceAll(secret, "[REDACTED]");
  }
  return text;
}
const runContext = {
  repo: process.env.GITHUB_REPOSITORY || "local",
  workflow: process.env.GITHUB_WORKFLOW || "local",
  job: process.env.GITHUB_JOB || "local",
  run_id: process.env.GITHUB_RUN_ID || "local",
  run_attempt: process.env.GITHUB_RUN_ATTEMPT || "1",
};

console.error(
  `Cursor full-evidence retro: repo=${runContext.repo} workflow=${runContext.workflow} job=${runContext.job} run_id=${runContext.run_id} attempt=${runContext.run_attempt}`,
);

let result;
try {
  result = await Agent.prompt(prompt, {
    apiKey,
    model,
    local: { cwd: process.cwd() },
  });
} catch (err) {
  const message = err instanceof Error ? err.message : String(err);
  const stack = err instanceof Error && err.stack ? err.stack : message;
  console.error(`::error::Cursor full-evidence retro Agent.prompt failed: ${message}`);
  console.error(stack);
  process.exit(1);
}

const observedModel = result?.model?.id ?? "unknown";
const fastParam = model.params?.find((p) => p.id === "fast")?.value;
const billingTier =
  observedModel.includes("fast") || fastParam === "true"
    ? "composer-2.5-fast"
    : fastParam === "false"
      ? "composer-2.5-standard"
      : "unknown";

console.error(
  `Cursor full-evidence retro: requested=${modelId} resolved=${JSON.stringify(model)} observed=${observedModel} fast_param=${fastParam ?? "unset"} billing_tier=${billingTier} status=${result?.status ?? "unknown"}`,
);

const text = result?.result ?? "";
if (!text.trim()) {
  console.error(
    `Cursor full-evidence retro returned empty result: ${sanitizedErrorDetails(result)}`,
  );
  process.exit(1);
}

writeFileSync(outFile, text, "utf8");
