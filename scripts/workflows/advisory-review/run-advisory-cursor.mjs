#!/usr/bin/env node
/**
 * Generate advisory review body via Cursor SDK (Composer 2.5 standard tier).
 * Requires: npm install @cursor/sdk@<pinned> (workflow step), CURSOR_API_KEY.
 * Pin: scripts/workflows/lib/cursor-sdk-version.sh (CURSOR_SDK_VERSION).
 *
 * Composer 2.5 billing: passing only model id "composer-2.5" defaults to the
 * fast (higher-cost) variant in the SDK. We always set fast=false for standard
 * tier unless the model id explicitly ends with "-fast".
 * @see https://forum.cursor.com/t/sdk-reports-composer-2-5-but-usage-dashboard-bills-composer-2-5-fast/163046
 */
import { readFileSync, writeFileSync } from "node:fs";
import { Agent } from "@cursor/sdk";

const [promptFile, outFile] = process.argv.slice(2);
if (!promptFile || !outFile) {
  console.error("Usage: run-advisory-cursor.mjs <prompt-file> <output-file>");
  process.exit(2);
}

const apiKey = process.env.CURSOR_API_KEY;
if (!apiKey) {
  console.error("CURSOR_API_KEY required");
  process.exit(1);
}

const modelId = process.env.CURSOR_ADVISORY_MODEL || "composer-2.5";
const prompt = readFileSync(promptFile, "utf8");

/** @param {string} id */
function buildCursorModelConfig(id) {
  if (id === "composer-2.5-fast") {
    return { id: "composer-2.5", params: [{ id: "fast", value: "true" }] };
  }
  if (id === "composer-2.5") {
    return { id: "composer-2.5", params: [{ id: "fast", value: "false" }] };
  }
  return { id };
}

const model = buildCursorModelConfig(modelId);
const runContext = {
  repo: process.env.GITHUB_REPOSITORY || "local",
  workflow: process.env.GITHUB_WORKFLOW || "local",
  job: process.env.GITHUB_JOB || "local",
  run_id: process.env.GITHUB_RUN_ID || "local",
  run_attempt: process.env.GITHUB_RUN_ATTEMPT || "1",
};

console.error(
  `Cursor advisory review context: repo=${runContext.repo} workflow=${runContext.workflow} job=${runContext.job} run_id=${runContext.run_id} attempt=${runContext.run_attempt}`,
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
  const cause =
    err instanceof Error && err.cause instanceof Error
      ? err.cause.stack || err.cause.message
      : err instanceof Error && err.cause
        ? String(err.cause)
        : "";
  console.error(`::error::Cursor Agent.prompt failed: ${message}`);
  console.error(stack);
  if (cause) {
    console.error(`Caused by: ${cause}`);
  }
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
  `Cursor advisory review: requested=${modelId} observed=${observedModel} fast_param=${fastParam ?? "unset"} billing_tier=${billingTier} status=${result?.status ?? "unknown"}`,
);

if (modelId === "composer-2.5" && billingTier === "composer-2.5-fast") {
  console.error(
    "::warning::Cursor SDK billed composer-2.5-fast despite fast=false; see https://forum.cursor.com/t/sdk-reports-composer-2-5-but-usage-dashboard-bills-composer-2-5-fast/163046",
  );
}

const text = result?.result ?? "";
if (!text.trim()) {
  console.error(`Cursor agent returned empty result (status=${result?.status ?? "unknown"})`);
  process.exit(1);
}

writeFileSync(outFile, text, "utf8");
