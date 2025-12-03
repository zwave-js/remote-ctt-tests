/**
 * Creates a setup archive containing all files needed for CTT tests on CI.
 *
 * This script packages the following into setup/setup.zip:
 * - zwave_stack/storage/ -> storage/
 * - DUT storage files (from config.json glob patterns) -> dut-storage/
 * - CTT AppData folder -> appdata/
 * - CTT Keys file (homeId-specific) -> keys/
 *
 * Usage: node --experimental-transform-types setup/create-setup-archive.ts
 */

import { execSync } from "node:child_process";
import {
	copyFileSync,
	cpSync,
	existsSync,
	mkdirSync,
	readdirSync,
	readFileSync,
	rmSync,
	unlinkSync,
} from "node:fs";
import { tmpdir, homedir } from "node:os";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import JSON5 from "json5";
import c from "ansi-colors";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const repoRoot = dirname(__dirname);
const tempDir = join(tmpdir(), "ctt-setup-staging");
const outputFile = join(repoRoot, "setup", "setup.zip");

interface Config {
	dut: {
		homeId: string;
		storageDir: string;
		storageFileFilter: string[];
	};
}

// Load config.json (supports JSON5 comments)
const configPath = join(repoRoot, "config.json");
const config: Config = JSON5.parse(readFileSync(configPath, "utf-8"));

// DUT configuration
const homeId = config.dut.homeId;
const homeIdLower = homeId.toLowerCase();
const homeIdUpper = homeId.toUpperCase();
const dutStorageDir = join(repoRoot, config.dut.storageDir);
const dutStorageArchiveName = "dut-storage";

// Source paths
const zwaveStorage = join(repoRoot, "zwave_stack", "storage");
const username = process.env.USERNAME || basename(homedir());
const cttAppData = join(
	"C:",
	"Users",
	username,
	"AppData",
	"Roaming",
	"Z-Wave Alliance",
	"Z-Wave CTT 3",
);
const cttKeys = join(
	"C:",
	"Users",
	username,
	"Documents",
	"Z-Wave Alliance",
	"Z-Wave CTT 3",
	"Keys",
);

console.log(c.cyan("Creating setup archive..."));

// Clean up any existing temp directory
if (existsSync(tempDir)) {
	rmSync(tempDir, { recursive: true, force: true });
}

// Create staging directory
mkdirSync(tempDir, { recursive: true });

// Copy zwave_stack/storage
if (existsSync(zwaveStorage)) {
	cpSync(zwaveStorage, join(tempDir, "storage"), { recursive: true });
}

// Copy DUT storage files using glob patterns from config
const dutStagingDir = join(tempDir, dutStorageArchiveName);
mkdirSync(dutStagingDir, { recursive: true });

if (existsSync(dutStorageDir)) {
	for (const pattern of config.dut.storageFileFilter) {
		// Replace placeholders
		const resolvedPattern = pattern
			.replace(/%HOME_ID_LOWER%/g, homeIdLower)
			.replace(/%HOME_ID_UPPER%/g, homeIdUpper);

		// Simple glob matching - for now just match files in the directory
		const files = readdirSync(dutStorageDir);
		const regex = new RegExp(
			"^" +
				resolvedPattern
					.replace(/\./g, "\\.")
					.replace(/\*/g, ".*")
					.replace(/\?/g, ".") +
				"$",
		);

		for (const file of files) {
			if (regex.test(file)) {
				copyFileSync(
					join(dutStorageDir, file),
					join(dutStagingDir, file),
				);
			}
		}
	}
}

// Copy CTT AppData
if (existsSync(cttAppData)) {
	cpSync(cttAppData, join(tempDir, "appdata"), { recursive: true });
}

// Copy CTT Keys - only the homeId-specific key file
const keysStagingDir = join(tempDir, "keys");
mkdirSync(keysStagingDir, { recursive: true });

if (existsSync(cttKeys)) {
	const keyFile = join(cttKeys, `${homeIdUpper}.txt`);
	if (existsSync(keyFile)) {
		copyFileSync(keyFile, join(keysStagingDir, `${homeIdUpper}.txt`));
	}
}

// Remove old archive if it exists
if (existsSync(outputFile)) {
	unlinkSync(outputFile);
}

// Create the zip archive
const archiveContents = readdirSync(tempDir).join(" ");
if (process.platform === "win32") {
	// Use Windows tar.exe which supports -a for zip format
	execSync(
		`tar.exe --force-local -a -cf "${outputFile}" -C "${tempDir}" ${archiveContents}`,
		{ stdio: "inherit" },
	);
} else {
	execSync(`cd "${tempDir}" && zip -r "${outputFile}" .`, {
		stdio: "inherit",
		shell: "/bin/bash",
	});
}

// Clean up temp directory
rmSync(tempDir, { recursive: true, force: true });

console.log(c.green(`Created ${outputFile}`));
