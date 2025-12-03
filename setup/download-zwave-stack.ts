import { execSync } from "node:child_process";
import { copyFileSync, mkdtempSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const REPO = "Z-Wave-Alliance/z-wave-stack-binaries";
const OUTPUT_DIR = "zwave_stack/bin";

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

const tempDir = mkdtempSync(join(tmpdir(), "zwave-stack-"));

try {
	console.log("Downloading latest Z-Wave stack binaries...");
	execSync(
		`gh release download --repo ${REPO} --pattern "*Linux.tar.gz" -D "${tempDir}"`,
		{ stdio: "inherit" },
	);

	const tarball = readdirSync(tempDir).find((f) => f.endsWith(".tar.gz"));
	if (!tarball) {
		throw new Error("No tarball found in downloaded files");
	}

	console.log(`Extracting ${tarball}...`);
	execSync(`tar --force-local -xzf "${join(tempDir, tarball)}" -C "${tempDir}"`, {
		stdio: "inherit",
	});

	const binDir = join(tempDir, "bin");
	const files = readdirSync(binDir);

	for (const { pattern, output } of BINARIES) {
		const match = files.find((f) => pattern.test(f));
		if (!match) {
			throw new Error(`No file matching ${pattern} found`);
		}

		const src = join(binDir, match);
		const dest = join(OUTPUT_DIR, output);
		console.log(`Copying ${match} -> ${output}`);
		copyFileSync(src, dest);
	}

	console.log("Done!");
} finally {
	rmSync(tempDir, { recursive: true, force: true });
}
