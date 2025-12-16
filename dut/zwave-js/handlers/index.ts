/**
 * Handler Index
 *
 * Dynamically imports all handler files from tests and behaviors directories.
 * Side-effect imports cause the handlers to self-register.
 */

import { readdirSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const directories = ["tests", "behaviors"];

for (const dir of directories) {
	const dirPath = join(__dirname, dir);
	const files = readdirSync(dirPath).filter((file) => file.endsWith(".ts"));

	for (const file of files) {
		await import(`./${dir}/${file}`);
	}
}
