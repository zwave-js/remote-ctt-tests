#!/usr/bin/env -S node --experimental-strip-types
/**
 * Creates setup/network-state.zip with the Z-Wave network state for CI.
 *
 * Packages:
 *   - zwave_stack/storage/                      -> storage/
 *   - DUT storage files (config.json globs)     -> dut-storage/
 *
 * Maintainer tool: run after capturing a good network state locally.
 */
import { execFileSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { fileURLToPath } from "url";
import JSON5 from "json5";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.join(__dirname, "..");

interface Config {
  dut: { homeId: string; storageDir: string; storageFileFilter: string[] };
}
const config = JSON5.parse(
  fs.readFileSync(path.join(repoRoot, "config.json"), "utf-8")
) as Config;

const homeIdLower = config.dut.homeId.toLowerCase();
const homeIdUpper = config.dut.homeId.toUpperCase();
const dutStorageDir = path.join(repoRoot, config.dut.storageDir);
const zwaveStorage = path.join(repoRoot, "zwave_stack", "storage");
const outputFile = path.join(repoRoot, "setup", "network-state.zip");

// Convert a glob with `*` wildcards into an anchored RegExp.
function globToRegExp(glob: string): RegExp {
  const escaped = glob.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*");
  return new RegExp(`^${escaped}$`);
}

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "network-state-staging-"));

try {
  console.log("Creating network state archive...");

  // Stage zwave_stack/storage
  if (fs.existsSync(zwaveStorage)) {
    console.log("  Staging zwave_stack/storage...");
    fs.cpSync(zwaveStorage, path.join(tempDir, "storage"), { recursive: true });
  } else {
    console.warn(`  WARNING: zwave_stack/storage not found at ${zwaveStorage}`);
  }

  // Stage DUT storage files matching the configured globs
  const dutStaging = path.join(tempDir, "dut-storage");
  fs.mkdirSync(dutStaging, { recursive: true });

  if (fs.existsSync(dutStorageDir)) {
    console.log("  Staging DUT storage files...");
    const patterns = config.dut.storageFileFilter.map((p) =>
      globToRegExp(
        p.replace(/%HOME_ID_LOWER%/g, homeIdLower).replace(/%HOME_ID_UPPER%/g, homeIdUpper)
      )
    );
    for (const file of fs.readdirSync(dutStorageDir)) {
      if (patterns.some((re) => re.test(file))) {
        console.log(`    ${file}`);
        fs.copyFileSync(
          path.join(dutStorageDir, file),
          path.join(dutStaging, file)
        );
      }
    }
  } else {
    console.warn(`  WARNING: DUT storage directory not found at ${dutStorageDir}`);
  }

  // (Re)create the zip from the staging dir contents
  fs.rmSync(outputFile, { force: true });
  console.log("  Compressing archive...");
  execFileSync("zip", ["-r", "-q", outputFile, "storage", "dut-storage"], {
    cwd: tempDir,
    stdio: "inherit",
  });
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}

console.log(`Created ${outputFile}`);
