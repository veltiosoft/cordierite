#!/usr/bin/env node
/**
 * Regenerate favicon PNG/ICO/SVG assets.
 * Run from site/: node scripts/generate-favicons.mjs
 */
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const siteDir = join(__dirname, "..");

const py = spawnSync("python3", [join(__dirname, "build-favicons.py"), siteDir], {
  encoding: "utf8",
});
if (py.status !== 0) {
  console.error(py.stderr || py.stdout);
  process.exit(py.status ?? 1);
}
console.log(py.stdout.trim());
