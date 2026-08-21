#!/usr/bin/env -S node --experimental-strip-types
/**
 * Extracts the network state archive before running tests.
 *
 * setup/network-state.zip contains:
 *   - storage/      -> zwave_stack/storage/
 *   - dut-storage/  -> config.dut.storageDir (individual files)
 */
import { execFileSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { fileURLToPath } from "url";
import JSON5 from "json5";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.join(__dirname, "..");

const archiveFile = path.join(repoRoot, "setup", "network-state.zip");

interface Config {
  dut: { storageDir: string };
}
const config = JSON5.parse(
  fs.readFileSync(path.join(repoRoot, "config.json"), "utf-8")
) as Config;

const zwaveStorage = path.join(repoRoot, "zwave_stack", "storage");
const dutStorageDir = path.join(repoRoot, config.dut.storageDir);

if (!fs.existsSync(archiveFile)) {
  console.error(`ERROR: Archive not found: ${archiveFile}`);
  process.exit(1);
}

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "network-state-"));

try {
  console.log(`Extracting ${archiveFile}...`);
  execFileSync("unzip", ["-q", "-o", archiveFile, "-d", tempDir], {
    stdio: "inherit",
  });

  // storage/ -> zwave_stack/storage/
  const sourceStorage = path.join(tempDir, "storage");
  if (fs.existsSync(sourceStorage)) {
    console.log("Copying storage -> zwave_stack/storage/");
    fs.rmSync(zwaveStorage, { recursive: true, force: true });
    fs.cpSync(sourceStorage, zwaveStorage, { recursive: true });
  } else {
    console.warn("WARNING: storage/ not found in archive");
  }

  // dut-storage/ -> config.dut.storageDir (copy individual files)
  const sourceDutStorage = path.join(tempDir, "dut-storage");
  if (fs.existsSync(sourceDutStorage)) {
    console.log(`Copying dut-storage -> ${config.dut.storageDir}`);
    fs.mkdirSync(dutStorageDir, { recursive: true });
    for (const file of fs.readdirSync(sourceDutStorage)) {
      console.log(`  Copying ${file}`);
      fs.copyFileSync(
        path.join(sourceDutStorage, file),
        path.join(dutStorageDir, file)
      );
    }
  } else {
    console.warn("WARNING: dut-storage/ not found in archive");
  }
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}

console.log("Network state files extracted successfully!");
console.log(`  - ${zwaveStorage}`);
console.log(`  - ${dutStorageDir}`);
