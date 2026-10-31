#!/bin/sh
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
# Fold record/*.plie into Haskell, Lean and JavaScript (record/gen/), and build the verifier
# page, record/verifier.html, from record/ui.html, the JavaScript fold and its prelude, and
# the BLS check compiled to WebAssembly (record/bls) with the notice of what is compiled in.
# CI checks that what is kept is what this gives.
set -e
cd "$(dirname "$0")/.."
src="record/Json.plie record/Merkle.plie record/Seed.plie record/Chain.plie record/Roots.plie record/Readings.plie record/Changes.plie record/Verify.plie"
rm -rf record/gen && mkdir -p record/gen/hs/Plie record/gen/lean/Plie
python3 plie/plie.py hs record/gen/hs/Plie $src
python3 plie/plie.py lean record/gen/lean/Plie $src
python3 plie/plie.py js record/gen/record.js ../../plie/prelude/plie.js $src
# The BLS check, compiled to WebAssembly by the toolchain record/bls pins, its paths mapped so
# that the bytes do not depend on where it is built; and the notice of the crates inside it.
( cd record/bls && RUSTFLAGS="--remap-path-prefix=$HOME/.cargo=/cargo --remap-path-prefix=$(pwd)=/src -C target-cpu=mvp" \
    cargo build --release --locked --lib --target wasm32-unknown-unknown --quiet && python3 notice.py > NOTICE )
if [ -f record/ui.html ]; then python3 - <<'PY'
import base64, re
strip = lambda s: re.sub(r'^import .*$\n', '', re.sub(r'^export (const|function)', r'\1', s, flags=re.M), flags=re.M)
sha = open('receipt/verify.js').read()
sha = sha[sha.index('// ---------- SHA-256'):sha.index('const enc = new TextEncoder();')]
parts = [strip(sha).replace('function sha256', 'function digest'), strip(open('plie/prelude/plie.js').read()),
         strip(open('plie/prelude/bridge.js').read()), strip(open('record/gen/record.js').read())]
wasm = open('record/bls/target/wasm32-unknown-unknown/release/releve_bls.wasm', 'rb').read()
notice = open('record/bls/NOTICE', encoding='utf-8').read().replace('-->', '- ->')
page = open('record/ui.html').read().replace('/*__RECORD_JS__*/', '\n'.join(parts)).replace('__BLS_WASM__', base64.b64encode(wasm).decode('ascii'))
page = page.replace('<!--__BLS_NOTICE__-->', '<!--\n' + notice + '\n-->')
# the compiled crates are named among the page's licences, as REUSE reads them
tag = 'SPDX-' 'License-Identifier: '  # split, so that REUSE does not read it as this file's own
page = page.replace('<!-- ' + tag + 'EUPL-1.2 -->', '<!-- ' + tag + 'EUPL-1.2 -->\n'
                    '<!-- SPDX-FileCopyrightText: the authors of the Rust crates named in the notice below, compiled in -->\n'
                    '<!-- ' + tag + 'MIT AND BSD-3-Clause -->', 1)
open('record/verifier.html', 'w', newline='\n').write(page)
PY
fi
