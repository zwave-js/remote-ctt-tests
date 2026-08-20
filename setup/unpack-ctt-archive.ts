#!/usr/bin/env -S node --experimental-strip-types
/**
 * Extracts the CTT setup archive and places files in their Linux locations.
 *
 * setup/ctt-setup.zip is expected to contain:
 *   - ctt-bin/   -> ctt/bin/            (the ZWaveCTT apphost + DLLs)
 *   - appdata/   -> ~/.ctt4/            (optional; CTT 4 settings seed)
 *
 * Keys are committed in the repo at ctt/keys/. This script points both
 * ~/.ctt4/settings.json (KeyStorageFolder) and
 * ctt/project/Config/ZatsSettings.json (KeysStoragePath) at that directory.
 */
import { execFileSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { fileURLToPath } from "url";
import JSON5 from "json5";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.join(__dirname, "..");

const archiveFile = path.join(repoRoot, "setup", "ctt-setup.zip");
const cttBinDir = path.join(repoRoot, "ctt", "bin");
const keysDir = path.join(repoRoot, "ctt", "keys");
const cttSettingsDir = path.join(os.homedir(), ".ctt4");
const cttSettingsFile = path.join(cttSettingsDir, "settings.json");
const zatsSettingsPath = path.join(
  repoRoot,
  "ctt",
  "project",
  "Config",
  "ZatsSettings.json"
);

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

  // appdata/ -> ~/.ctt4/ (optional seed)
  const sourceAppData = path.join(tempDir, "appdata");
  fs.mkdirSync(cttSettingsDir, { recursive: true });
  if (fs.existsSync(sourceAppData)) {
    console.log(`Copying appdata -> ${cttSettingsDir}`);
    fs.cpSync(sourceAppData, cttSettingsDir, { recursive: true });
  }
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}

let cttSettings: Record<string, unknown> = {};
if (fs.existsSync(cttSettingsFile)) {
  try {
    cttSettings = JSON5.parse(fs.readFileSync(cttSettingsFile, "utf-8"));
  } catch {
    cttSettings = {};
  }
}
cttSettings.KeyStorageFolder = keysDir;
// ZATS requires a Commander path even when every device is virtual.
if (!cttSettings.SimplicityCommanderPath) {
  cttSettings.SimplicityCommanderPath = "/usr/bin/true";
}
fs.writeFileSync(cttSettingsFile, JSON.stringify(cttSettings, null, 2));
console.log(`Wrote ${cttSettingsFile} (KeyStorageFolder=${keysDir})`);

// Rewrite ZatsSettings.json KeysStoragePath to match.
if (fs.existsSync(zatsSettingsPath)) {
  const zats = JSON5.parse(fs.readFileSync(zatsSettingsPath, "utf-8"));
  zats.KeysStoragePath = keysDir;
  fs.writeFileSync(zatsSettingsPath, JSON.stringify(zats, null, 2));
  console.log(`Updated ZatsSettings.json KeysStoragePath -> ${keysDir}`);
} else {
  console.warn(`WARNING: ZatsSettings.json not found at ${zatsSettingsPath}`);
}

console.log("CTT setup files extracted successfully!");
