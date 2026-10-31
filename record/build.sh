#!/bin/sh
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
# Fold record/*.plie into Haskell, Lean and JavaScript (record/gen/), and build the verifier
# page, record/verifier.html, from record/ui.html, the JavaScript fold and its prelude.
# CI checks that what is kept is what this gives.
set -e
cd "$(dirname "$0")/.."
src="record/Json.plie record/Merkle.plie record/Seed.plie record/Chain.plie record/Roots.plie record/Readings.plie record/Changes.plie record/Verify.plie"
rm -rf record/gen && mkdir -p record/gen/hs/Plie record/gen/lean/Plie
python3 plie/plie.py hs record/gen/hs/Plie $src
python3 plie/plie.py lean record/gen/lean/Plie $src
python3 plie/plie.py js record/gen/record.js ../../plie/prelude/plie.js $src
if [ -f record/ui.html ]; then python3 - <<'PY'
import re
strip = lambda s: re.sub(r'^import .*$\n', '', re.sub(r'^export (const|function)', r'\1', s, flags=re.M), flags=re.M)
sha = open('receipt/verify.js').read()
sha = sha[sha.index('// ---------- SHA-256'):sha.index('const enc = new TextEncoder();')]
parts = [strip(sha).replace('function sha256', 'function digest'), strip(open('plie/prelude/plie.js').read()),
         strip(open('plie/prelude/bridge.js').read()), strip(open('record/gen/record.js').read())]
page = open('record/ui.html').read().replace('/*__RECORD_JS__*/', '\n'.join(parts))
open('record/verifier.html', 'w', newline='\n').write(page)
PY
fi
