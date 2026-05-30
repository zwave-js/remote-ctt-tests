#!/usr/bin/env -S node --experimental-strip-types
/**
 * Downloads the CTT setup archive from GitHub.
 *
 * Fetches the latest `ctt-setup.zip` release asset from the zwave-js/byoctt
 * repository into setup/ctt-setup.zip.
 *
 * Requires the `gh` CLI authenticated with access to byoctt
 * (GH_TOKEN / CTT_ARCHIVE_TOKEN in CI).
 */
import { execFileSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.join(__dirname, "..");

const REPO = "zwave-js/byoctt";
const OUTPUT_DIR = path.join(repoRoot, "setup");
const OUTPUT_FILE = path.join(OUTPUT_DIR, "ctt-setup.zip");

console.log("Downloading CTT setup archive...");

fs.rmSync(OUTPUT_FILE, { force: true });

console.log(`  Downloading from ${REPO}...`);
execFileSync(
  "gh",
  ["release", "download", "--repo", REPO, "--pattern", "ctt-setup.zip", "-D", OUTPUT_DIR],
  { stdio: "inherit" }
);

if (!fs.existsSync(OUTPUT_FILE)) {
  throw new Error(`Downloaded file not found at ${OUTPUT_FILE}`);
}

const fileSizeMb = fs.statSync(OUTPUT_FILE).size / 1024 / 1024;
console.log(`  Downloaded: ctt-setup.zip (${fileSizeMb.toFixed(1)} MB)`);
console.log("Done!");
