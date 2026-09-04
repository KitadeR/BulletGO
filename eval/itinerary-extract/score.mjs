#!/usr/bin/env node
/**
 * Offline scorer for itinerary extraction.
 * Live provider comparison requires API keys and is intentionally not run in CI.
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const cases = JSON.parse(readFileSync(join(root, "cases.json"), "utf8"));
const schema = JSON.parse(readFileSync(join(root, "schema.json"), "utf8"));

const report = {
  generatedAt: new Date().toISOString(),
  caseCount: cases.cases.length,
  schemaTitle: schema.title,
  lockedModel: "gpt-5.4-nano-2026-03-17",
  comparators: ["gemini-3.1-flash-lite", "ministral-3b-2512"],
  estimatedUSDPer1000: {
    "gpt-5.4-nano-2026-03-17": 0.475,
    "gemini-3.1-flash-lite": 0.575,
    "ministral-3b-2512": 0.08,
  },
  note: "Live bilingual scoring is deferred until provider keys exist. iOS tests cover the deterministic extractor and confirmation-before-save path.",
};

process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
