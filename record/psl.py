# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The public suffix list as the dependency reading takes it: the pinned file's rules, each
also in its ASCII form (IDNA), since a browser names hosts in that form; and its version."""
import re
from pathlib import Path

FILE = Path(__file__).with_name("data") / "public_suffix_list.dat"


def ascii_rule(rule):
    lead = "!" if rule.startswith("!") else "*." if rule.startswith("*.") else ""
    try:
        return lead + ".".join(l.encode("idna").decode("ascii") for l in rule[len(lead):].split("."))
    except UnicodeError:
        return None


def load():
    text = FILE.read_text(encoding="utf-8")
    version = re.search(r"^// VERSION: (\S+)", text, re.M).group(1)
    commit = re.search(r"^// COMMIT: (\S+)", text, re.M).group(1)
    rules = []
    for line in text.splitlines():
        r = line.strip().lower()
        if r and not r.startswith("//"):
            rules.append(r)
            a = ascii_rule(r)
            if a and a != r:
                rules.append(a)
    return {"version": f"{version} {commit[:7]}", "rules": rules}
