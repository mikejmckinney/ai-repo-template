#!/usr/bin/env node
/**
 * Generate advisory review body via Cursor SDK (Composer 2.5).
 * Requires: npm install @cursor/sdk (workflow step), CURSOR_API_KEY.
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

const result = await Agent.prompt(prompt, {
  apiKey,
  model: { id: modelId },
  local: { cwd: process.cwd() },
});

const observedModel = result?.model?.id ?? "unknown";
console.error(
  `Cursor advisory review: requested=${modelId} observed=${observedModel} status=${result?.status ?? "unknown"}`,
);

const text = result?.result ?? "";
if (!text.trim()) {
  console.error(`Cursor agent returned empty result (status=${result?.status ?? "unknown"})`);
  process.exit(1);
}

writeFileSync(outFile, text, "utf8");
