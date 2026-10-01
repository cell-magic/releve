#!/bin/sh
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
# The kernel's checks. No browser, no network: recorded observations in,
# reports compared byte for byte with the expected ones.
#   tests/run.sh            check
#   tests/run.sh --accept   rewrite the expected reports after a deliberate change
set -e
cd "$(dirname "$0")"
releve=${RELEVE:-releve}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok    $1"; }
bad() { echo "FAIL  $1"; fail=1; }

for obs in observations/*.jsonl; do
  name=$(basename "$obs" .jsonl)
  "$releve" ingest "$tmp/$name" < "$obs" > /dev/null
  "$releve" facts "$tmp/$name" > "$tmp/$name.md"
  if [ "$1" = "--accept" ]; then cp "$tmp/$name.md" "expected/$name.md"; fi
  if cmp -s "$tmp/$name.md" "expected/$name.md"; then ok "report $name"
  else bad "report $name"; diff "expected/$name.md" "$tmp/$name.md" | head -20; fi

  # An untouched report records nothing, however often it is fed back.
  n=$("$releve" correct "$tmp/$name" < "$tmp/$name.md" 2>&1)
  [ "$n" = "0 corrections recorded" ] && ok "untouched $name" || bad "untouched $name: $n"
done

# A correction is recorded once, shown with the machine's verdict, and survives replay.
c=$tmp/fixture
sed 's/^- \*\*REVIEW\*\* main-region\(.*\) {\(.*\)}$/- **PASS** main-region\1 \/\/ layout uses a single article {\2}/' "$c.md" > "$tmp/edit.md"
[ "$("$releve" correct "$c" < "$tmp/edit.md" 2>&1)" = "1 correction recorded" ] && ok "correction recorded" || bad "correction recorded"
[ "$("$releve" correct "$c" < "$tmp/edit.md" 2>&1)" = "0 corrections recorded" ] && ok "correction idempotent" || bad "correction idempotent"
"$releve" facts "$c" | grep -q '^- \*\*PASS\*\* main-region.*machine said REVIEW // layout uses a single article' \
  && ok "correction shown" || bad "correction shown"

# One combined document for several pages: each section corrects its own page.
m=$tmp/multi
cat observations/fixture.jsonl observations/edge.jsonl | "$releve" ingest "$m" > /dev/null
"$releve" facts "$m" --all > "$tmp/all.md"
[ "$(grep -c '^Observation `' "$tmp/all.md")" = 2 ] && ok "combined report" || bad "combined report"
sed -e 's/^- \*\*REVIEW\*\* main-region\(.*\)$/- **FAIL** main-region\1/' \
    -e 's/^- \*\*REVIEW\*\* text-contrast\(.*Half faded.*\)$/- **PASS** text-contrast\1/' "$tmp/all.md" > "$tmp/all-edit.md"
[ "$("$releve" correct "$m" < "$tmp/all-edit.md" 2>&1)" = "2 corrections recorded" ] && ok "combined corrections" || bad "combined corrections"

# Seals: intact, tampered, and with Windows line endings.
"$releve" verify "$c" > /dev/null && ok "seal intact" || bad "seal intact"
sed '1s/Relev/Relev_/' "$c" > "$tmp/tampered"
"$releve" verify "$tmp/tampered" > /dev/null 2>&1 && bad "seal tamper" || ok "seal tamper detected"
sed 's/$/\r/' "$c" > "$tmp/crlf"
"$releve" verify "$tmp/crlf" > /dev/null && ok "seal CRLF" || bad "seal CRLF"

exit $fail
