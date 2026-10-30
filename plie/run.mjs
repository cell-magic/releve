// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
// node plie/run.mjs COMPILED.js FUNCTION < input.json: the JavaScript fold of a plié function, called as
// `releve core FUNCTION` calls the Haskell one. tests/plie.py holds the two to the same bytes.
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";
import { call } from "./prelude/bridge.js";
const mod = await import(pathToFileURL(resolve(process.argv[2])).href);
process.stdout.write(call(mod, process.argv[3], readFileSync(0, "utf8")) + "\n");
