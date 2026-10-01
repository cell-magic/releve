#!/bin/sh
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
# Re-record the test pages. Needs Python, Playwright and Chromium.
# Run this only when the observer changes; then review the diff of tests/expected.
set -e
cd "$(dirname "$0")"
python3 -m http.server 8765 --directory pages >/dev/null 2>&1 & server=$!
trap 'kill $server' EXIT
sleep 1
for page in pages/*.html; do
  name=$(basename "$page" .html)
  python3 ../observe/observe.py "http://localhost:8765/$name.html" --contact https://example.org/robot > "observations/$name.jsonl"
done
