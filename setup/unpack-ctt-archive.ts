#!/usr/bin/env -S node --experimental-strip-types
/**
 * Extracts the CTT setup archive and places files in their Linux locations.
 *
 * setup/ctt-setup.zip is expected to contain:
 *   - ctt-bin/   -> ctt/bin/            (the ZWaveCTT apphost + DLLs)
 *
 * The harness generates CTT user settings inside each run directory.
 */
import { execFileSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.join(__dirname, "..");

const archiveFile = path.join(repoRoot, "setup", "ctt-setup.zip");
const cttBinDir = path.join(repoRoot, "ctt", "bin");

if (!fs.existsSync(archiveFile)) {
  console.error(`ERROR: Archive not found: ${archiveFile}`);
  process.exit(1);
}

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "ctt-archive-"));

try {
  console.log(`Extracting ${archiveFile}...`);
  execFileSync("unzip", ["-q", "-o", archiveFile, "-d", tempDir], {
    stdio: "inherit",
  });

  // ctt-bin/ -> ctt/bin/
  const sourceCttBin = path.join(tempDir, "ctt-bin");
  if (fs.existsSync(sourceCttBin)) {
    console.log(`Copying ctt-bin -> ${cttBinDir}`);
    fs.rmSync(cttBinDir, { recursive: true, force: true });
    fs.cpSync(sourceCttBin, cttBinDir, { recursive: true });
  } else {
    console.warn("WARNING: ctt-bin/ not found in archive");
  }

  // Make the ZWaveCTT apphost executable
  const apphost = path.join(cttBinDir, "ZWaveCTT");
  if (fs.existsSync(apphost)) {
    fs.chmodSync(apphost, 0o755);
  } else {
    console.warn(`WARNING: ZWaveCTT apphost not found at ${apphost}`);
  }
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}

console.log("CTT setup files extracted successfully!");
