# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""A record checked against its JSON Schema (record/schema/record-2.schema.json), by the
keywords that schema uses and no others: type, const, enum, pattern, minimum, required,
properties, additionalProperties, items, oneOf. A keyword it does not know is refused,
so that the schema cannot say more than is checked."""
import json, re
from pathlib import Path

SCHEMA = json.loads((Path(__file__).with_name("schema") / "record-2.schema.json").read_text(encoding="utf-8"))
KNOWN = {"$schema", "$id", "$comment", "title", "type", "const", "enum", "pattern", "minimum", "required", "properties",
         "additionalProperties", "items", "oneOf"}
TYPES = {"object": dict, "array": list, "string": str, "boolean": bool, "null": type(None)}


def problems(value, schema=SCHEMA, where="record"):
    """What in a value the schema does not admit, as a list of sentences; empty if all holds."""
    unknown = set(schema) - KNOWN
    if unknown:
        raise ValueError(f"the schema uses {sorted(unknown)}, which this validator does not check")
    out = []
    t = schema.get("type")
    if t == "integer":
        if not (isinstance(value, int) and not isinstance(value, bool)):
            return [f"{where} is not an integer"]
    elif t and not isinstance(value, TYPES[t]) or (t in ("object", "array", "string") and isinstance(value, bool)):
        return [f"{where} is not of type {t}"]
    if "const" in schema and value != schema["const"]:
        out.append(f"{where} is not {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        out.append(f"{where} is none of {schema['enum']}")
    if "pattern" in schema and isinstance(value, str) and not re.search(schema["pattern"], value):
        out.append(f"{where} does not match {schema['pattern']}")
    if "minimum" in schema and isinstance(value, int) and value < schema["minimum"]:
        out.append(f"{where} is below {schema['minimum']}")
    if isinstance(value, dict):
        out += [f"{where}.{k} is missing" for k in schema.get("required", []) if k not in value]
        props = schema.get("properties", {})
        for k, v in value.items():
            if k in props:
                out += problems(v, props[k], f"{where}.{k}")
            elif schema.get("additionalProperties") is False:
                out.append(f"{where}.{k} is not allowed")
    if isinstance(value, list) and "items" in schema:
        for i, v in enumerate(value):
            out += problems(v, schema["items"], f"{where}[{i}]")
    if "oneOf" in schema:
        fits = [s for s in schema["oneOf"] if not problems(value, s, where)]
        if len(fits) != 1:
            out.append(f"{where} fits {len(fits)} of the forms it may take, not one")
    return out
