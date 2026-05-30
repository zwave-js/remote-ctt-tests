#!/usr/bin/env -S node --experimental-strip-types
/**
 * Downloads the latest Z-Wave stack binaries from GitHub.
 *
 * Fetches the latest *Linux.tar.gz release asset from
 * Z-Wave-Alliance/z-wave-stack-binaries and extracts the required ELF
 * binaries into zwave_stack/bin/.
 *
 * Requires the `gh` CLI authenticated (GH_TOKEN / ZW_STACK_TOKEN in CI).
 */
import { execFileSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.join(__dirname, "..");

const REPO = "Z-Wave-Alliance/z-wave-stack-binaries";
const OUTPUT_DIR = path.join(repoRoot, "zwave_stack", "bin");

const BINARIES = [
  {
    pattern: /^ZW_zwave_ncp_serial_api_controller_.*_REALTIME_DEBUG\.elf$/,
    output: "ZW_zwave_ncp_serial_api_controller.elf",
  },
  {
    pattern: /^ZW_zwave_ncp_serial_api_end_device_.*_REALTIME_DEBUG\.elf$/,
    output: "ZW_zwave_ncp_serial_api_end_device.elf",
  },
];

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "zwave-stack-"));

try {
  console.log("Downloading latest Z-Wave stack binaries...");
  execFileSync(
    "gh",
    ["release", "download", "--repo", REPO, "--pattern", "*Linux.tar.gz", "-D", tempDir],
    { stdio: "inherit" }
  );

  const tarball = fs
    .readdirSync(tempDir)
    .find((f) => f.endsWith(".tar.gz"));
  if (!tarball) throw new Error("No tarball found in downloaded files");

  console.log(`Extracting ${tarball}...`);
  execFileSync("tar", ["-xzf", tarball], { cwd: tempDir, stdio: "inherit" });

  const binDir = path.join(tempDir, "bin");
  const files = fs.readdirSync(binDir);

  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  for (const binary of BINARIES) {
    const match = files.find((f) => binary.pattern.test(f));
    if (!match) throw new Error(`No file matching ${binary.pattern} found`);

    const dest = path.join(OUTPUT_DIR, binary.output);
    console.log(`Copying ${match} -> ${binary.output}`);
    fs.copyFileSync(path.join(binDir, match), dest);
    fs.chmodSync(dest, 0o755);
  }

  console.log("Done!");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
