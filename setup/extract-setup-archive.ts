/**
 * Extracts the CTT setup archive on CI before running tests.
 *
 * This script extracts setup/setup.zip and places files in the correct locations:
 * - storage/ -> zwave_stack/storage/
 * - dut-storage/ -> DUT storage directory (from config.json)
 * - appdata/ -> %APPDATA%/Z-Wave Alliance/Z-Wave CTT 3/
 * - keys/ -> %USERPROFILE%/Documents/Z-Wave Alliance/Z-Wave CTT 3/Keys/
 *
 * It also updates ctt/project/Config/ZatsSettings.json to point to the correct keys directory.
 *
 * Usage: node --experimental-transform-types setup/extract-setup-archive.ts
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
	writeFileSync,
} from "node:fs";
import { tmpdir, homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import JSON5 from "json5";
import c from "ansi-colors";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const repoRoot = dirname(__dirname);
const archiveFile = join(repoRoot, "setup", "setup.zip");
const tempDir = join(tmpdir(), "ctt-setup-extract");

interface Config {
	dut: {
		storageDir: string;
	};
}

// Load config.json (supports JSON5 comments)
const configPath = join(repoRoot, "config.json");
const config: Config = JSON5.parse(readFileSync(configPath, "utf-8"));

// Destination paths
const zwaveStorage = join(repoRoot, "zwave_stack", "storage");
const dutStorageDir = join(repoRoot, config.dut.storageDir);
const dutStorageArchiveName = "dut-storage";
const cttAppData = join(
	process.env.APPDATA || join(homedir(), "AppData", "Roaming"),
	"Z-Wave Alliance",
	"Z-Wave CTT 3",
);
const cttKeys = join(
	process.env.USERPROFILE || homedir(),
	"Documents",
	"Z-Wave Alliance",
	"Z-Wave CTT 3",
	"Keys",
);

// CTT settings file
const zatsSettingsPath = join(
	repoRoot,
	"ctt",
	"project",
	"Config",
	"ZatsSettings.json",
);

console.log(c.cyan("Extracting CTT setup archive..."));
console.log();

if (!existsSync(archiveFile)) {
	console.log(c.red(`ERROR: Archive not found: ${archiveFile}`));
	process.exit(1);
}

// Clean up any existing temp directory
if (existsSync(tempDir)) {
	rmSync(tempDir, { recursive: true, force: true });
}

// Create temp directory
mkdirSync(tempDir, { recursive: true });

// Extract archive
console.log(c.green(`Extracting ${archiveFile}...`));
if (process.platform === "win32") {
	// Use Windows tar.exe which supports zip format
	execSync(`tar.exe --force-local -xf "${archiveFile}" -C "${tempDir}"`, {
		stdio: "inherit",
	});
} else {
	execSync(`unzip -q "${archiveFile}" -d "${tempDir}"`, { stdio: "inherit" });
}

// Copy storage -> zwave_stack/storage
const sourceStorage = join(tempDir, "storage");
if (existsSync(sourceStorage)) {
	console.log(c.green("Copying storage -> zwave_stack/storage/"));
	if (existsSync(zwaveStorage)) {
		rmSync(zwaveStorage, { recursive: true, force: true });
	}
	cpSync(sourceStorage, zwaveStorage, { recursive: true });
} else {
	console.log(c.yellow("WARNING: storage/ not found in archive"));
}

// Copy DUT storage files to storageDir
const sourceDutStorage = join(tempDir, dutStorageArchiveName);
if (existsSync(sourceDutStorage)) {
	console.log(c.green(`Copying ${dutStorageArchiveName} -> ${config.dut.storageDir}`));
	// Create destination directory if it doesn't exist
	if (!existsSync(dutStorageDir)) {
		mkdirSync(dutStorageDir, { recursive: true });
	}
	// Copy individual files (not the folder itself)
	for (const file of readdirSync(sourceDutStorage)) {
		console.log(c.green(`  Copying ${file}`));
		copyFileSync(join(sourceDutStorage, file), join(dutStorageDir, file));
	}
} else {
	console.log(c.yellow(`WARNING: ${dutStorageArchiveName}/ not found in archive`));
}

// Copy appdata -> CTT AppData location
const sourceAppData = join(tempDir, "appdata");
if (existsSync(sourceAppData)) {
	console.log(c.green(`Copying appdata -> ${cttAppData}`));
	// Create parent directories if needed
	const parentDir = dirname(cttAppData);
	if (!existsSync(parentDir)) {
		mkdirSync(parentDir, { recursive: true });
	}
	if (existsSync(cttAppData)) {
		rmSync(cttAppData, { recursive: true, force: true });
	}
	cpSync(sourceAppData, cttAppData, { recursive: true });
} else {
	console.log(c.yellow("WARNING: appdata/ not found in archive"));
}

// Copy keys -> CTT Keys location
const sourceKeys = join(tempDir, "keys");
if (existsSync(sourceKeys)) {
	console.log(c.green(`Copying keys -> ${cttKeys}`));
	// Create parent directories if needed
	const parentDir = dirname(cttKeys);
	if (!existsSync(parentDir)) {
		mkdirSync(parentDir, { recursive: true });
	}
	if (existsSync(cttKeys)) {
		rmSync(cttKeys, { recursive: true, force: true });
	}
	cpSync(sourceKeys, cttKeys, { recursive: true });
} else {
	console.log(c.yellow("WARNING: keys/ not found in archive"));
}

// Update ZatsSettings.json with correct KeysStoragePath
if (existsSync(zatsSettingsPath)) {
	console.log(c.green("Updating ZatsSettings.json with KeysStoragePath..."));
	const zatsSettings = JSON.parse(readFileSync(zatsSettingsPath, "utf-8"));
	zatsSettings.KeysStoragePath = cttKeys;
	writeFileSync(zatsSettingsPath, JSON.stringify(zatsSettings, null, 2), "utf-8");
	console.log(c.green(`  KeysStoragePath set to: ${cttKeys}`));
} else {
	console.log(c.yellow(`WARNING: ZatsSettings.json not found at ${zatsSettingsPath}`));
}

// Clean up temp directory
rmSync(tempDir, { recursive: true, force: true });

console.log();
console.log(c.green("Setup files extracted successfully!"));
console.log();
console.log(c.cyan("Extracted to:"));
console.log(c.white(`  - ${zwaveStorage}`));
console.log(c.white(`  - ${dutStorageDir}`));
console.log(c.white(`  - ${cttAppData}`));
console.log(c.white(`  - ${cttKeys}`));

// Debug: Print directory structures
console.log();
console.log(c.magenta("=== Debug: Directory Structures ==="));
console.log();

function listDirectory(dir: string, label: string) {
	console.log(c.yellow(`${label}:`));
	if (existsSync(dir)) {
		const listFiles = (d: string, prefix = "  ") => {
			for (const entry of readdirSync(d, { withFileTypes: true })) {
				const fullPath = join(d, entry.name);
				const relativePath = fullPath.replace(repoRoot, ".");
				console.log(c.gray(`${prefix}${relativePath}`));
				if (entry.isDirectory()) {
					listFiles(fullPath, prefix + "  ");
				}
			}
		};
		listFiles(dir);
	} else {
		console.log(c.red("  (directory not found)"));
	}
	console.log();
}

listDirectory(zwaveStorage, "zwave_stack/storage");
listDirectory(dutStorageDir, `DUT storage (${config.dut.storageDir})`);
