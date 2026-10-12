#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""counts — the service's weekly counts, as a table to read or to pass on.

    counts FILE [en|fr]

Only the weeks that have ended; a region counted fewer than five times in a
week is shown as such, not by its number. Read where the counts are kept: no
page of the service shows them.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from serve import Tally, WORDS  # noqa: E402


def table(path, lang="en"):
    w, weeks = WORDS[lang], Tally(path).shown()
    if not weeks:
        return w["none"]
    regions = [r for r in w["regions"] if any(r in v["regions"] for v in weeks.values())]
    head = w["columns"] + [w["regions"][r] for r in regions]
    cell = lambda n: w["few"] if isinstance(n, str) else str(n)
    rows = [[k, str(v["reports"]), str(v["following"]), str(v["languages"].get("en", 0)), str(v["languages"].get("fr", 0))]
            + [cell(v["regions"].get(r, 0)) for r in regions] for k, v in weeks.items()]
    return "\n".join([w["counts"], "", w["countsit"], "", "| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
                     + ["| " + " | ".join(r) + " |" for r in rows])


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3) or sys.argv[2:] not in ([], ["en"], ["fr"]):
        sys.exit(__doc__.strip().splitlines()[2].strip())
    print(table(sys.argv[1], (sys.argv[2:] or ["en"])[0]))
