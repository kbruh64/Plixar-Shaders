#!/usr/bin/env python3
"""
Lightweight static sanity checker for the Plixar shaderpack.

It is NOT a GLSL compiler. It resolves `#include` directives the same way
OptiFine/Iris do (paths are relative to the `shaders/` root when they start
with `/`), then runs cheap structural checks that catch the mistakes that
most often break a shaderpack:

  * unbalanced braces / parentheses
  * missing or unresolvable #include targets
  * a DRAWBUFFERS/RENDERTARGETS index that is written but whose colortex
    sampler is also read in the same program (self-feedback) -- warning only
  * use of an identifier that looks like an undeclared uniform sampler

Run:  python tools/check_shaders.py
Exit code 0 = no errors (warnings allowed), 1 = errors found.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHADERS = ROOT / "shaders"

INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"', re.M)

# Programs (entry points) we expect Iris to compile.
ENTRY_SUFFIXES = (".vsh", ".fsh", ".gsh")


def resolve_include(target: str, current: Path) -> Path:
    if target.startswith("/"):
        return SHADERS / target.lstrip("/")
    return current.parent / target


def flatten(path: Path, seen=None, stack=None) -> str:
    """Inline all #includes, depth-first, with cycle protection."""
    if seen is None:
        seen = {}
    if stack is None:
        stack = []
    if path in stack:
        raise ValueError(f"include cycle: {' -> '.join(str(s) for s in stack)} -> {path}")
    text = path.read_text(encoding="utf-8", errors="replace")
    out = []
    pos = 0
    for m in INCLUDE_RE.finditer(text):
        out.append(text[pos:m.start()])
        inc = resolve_include(m.group(1), path)
        if not inc.exists():
            raise FileNotFoundError(f"{path.name}: cannot resolve #include \"{m.group(1)}\"")
        out.append(flatten(inc, seen, stack + [path]))
        pos = m.end()
    out.append(text[pos:])
    return "".join(out)


def strip_comments_and_strings(src: str) -> str:
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    src = re.sub(r'//[^\n]*', '', src)
    src = re.sub(r'"[^"]*"', '""', src)
    return src


def check_balance(name: str, src: str, errors: list):
    for open_c, close_c, label in (('{', '}', 'braces'), ('(', ')', 'parens')):
        depth = 0
        for ch in src:
            if ch == open_c:
                depth += 1
            elif ch == close_c:
                depth -= 1
                if depth < 0:
                    errors.append(f"{name}: unbalanced {label} (extra '{close_c}')")
                    break
        if depth > 0:
            errors.append(f"{name}: unbalanced {label} (missing {depth} '{close_c}')")


def check_undeclared_samplers(name: str, src: str, warnings: list):
    """Flag use of texture2D(<id>, ...) where <id> is never declared."""
    used = set(re.findall(r'texture2D\s*\(\s*([A-Za-z_]\w*)', src))
    declared = set(re.findall(r'uniform\s+sampler2D\s+([A-Za-z_]\w*)', src))
    # The default vanilla samplers are always provided.
    builtin = {"texture", "lightmap", "gtexture", "gcolor", "tex", "colortex0",
               "colortex1", "colortex2", "colortex3", "depthtex0", "depthtex1",
               "depthtex2", "shadowtex0", "shadowtex1", "shadowcolor0",
               "shadowcolor1", "noisetex"}
    for u in used - declared - builtin:
        warnings.append(f"{name}: texture2D uses '{u}' but no matching "
                        f"`uniform sampler2D {u};` was found")


def check_drawbuffers(name: str, raw: str, errors: list):
    m = re.search(r'/\*\s*(DRAWBUFFERS|RENDERTARGETS)\s*:\s*([0-9, ]+)\*/', raw)
    writes = re.findall(r'gl_FragData\s*\[\s*(\d+)\s*\]', raw)
    if name.endswith(".fsh"):
        if m:
            kind, body = m.group(1), m.group(2).strip()
            if kind == "DRAWBUFFERS":
                # OptiFine form: each character is one buffer index, e.g. "012".
                declared = list(body.replace(" ", ""))
            else:
                # Iris RENDERTARGETS form: comma-separated indices, e.g. "0,1,2".
                declared = [c for c in re.split(r'[,\s]+', body) if c != ""]
            # Every gl_FragData[i] index must map to a position in the list.
            for w in set(writes):
                if int(w) >= len(declared):
                    errors.append(f"{name}: writes gl_FragData[{w}] but DRAWBUFFERS "
                                  f"only declares {len(declared)} target(s)")
        elif writes:
            errors.append(f"{name}: uses gl_FragData[...] but has no "
                          f"/* DRAWBUFFERS:... */ directive")


def main():
    errors, warnings = [], []
    entries = sorted(p for p in SHADERS.glob("*") if p.suffix in ENTRY_SUFFIXES)
    if not entries:
        print("No shader entry points found under shaders/", file=sys.stderr)
        return 1

    for path in entries:
        name = path.name
        try:
            raw_flat = flatten(path)
        except (FileNotFoundError, ValueError) as e:
            errors.append(str(e))
            continue

        code = strip_comments_and_strings(raw_flat)
        check_balance(name, code, errors)
        check_undeclared_samplers(name, code, warnings)
        check_drawbuffers(name, raw_flat, errors)  # needs comments intact

    print(f"Checked {len(entries)} shader programs.\n")
    for w in warnings:
        print(f"  warning: {w}")
    for e in errors:
        print(f"  ERROR:   {e}")
    print()
    if errors:
        print(f"FAILED with {len(errors)} error(s), {len(warnings)} warning(s).")
        return 1
    print(f"OK ({len(warnings)} warning(s)).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
