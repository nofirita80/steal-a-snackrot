// Steal a Snackrot: the entrypoint for make.fun's roblox-brainrot-01 bounty.
// It hands the game in. It copies the built place (game.rbxl), the Luau
// sources, the screenshots and the play link from beside this file into
// the output directory, then writes dossier.json there with the vendored
// make.fun library. Run it as the grader does:
//
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
//
// Outside the grader's container MAKEFUN_OUTPUT_DIR stands in for
// /output; when it is unset the program writes to /output.

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

const here = fileURLToPath(new URL(".", import.meta.url));
const outDir = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

// Leave out every file or directory whose name starts with a dot, at any
// depth: a stray .gitkeep or .DS_Store under /output fails the entry.
const keepVisible = (path: string): boolean => !basename(path).startsWith(".");

// Every input the dossier is built from must exist before anything is
// copied: a missing place file or play link is a broken entry, and it is
// far better to fail here with the name of the missing file than to hand
// in a half-empty output directory.
const requiredInputs = ["game.rbxl", "PLAY.json"];
for (const name of requiredInputs) {
	if (!existsSync(join(here, name))) {
		throw new Error(`Steal a Snackrot: missing required input ${name} beside main.ts - build the place with Rojo first.`);
	}
}
for (const dir of ["src", "screenshots"]) {
	if (!existsSync(join(here, dir))) {
		throw new Error(`Steal a Snackrot: missing required directory ${dir}/ beside main.ts.`);
	}
}

// Make sure the output directory exists before anything is copied:
// the grader creates it, but a missing directory must not turn into
// a confusing copy failure here.
mkdirSync(outDir, { recursive: true });

copyFileSync(join(here, "game.rbxl"), join(outDir, "game.rbxl"));
copyFileSync(join(here, "PLAY.json"), join(outDir, "PLAY.json"));
cpSync(join(here, "src"), join(outDir, "src"), { recursive: true, filter: keepVisible });
mkdirSync(join(outDir, "screenshots"), { recursive: true });
if (existsSync(join(here, "screenshots"))) {
	cpSync(join(here, "screenshots"), join(outDir, "screenshots"), { recursive: true, filter: keepVisible });
}

// The dossier caps the gate itself enforces: the text is capped at 64 KiB,
// at most 4 screenshots of at most 256 KiB each, at most 500,000 place
// instances, and scripts of at most 8 MiB of source with at most
// 1,048,576 path characters in all.
const dossierPath = join(outDir, "dossier.json");
writeFileSync(
	dossierPath,
	buildDossier(outDir, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	}),
);

// Say what was handed in, and prove the dossier actually landed: a
// zero-byte dossier would pass silently here and fail at the gate.
const dossierSize = statSync(dossierPath).size;
if (dossierSize === 0) {
	throw new Error("Steal a Snackrot: dossier.json was written empty - nothing was handed in.");
}
const shotCount = readdirSync(join(outDir, "screenshots")).filter((name) => !name.startsWith(".")).length;
console.log(`Steal a Snackrot: copied game.rbxl, PLAY.json, src/ and ${shotCount} screenshots to ${outDir}.`);
console.log(`Steal a Snackrot: dossier.json written (${dossierSize} bytes).`);
