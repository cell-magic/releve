#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""plié — a small pure language, written once and folded three ways: into Haskell, which
runs it; into Lean 4, which proves things of it; into JavaScript, which runs it in a browser.

    python plie/plie.py hs   OUT_DIR FILE.plie ...   one Haskell module per file (Plie.<Module>)
    python plie/plie.py lean OUT_DIR FILE.plie ...   one Lean 4 file per file (Plie/<Module>.lean)
    python plie/plie.py js   OUT_FILE PRELUDE FILE.plie ...  one JavaScript module for all of them, importing
                                                    the prelude from PRELUDE (a path as the module names it)

The language is the common ground of Haskell and Lean, and no more (plie/README.md):
data types, typed top-level definitions, application, lambda, let, if, case over
constructors, literals and lists. Integers are unbounded; there are no floats. Types are
written as Lean writes them (`x : Int`, `x :: xs`). What a name means is fixed by the
prelude, the same in each language (plie/prelude/). Nothing reads or writes the world:
a program is a function, and the same input gives the same output, in every fold.
"""
import re, sys
from pathlib import Path

KEYWORDS = {"module", "where", "import", "data", "sealed", "case", "of", "if", "then", "else", "let", "in"}
# Names no definition may take: each is a keyword, or a builtin, in one of the three folds.
RESERVED = set("""abbrev at attribute axiom break by calc catch class const continue def default delete deriving do
end example export extends false finally for from fun function have instance inductive infix infixl infixr instanceof
let local macro match mutual namespace new noncomputable null opaque open partial private protected return section
set_option show static structure suffices super switch syntax then theorem this throw true try typeof universe unless
var variable void while with yield type forall exists qualified as hiding newtype family pattern proc rec mdo
""".split())
SYMBOLS = ["::", "->", "==", "/=", "<=", ">=", "&&", "||", "++", "\\", "=", ":", "|", "(", ")", "[", "]", ",",
           "+", "-", "*", "<", ">", "_"]
# What the prelude defines, in each fold under the same name (plie/prelude/).
PRELUDE = set("""div mod abs min max not showInt readInt length map filter foldl reverse take drop sum all any elem
concat range zip nth sortBy fromMaybe fst snd textLength utf8 split startsWith endsWith asciiLower joinText trim
jsonQuote ltUtf16 sha256 byte be64 hex unhex bytesLength""".split())
PREC = {"||": (2, "r"), "&&": (3, "r"), "==": (4, "n"), "/=": (4, "n"), "<": (4, "n"), "<=": (4, "n"),
        ">": (4, "n"), ">=": (4, "n"), "::": (5, "r"), "++": (5, "r"), "+": (6, "l"), "-": (6, "l"), "*": (7, "l")}


class Fault(Exception):
    pass


# ---- lexing ---------------------------------------------------------------------------

def lex(src, name):
    toks, i, line, col = [], 0, 1, 1
    while i < len(src):
        c = src[i]
        if c == "\n":
            i, line, col = i + 1, line + 1, 1
            continue
        if c in " \t\r":
            i, col = i + 1, col + 1
            continue
        if src.startswith("--", i):
            while i < len(src) and src[i] != "\n":
                i += 1
            continue
        start = (line, col)
        m = re.match(r"[0-9]+", src[i:])
        if m:
            toks.append(("int", int(m.group()), start))
            n = len(m.group())
        elif c == '"':
            j, out = i + 1, []
            while src[j] != '"':
                if src[j] == "\n":
                    raise Fault(f"{name}:{line}:{col}: a text does not cross a line")
                if src[j] == "\\":
                    e = src[j + 1]
                    if e == "u":
                        out.append(chr(int(src[j + 2:j + 6], 16)))
                        j += 6
                        continue
                    out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}[e])
                    j += 2
                    continue
                out.append(src[j])
                j += 1
            toks.append(("text", "".join(out), start))
            n = j + 1 - i
        elif re.match(r"[A-Za-z]", c):
            m = re.match(r"[A-Za-z][A-Za-z0-9_']*", src[i:])
            w = m.group()
            kind = "kw" if w in KEYWORDS else "con" if w[0].isupper() else "var"
            toks.append((kind, w, start))
            n = len(w)
        else:
            s = next((s for s in SYMBOLS if src.startswith(s, i)), None)
            if s is None:
                raise Fault(f"{name}:{line}:{col}: unexpected {c!r}")
            toks.append(("sym", s, start))
            n = len(s)
        i, col = i + n, col + n
    toks.append(("eof", None, (line + 1, 1)))
    return toks


# ---- parsing --------------------------------------------------------------------------
# Types:       ("tcon", name, [args]) | ("tvar", name) | ("fn", a, b)
# Patterns:    ("pvar", n) | ("pany",) | ("pint", k) | ("ptext", s) | ("pnil",) | ("pcons", h, t) | ("pcon", C, [p])
# Expressions: ("var", n) | ("con", C) | ("int", k) | ("text", s) | ("app", f, [a]) | ("lam", [x], e)
#              ("let", x, e, body) | ("if", c, a, b) | ("case", e, [(p, e)]) | ("list", [e]) | ("op", o, a, b)

class Parser:
    def __init__(self, toks, name):
        self.t, self.i, self.name = toks, 0, name

    def peek(self, k=0):
        return self.t[self.i + k]

    def at(self, kind, val=None, k=0):
        t = self.peek(k)
        return t[0] == kind and (val is None or t[1] == val)

    def eat(self, kind, val=None):
        t = self.peek()
        if not self.at(kind, val):
            want = val if val is not None else kind
            raise Fault(f"{self.name}:{t[2][0]}:{t[2][1]}: expected {want}, found {t[1] if t[1] is not None else 'the end'}")
        self.i += 1
        return t

    def top(self):
        return self.peek()[2][1] == 1

    # A module: its name, what it imports, its data types, signatures and definitions.
    def module(self):
        self.eat("kw", "module")
        mod = self.eat("con")[1]
        self.eat("kw", "where")
        imports, datas, sigs, defs, sealed = [], [], {}, [], set()
        while not self.at("eof"):
            if not self.top():
                t = self.peek()
                raise Fault(f"{self.name}:{t[2][0]}:{t[2][1]}: a declaration starts in the first column")
            if self.at("kw", "import"):
                self.eat("kw")
                imports.append(self.eat("con")[1])
            elif self.at("kw", "data"):
                datas.append(self.data())
            elif self.at("kw", "sealed"):
                self.eat("kw")
                datas.append(self.data())
                sealed.add(datas[-1][0])
            elif self.at("var") and self.at("sym", ":", 1):
                n = self.eat("var")[1]
                self.eat("sym", ":")
                sigs[n] = self.type_()
            else:
                defs.append(self.definition())
        for n, _, _ in defs:
            if n not in sigs:
                raise Fault(f"{self.name}: {n} has no signature")
            if n in RESERVED or n in PRELUDE:
                raise Fault(f"{self.name}: {n} is a reserved or prelude name; choose another")
        return {"module": mod, "imports": imports, "datas": datas, "sigs": sigs, "defs": defs, "sealed": sealed}

    def data(self):
        self.eat("kw", "data")
        name = self.eat("con")[1]
        params = []
        while self.at("var"):
            params.append(self.eat("var")[1])
        self.eat("sym", "=")
        cons = [self.constructor()]
        while self.at("sym", "|") and not self.top():
            self.eat("sym")
            cons.append(self.constructor())
        return (name, params, cons)

    def constructor(self):
        c = self.eat("con")[1]
        fields = []
        while not self.top() and (self.at("con") or self.at("var") or self.at("sym", "(")):
            fields.append(self.atype())
        return (c, fields)

    def type_(self):
        a = self.btype()
        if self.at("sym", "->"):
            self.eat("sym")
            return ("fn", a, self.type_())
        return a

    def btype(self):
        if self.at("con"):
            c = self.eat("con")[1]
            args = []
            while not self.top() and (self.at("con") or self.at("var") or self.at("sym", "(")):
                args.append(self.atype())
            return ("tcon", c, args)
        return self.atype()

    def atype(self):
        if self.at("sym", "("):
            self.eat("sym")
            t = self.type_()
            self.eat("sym", ")")
            return t
        if self.at("con"):
            return ("tcon", self.eat("con")[1], [])
        return ("tvar", self.eat("var")[1])

    def definition(self):
        n = self.eat("var")[1]
        params = []
        while self.at("var"):
            params.append(self.eat("var")[1])
        self.eat("sym", "=")
        return (n, params, self.expr())

    def expr(self):
        if self.at("sym", "\\"):
            self.eat("sym")
            xs = [self.eat("var")[1]]
            while self.at("var"):
                xs.append(self.eat("var")[1])
            self.eat("sym", "->")
            return ("lam", xs, self.expr())
        if self.at("kw", "let"):
            self.eat("kw")
            x = self.eat("var")[1]
            self.eat("sym", "=")
            e = self.expr()
            self.eat("kw", "in")
            return ("let", x, e, self.expr())
        if self.at("kw", "if"):
            self.eat("kw")
            c = self.expr()
            self.eat("kw", "then")
            a = self.expr()
            self.eat("kw", "else")
            return ("if", c, a, self.expr())
        if self.at("kw", "case"):
            self.eat("kw")
            e = self.expr()
            self.eat("kw", "of")
            col = self.peek()[2][1]
            alts = []
            while self.at("sym", "|") and self.peek()[2][1] == col:
                self.eat("sym")
                p = self.pattern()
                self.eat("sym", "->")
                alts.append((p, self.expr()))
            if not alts:
                raise Fault(f"{self.name}:{self.peek()[2][0]}: a case has no alternative")
            return ("case", e, alts)
        return self.binary(0)

    def binary(self, least):
        a = self.application()
        while self.at("sym") and self.peek()[1] in PREC and PREC[self.peek()[1]][0] >= least and not self.top():
            op = self.eat("sym")[1]
            p, assoc = PREC[op]
            b = self.binary(p + 1 if assoc in "ln" else p)
            a = ("op", op, a, b)
            if assoc == "n" and self.at("sym") and self.peek()[1] in PREC and PREC[self.peek()[1]][0] == p:
                raise Fault(f"{self.name}:{self.peek()[2][0]}: {op} does not chain; use parentheses")
        return a

    def starts_atom(self):
        return not self.top() and (self.at("var") or self.at("con") or self.at("int") or self.at("text")
                                   or self.at("sym", "(") or self.at("sym", "["))

    def application(self):
        f = self.atom()
        args = []
        while self.starts_atom():
            args.append(self.atom())
        return ("app", f, args) if args else f

    def atom(self):
        t = self.peek()
        if t[0] == "var":
            self.i += 1
            return ("var", t[1])
        if t[0] == "con":
            self.i += 1
            return ("con", t[1])
        if t[0] in ("int", "text"):
            self.i += 1
            return (t[0], t[1])
        if self.at("sym", "("):
            self.eat("sym")
            e = self.expr()
            self.eat("sym", ")")
            return e
        if self.at("sym", "["):
            self.eat("sym")
            items = []
            if not self.at("sym", "]"):
                items.append(self.expr())
                while self.at("sym", ","):
                    self.eat("sym")
                    items.append(self.expr())
            self.eat("sym", "]")
            return ("list", items)
        raise Fault(f"{self.name}:{t[2][0]}:{t[2][1]}: unexpected {t[1]}")

    def pattern(self):
        p = self.apattern(True)
        if self.at("sym", "::"):
            self.eat("sym")
            return ("pcons", p, self.pattern())
        return p

    def apattern(self, head=False):
        t = self.peek()
        if self.at("sym", "_"):
            self.i += 1
            return ("pany",)
        if t[0] == "var":
            self.i += 1
            return ("pvar", t[1])
        if t[0] == "int":
            self.i += 1
            return ("pint", t[1])
        if t[0] == "text":
            self.i += 1
            return ("ptext", t[1])
        if self.at("sym", "["):
            self.eat("sym")
            self.eat("sym", "]")
            return ("pnil",)
        if self.at("sym", "("):
            self.eat("sym")
            p = self.pattern()
            self.eat("sym", ")")
            return p
        if t[0] == "con":
            self.i += 1
            args = []
            while head and not self.at("sym", "->") and not self.at("sym", "::") and (
                    self.at("var") or self.at("con") or self.at("sym", "_") or self.at("sym", "(") or self.at("int")
                    or self.at("text") or self.at("sym", "[")):
                args.append(self.apattern())
            return ("pcon", t[1], args)
        raise Fault(f"{self.name}:{t[2][0]}:{t[2][1]}: not a pattern: {t[1]}")


def parse(path):
    src = Path(path).read_text(encoding="utf-8")
    m = Parser(lex(src, str(path)), str(path)).module()
    # the source's licence goes with every fold of it
    m["spdx"] = [l[2:].strip() for l in src.splitlines()[:6] if l.startswith("-- SPDX-")]
    return m


# ---- the prelude's names, in each fold --------------------------------------------------
# Types and constructors the prelude defines; everything else it defines is a function of
# the same name in every fold (plie/prelude/Plie/Prelude.hs, Plie/Prelude.lean, plie.js).
TYPES = {"Int": ("Integer", "Int"), "Bool": ("Bool", "Bool"), "Text": ("Text", "String"),
         "Bytes": ("ByteString", "Bytes"), "List": (None, "List"), "Maybe": ("Maybe", "Option"),
         "Pair": ("Pair", "Pair")}
CONS = {"True": ("True", "true", "true"), "False": ("False", "false", "false"),
        "Nothing": ("Nothing", "none", None), "Just": ("Just", "some", None)}


def every_con(mods):
    out = {}
    for m in mods:
        for name, _, cons in m["datas"]:
            for c, fields in cons:
                out[c] = len(fields)
    out.update({"Nothing": 0, "Just": 1, "Pair": 2, "True": 0, "False": 0})
    return out


# ---- Haskell -----------------------------------------------------------------------------

def hs_type(t, top=True):
    if t[0] == "tvar":
        return t[1]
    if t[0] == "fn":
        s = f"{hs_type(t[1], False) if t[1][0] != 'fn' else '(' + hs_type(t[1]) + ')'} -> {hs_type(t[2])}"
        return s if top else f"({s})"
    name, args = t[1], t[2]
    if name == "List":
        return f"[{hs_type(args[0])}]"
    base = TYPES.get(name, (name,))[0]
    s = " ".join([base] + [hs_type(a, False) for a in args])
    return f"({s})" if args and not top else s


def hs_pat(p):
    k = p[0]
    if k == "pvar":
        return p[1]
    if k == "pany":
        return "_"
    if k == "pint":
        return str(p[1])
    if k == "ptext":
        return hs_text(p[1])
    if k == "pnil":
        return "[]"
    if k == "pcons":
        return f"({hs_pat(p[1])} : {hs_pat(p[2])})"
    return "(" + " ".join([CONS.get(p[1], (p[1],))[0]] + [hs_pat(a) for a in p[2]]) + ")"


def hs_text(s):
    out = ['"']
    for ch in s:
        out.append({'"': '\\"', "\\": "\\\\", "\n": "\\n", "\t": "\\t"}.get(ch) or (ch if 32 <= ord(ch) < 127 else f"\\{ord(ch)}\\&"))
    return "".join(out) + '"'


HS_OPS = {"++": "<>", "::": ":", "/=": "/="}


def hs_expr(e):
    k = e[0]
    if k == "var":
        return e[1]
    if k == "con":
        return CONS.get(e[1], (e[1],))[0]
    if k == "int":
        return f"({e[1]} :: Integer)"
    if k == "text":
        return f"(T.pack {hs_text(e[1])})"
    if k == "app":
        return "(" + " ".join(hs_expr(x) for x in [e[1]] + e[2]) + ")"
    if k == "lam":
        return f"(\\{' '.join(e[1])} -> {hs_expr(e[2])})"
    if k == "let":
        return f"(let {e[1]} = {hs_expr(e[2])} in {hs_expr(e[3])})"
    if k == "if":
        return f"(if {hs_expr(e[1])} then {hs_expr(e[2])} else {hs_expr(e[3])})"
    if k == "case":
        alts = "; ".join(f"{hs_pat(p)} -> {hs_expr(b)}" for p, b in e[2])
        return f"(case {hs_expr(e[1])} of {{ {alts} }})"
    if k == "list":
        return "[" + ", ".join(hs_expr(x) for x in e[1]) + "]"
    if k == "op":
        return f"({hs_expr(e[2])} {HS_OPS.get(e[1], e[1])} {hs_expr(e[3])})"
    raise Fault(f"no Haskell for {k}")


def hs_exports(m):
    """Every definition and type; a sealed type without its constructors, so that GHC too keeps them home."""
    types = [name if name in m["sealed"] else f"{name}(..)" for name, _, _ in m["datas"]]
    return ", ".join(types + [n for n, _, _ in m["defs"]])


def to_hs(m):
    out = [f"-- {x}" for x in m["spdx"]] + ["-- Written by plie/plie.py from " + m["module"] + ".plie. Do not edit: edit the source.",
           "{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}",
           "{-# OPTIONS_GHC -Wno-unused-matches -Wno-name-shadowing -Wno-unused-imports -Wno-incomplete-patterns -Wno-overlapping-patterns #-}",
           f"module Plie.{m['module']} ({hs_exports(m)}) where", "", "import Plie.Prelude", "import Prelude (Show)", "import qualified Data.Text as T"]
    out += [f"import Plie.{i}" for i in m["imports"]]
    out.append("")
    for name, params, cons in m["datas"]:
        alts = " | ".join(" ".join([c] + [hs_type(f, False) for f in fs]) for c, fs in cons)
        out.append(f"data {' '.join([name] + params)} = {alts} deriving (Eq, Show)")
    for n, params, body in m["defs"]:
        tv = sorted(type_vars(m["sigs"][n]))
        ctx = ("(" + ", ".join(f"Eq {v}" for v in tv) + ") => ") if tv else ""
        out.append(f"{n} :: {ctx}{hs_type(m['sigs'][n])}")
        out.append(f"{' '.join([n] + params)} = {hs_expr(body)}")
        out.append("")
    return "\n".join(out) + "\n"


def is_entry(t):
    """A function from Json to Json: what the world may call."""
    return t == ("fn", ("tcon", "Json", []), ("tcon", "Json", []))


def to_hs_entries(mods):
    entries = [(m["module"], n) for m in mods for n, params, _ in m["defs"] if is_entry(m["sigs"][n])]
    out = [f"-- {x}" for x in mods[0]["spdx"]] + ["-- Written by plie/plie.py. Do not edit: edit the sources.",
           "module Plie.Entries (entries) where", "", "import qualified Data.Text as T", "import Plie.Json (Json)"]
    out += sorted({f"import qualified Plie.{mod}" for mod, _ in entries})
    out += ["", "-- | Every function from Json to Json, by name: what the world may call.",
            "entries :: [(T.Text, Json -> Json)]",
            "entries = [" + ", ".join(f'(T.pack "{n}", Plie.{mod}.{n})' for mod, n in entries) + "]"]
    return "\n".join(out) + "\n"


# ---- Lean 4 ------------------------------------------------------------------------------

def lean_type(t, top=True):
    if t[0] == "tvar":
        return t[1]
    if t[0] == "fn":
        s = f"{lean_type(t[1], False)} → {lean_type(t[2])}"
        return s if top else f"({s})"
    name, args = t[1], t[2]
    base = TYPES.get(name, (None, name))[1]
    s = " ".join([base] + [lean_type(a, False) for a in args])
    return f"({s})" if args and not top else s


def fn_parts(t, k):
    """The first k argument types of a function type, and what remains."""
    args = []
    while k:
        if t[0] != "fn":
            raise Fault("more parameters than the signature gives")
        args.append(t[1])
        t, k = t[2], k - 1
    return args, t


def lean_pat(p):
    k = p[0]
    if k == "pvar":
        return p[1]
    if k == "pany":
        return "_"
    if k == "pint":
        return str(p[1])
    if k == "ptext":
        return lean_text(p[1])
    if k == "pnil":
        return "[]"
    if k == "pcons":
        return f"({lean_pat(p[1])} :: {lean_pat(p[2])})"
    c = CONS.get(p[1], (None, "." + p[1]))[1]
    return "(" + " ".join([c] + [lean_pat(a) for a in p[2]]) + ")" if p[2] else c


def pat_vars(p):
    if p[0] == "pvar":
        return {p[1]}
    if p[0] == "pcons":
        return pat_vars(p[1]) | pat_vars(p[2])
    if p[0] == "pcon":
        return set().union(*[pat_vars(a) for a in p[2]])
    return set()


def lean_text(s):
    out = ['"']
    for ch in s:
        out.append({'"': '\\"', "\\": "\\\\", "\n": "\\n", "\t": "\\t"}.get(ch) or (ch if 32 <= ord(ch) < 127 else f"\\u{{{ord(ch):x}}}"))
    return "".join(out) + '"'


LEAN_OPS = {"/=": "!=", "==": "==", "&&": "&&", "||": "||"}
LEAN_ORDER = {"<": "lt", "<=": "le", ">": "gt", ">=": "ge"}


def lean_expr(e, owners, local=frozenset()):
    k = e[0]
    if k == "var":
        n = e[1]
        return n if n in local else f"Plie.Prelude.{n}" if n in PRELUDE else f"Plie.{n}"
    if k == "con":
        c = CONS.get(e[1])
        return c[1] if c else f"{owners[e[1]]}.{e[1]}"
    if k == "int":
        return f"({e[1]} : Int)"
    if k == "text":
        return lean_text(e[1])
    if k == "app":
        return "(" + " ".join(lean_expr(x, owners, local) for x in [e[1]] + e[2]) + ")"
    if k == "lam":
        return f"(fun {' '.join(e[1])} => {lean_expr(e[2], owners, local | set(e[1]))})"
    if k == "let":
        return f"(let {e[1]} := {lean_expr(e[2], owners, local)}; {lean_expr(e[3], owners, local | {e[1]})})"
    if k == "if":
        return f"(if {lean_expr(e[1], owners, local)} then {lean_expr(e[2], owners, local)} else {lean_expr(e[3], owners, local)})"
    if k == "case":
        alts = " ".join(f"| {lean_pat(p)} => {lean_expr(b, owners, local | pat_vars(p))}" for p, b in e[2])
        return f"(match {lean_expr(e[1], owners, local)} with {alts})"
    if k == "list":
        return "[" + ", ".join(lean_expr(x, owners, local) for x in e[1]) + "]"
    if k == "op":
        a, b = lean_expr(e[2], owners, local), lean_expr(e[3], owners, local)
        if e[1] in LEAN_ORDER:
            return f"(Plie.Prelude.{LEAN_ORDER[e[1]]} {a} {b})"
        return f"({a} {LEAN_OPS.get(e[1], e[1])} {b})"
    raise Fault(f"no Lean for {k}")


def to_lean(m, owners):
    out = [f"-- {x}" for x in m["spdx"]] + ["-- Written by plie/plie.py from " + m["module"] + ".plie. Do not edit: edit the source.",
           "import Plie.Prelude"] + [f"import Plie.{i}" for i in m["imports"]]
    out += ["", "namespace Plie", "open Plie.Prelude", ""]
    for name, params, cons in m["datas"]:
        ps = " ".join(f"({p} : Type)" for p in params)
        if name in m["sealed"]:
            out.append(f"-- sealed: its constructor is used in {m['module']} alone (plié checks it, GHC's export list too)")
        out.append(f"inductive {name}{' ' + ps if ps else ''} where")
        for c, fs in cons:
            out.append(f"  | {c} : " + " → ".join([lean_type(f, False) for f in fs] + [" ".join([name] + params)]))
        out.append("  deriving Repr, BEq, Inhabited")
        out.append("")
    groups = components(m)
    for group in groups:
        if len(group) > 1:
            out.append("mutual")
        for n, params, body in group:
            out += lean_def(m, n, params, body, owners, recursive=len(group) > 1)
        if len(group) > 1:
            out += ["end", ""]
    out.append("end Plie")
    return "\n".join(out) + "\n"


def components(m):
    """The definitions in an order Lean accepts: each after what it uses, mutually recursive ones together
    (Tarjan's strongly connected components, which come out dependencies first)."""
    defs = {n: (n, p, b) for n, p, b in m["defs"]}
    uses = {n: [x[1] for x in walk(b) if x[0] == "var" and x[1] in defs and x[1] not in p] for n, p, b in m["defs"]}
    index, low, stack, on, out, k = {}, {}, [], set(), [], [0]
    def visit(v):
        index[v] = low[v] = k[0]; k[0] += 1
        stack.append(v); on.add(v)
        for w in uses[v]:
            if w not in index:
                visit(w)
                low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            group = []
            while True:
                w = stack.pop(); on.discard(w); group.append(defs[w])
                if w == v:
                    break
            out.append(sorted(group, key=lambda d: list(defs).index(d[0])))
    for n in defs:
        if n not in index:
            visit(n)
    return out


def lean_def(m, n, params, body, owners, recursive=False):
    args, res = fn_parts(m["sigs"][n], len(params))
    binders = " ".join(f"({p} : {lean_type(t)})" for p, t in zip(params, args))
    tvars = sorted(tv for tv in type_vars(m["sigs"][n]))
    implicit = " ".join("{" + v + " : Type} [BEq " + v + "] [Inhabited " + v + "] [Plie.Prelude.Order " + v + "]" for v in tvars)
    head = " ".join(x for x in (n, implicit, binders) if x)
    # a definition that is not structurally recursive is said so to Lean, which then proves nothing of it
    word = "partial def" if recursive or n in recursive_names(m) - structural_names(m) else "def"
    return [f"{word} {head} : {lean_type(res)} :=", f"  {lean_expr(body, owners, frozenset(params))}", ""]


def type_vars(t):
    if t[0] == "tvar":
        return {t[1]}
    if t[0] == "fn":
        return type_vars(t[1]) | type_vars(t[2])
    return set().union(*[type_vars(x) for x in t[2]])


def children(e):
    """The expressions directly inside an expression."""
    k = e[0]
    if k == "app":
        return [e[1]] + e[2]
    if k == "lam":
        return [e[2]]
    if k == "let":
        return [e[2], e[3]]
    if k == "if":
        return [e[1], e[2], e[3]]
    if k == "case":
        return [e[1]] + [b for _, b in e[2]]
    if k == "list":
        return e[1]
    if k == "op":
        return [e[2], e[3]]
    return []


def walk(e):
    yield e
    for c in children(e):
        yield from walk(c)


def recursive_names(m):
    return {n for n, _, b in m["defs"] if ("var", n) in walk(b)}


def structural_names(m):
    """Recursive definitions where every self-call passes, in the position of a parameter, the tail a cons
    pattern bound when matching on that same parameter: Lean sees by structure that these end."""
    out = set()
    for n, params, body in m["defs"]:
        if ("var", n) not in walk(body):
            continue
        def tail_vars(p):  # the variables a cons pattern binds below its head, at any depth: a :: b :: rest
            while p[0] == "pcons":
                p = p[2]
                if p[0] == "pvar":
                    yield p[1]
        tails = {v: params.index(x[1][1]) for x in walk(body) if x[0] == "case" and x[1][0] == "var" and x[1][1] in params
                 for p, _ in x[2] for v in tail_vars(p)}
        selfcalls = [x for x in walk(body) if x[0] == "app" and x[1] == ("var", n)]
        bare = sum(1 for x in walk(body) if x == ("var", n)) != len(selfcalls)
        if tails and not bare and all(any(a[0] == "var" and tails.get(a[1]) == i for i, a in enumerate(x[2])) for x in selfcalls):
            out.add(n)
    return out


# ---- JavaScript --------------------------------------------------------------------------
# Int is BigInt; Text a string; Bytes a Uint8Array; a list an array; Bool a boolean; any other
# value of a data type {t: constructor, f: [fields]}. Functions are curried.

def js_name(n):
    return "$" + n.replace("'", "_")


def js_text(s):
    import json
    return json.dumps(s, ensure_ascii=True)


def js_test(p, v, binds):
    """The condition that value expression v matches pattern p, binding names into binds."""
    k = p[0]
    if k == "pvar":
        binds.append((p[1], v))
        return []
    if k == "pany":
        return []
    if k == "pint":
        return [f"{v} === {p[1]}n"]
    if k == "ptext":
        return [f"{v} === {js_text(p[1])}"]
    if k == "pnil":
        return [f"{v}.length === 0"]
    if k == "pcons":
        return [f"{v}.length > 0"] + js_test(p[1], f"{v}[0]", binds) + js_test(p[2], f"{v}.slice(1)", binds)
    if p[1] in ("True", "False"):
        return [f"{v} === {'true' if p[1] == 'True' else 'false'}"]
    out = [f"{v}.t === {js_text(p[1])}"]
    for i, a in enumerate(p[2]):
        out += js_test(a, f"{v}.f[{i}]", binds)
    return out


JS_OPS = {"+": "$add", "-": "$sub", "*": "$mul", "==": "$eq", "/=": "$ne", "<": "$lt", "<=": "$le", ">": "$gt",
          ">=": "$ge", "++": "$append", "::": "$cons"}


def js_expr(e, cx, local=frozenset()):
    """cx: (constructor arities, names of constants). A constant is a thunk, computed once when first asked for."""
    arity, consts = cx
    k = e[0]
    if k == "var":
        return js_name(e[1]) + ("()" if e[1] in consts and e[1] not in local else "")
    if k == "con":
        if e[1] in ("True", "False"):
            return "true" if e[1] == "True" else "false"
        n = arity[e[1]]
        if n == 0:
            return f"{{t: {js_text(e[1])}, f: []}}"
        xs = [f"x{i}" for i in range(n)]
        return "(" + "".join(f"{x} => " for x in xs) + f"({{t: {js_text(e[1])}, f: [{', '.join(xs)}]}}))"
    if k == "int":
        return f"{e[1]}n"
    if k == "text":
        return js_text(e[1])
    if k == "app":
        return js_expr(e[1], cx, local) + "".join(f"({js_expr(a, cx, local)})" for a in e[2])
    if k == "lam":
        inner = local | set(e[1])
        return "(" + "".join(f"{js_name(x)} => " for x in e[1]) + js_expr(e[2], cx, inner) + ")"
    if k == "let":
        return f"(({js_name(e[1])}) => {js_expr(e[3], cx, local | {e[1]})})({js_expr(e[2], cx, local)})"
    if k == "if":
        return f"({js_expr(e[1], cx, local)} ? {js_expr(e[2], cx, local)} : {js_expr(e[3], cx, local)})"
    if k == "case":
        parts = []
        for p, b in e[2]:
            binds = []
            conds = js_test(p, "s", binds)
            inner = local | {n for n, _ in binds}
            bound = "".join(f"const {js_name(n)} = {v}; " for n, v in binds)
            parts.append(f"if ({' && '.join(conds) or 'true'}) {{ {bound}return {js_expr(b, cx, inner)}; }}")
        return "((s) => { " + " ".join(parts) + ' throw new Error("plié: no alternative matches"); })(' + js_expr(e[1], cx, local) + ")"
    if k == "list":
        return "[" + ", ".join(js_expr(x, cx, local) for x in e[1]) + "]"
    if k == "op":
        if e[1] in ("&&", "||"):
            return f"({js_expr(e[2], cx, local)} {e[1]} {js_expr(e[3], cx, local)})"
        return f"{JS_OPS[e[1]]}({js_expr(e[2], cx, local)})({js_expr(e[3], cx, local)})"
    raise Fault(f"no JavaScript for {k}")


def to_js(mods, prelude):
    consts = {n for m in mods for n, params, _ in m["defs"] if not params}
    cx = (every_con(mods), consts)
    used = sorted({"$" + n for n in PRELUDE} | set(JS_OPS.values()))
    out = [f"// {x}" for x in mods[0]["spdx"]] + ["// Written by plie/plie.py. Do not edit: edit the sources.",
           f"import {{ {', '.join(used)} }} from {js_text(prelude)};"]
    for m in mods:
        out.append(f"// ---- {m['module']}")
        for n, params, body in m["defs"]:
            if params:
                out.append(f"export const {js_name(n)} = " + "".join(f"{js_name(p)} => " for p in params)
                           + js_expr(body, cx, frozenset(params)) + ";")
            else:
                out.append(f"export const {js_name(n)} = (() => {{ let v; return () => v === undefined ? (v = {js_expr(body, cx)}) : v; }})();")
    entries = [n for m in mods for n, params, _ in m["defs"] if is_entry(m["sigs"][n])]
    out.append("export const entries = {" + ", ".join(f"{js_text(n)}: {js_name(n)}" for n in entries) + "};")
    return "\n".join(out) + "\n"


# ---- the whole -------------------------------------------------------------------------------

def pattern_cons(p):
    if p[0] == "pcon":
        return {p[1]}.union(*[pattern_cons(a) for a in p[2]])
    if p[0] == "pcons":
        return pattern_cons(p[1]) | pattern_cons(p[2])
    return set()


def used_cons(body):
    """The constructors a definition builds or takes apart."""
    out = {x[1] for x in walk(body) if x[0] == "con"}
    for x in walk(body):
        if x[0] == "case":
            for p, _ in x[2]:
                out |= pattern_cons(p)
    return out


def seal(mods):
    """A sealed type's constructors are used in its own module alone: elsewhere its values are held and
    passed, and made or opened only through the functions of the module that declares it."""
    home = {c: (m["module"], name) for m in mods for name, _, cons in m["datas"] if name in m["sealed"] for c, _ in cons}
    for m in mods:
        for n, _, body in m["defs"]:
            for c in sorted(used_cons(body)):
                if c in home and home[c][0] != m["module"]:
                    raise Fault(f"{m['module']}.{n} uses the constructor {c} of {home[c][1]}, sealed in {home[c][0]}; "
                                f"only {home[c][0]}'s own functions may make or open it")


def load(paths):
    mods = [parse(p) for p in paths]
    seal(mods)
    names = {}
    for m in mods:
        for n, _, _ in m["defs"]:
            if n in names:
                raise Fault(f"{n} is defined in {names[n]} and in {m['module']}: one name, one meaning")
            names[n] = m["module"]
    return mods


def main(a):
    if len(a) < 3 or a[0] not in ("hs", "lean", "js"):
        print(__doc__)
        return 2
    files = a[3:] if a[0] == "js" else a[2:]
    try:
        mods = load(files)
    except Fault as f:
        print(f"plié: {f}", file=sys.stderr)
        return 1
    if a[0] == "js":
        Path(a[1]).write_text(to_js(mods, a[2]), encoding="utf-8", newline="\n")
        return 0
    out = Path(a[1])
    owners = {"Pair": "Pair", **{c: name for m in mods for name, _, cons in m["datas"] for c, _ in cons}}
    for m in mods:
        if a[0] == "hs":
            (out / f"{m['module']}.hs").write_text(to_hs(m), encoding="utf-8", newline="\n")
        else:
            (out / f"{m['module']}.lean").write_text(to_lean(m, owners), encoding="utf-8", newline="\n")
    if a[0] == "hs" and any(m["module"] == "Json" for m in mods):
        (out / "Entries.hs").write_text(to_hs_entries(mods), encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
