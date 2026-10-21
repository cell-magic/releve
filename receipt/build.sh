#!/bin/sh
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
# Rebuild verifier.html, one offline file, from verify.js and ui.html.
cd "$(dirname "$0")" && python3 - <<'PY'
import re
js = re.sub(r'^export (const|function)', r'\1', open('verify.js').read(), flags=re.M)
open('verifier.html', 'w', newline='\n').write(open('ui.html').read().replace('/*__VERIFY_JS__*/', js))
PY
