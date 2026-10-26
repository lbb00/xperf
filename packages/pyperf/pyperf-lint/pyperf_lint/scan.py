"""Line-window scanner for pp-str-plus-in-loop-pp-print-in-loop (PP004 removed 2026-10-22)."""
from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import List

RE_LOOP = re.compile(r"\b(for|while)\b")
RE_STR_PLUS = re.compile(r"(\w+)\s*\+=\s*([^\n#]+)")
RE_LIST_PLUS = re.compile(r"(\w+)\s*=\s*\1\s*\+\s*\[")
RE_PRINT = re.compile(r"\bprint\s*\(")
RE_JSON = re.compile(r"\bjson\.(loads|dumps|load|dump)\s*\(")
RE_DEEPCOPY = re.compile(r"\b(?:copy\.)?deepcopy\s*\(")
RE_OPEN = re.compile(r"(?<![\w.])open\s*\(")
RE_FOR_HEAD = re.compile(r"\bfor\s+(.+?)\s+in\b")
RE_JSON_ARG = re.compile(r"\bjson\.(?:loads|dumps|load|dump)\s*\(([^)\n]*)")
RE_OPEN_ARG = re.compile(r"(?<![\w.])open\s*\(([^)\n]*)")
RE_IDENT = re.compile(r"[A-Za-z_]\w*")
# strptime/strftime only. A bare now() call is not this rule.
RE_NUM = re.compile(r"^\d")
RE_LEN = re.compile(r"^len\s*\(")
# Ad-hoc re.METHOD( with a string/bytes literal pattern — compiles every call.
# RE_ADHOC removed with PP004
RE_DEF = re.compile(r"^(async\s+)?def\b")
COUNTER_LHS = re.compile(
    r"^(i|j|k|n|x|y|pos|position|index|idx|count|cnt|length|offset|size|total|"
    r"num_\w+|stripped_length|num_bytes_read|val|lineno)$",
    re.I,
)
BARE_NAME = re.compile(r"^[A-Za-z_][\w\.]*$")

MSG = {
    "pp-str-plus-in-loop": "string += in loop; prefer str.join / StringIO",
    "pp-list-plus-rebind": "list + rebinding in loop; prefer append",
    "pp-print-in-loop": "print( in loop; gate or buffer",
    "pp-json-in-loop": "json.loads/dumps in a loop; hoist only when this text stays the same",
    "pp-deepcopy-in-loop": "deepcopy in loop; copy once or share the structure",
    "pp-open-in-loop": "open() in a loop; open once when the path stays the same",
    # "PP004" removed 2026-10-22 — see evidence/_removed/
}

SKIP_DIRS = {
    ".git",
    "__pycache__",
    ".venv",
    "venv",
    "node_modules",
    "fixtures",
    ".tox",
    "tests",
    "testdata",
    "testserver",
    "scripts",
}


@dataclass
class Finding:
    rule: str
    path: str
    line: int
    message: str


def _strip_comment(line: str) -> str:
    """Drop trailing # comments outside simple quotes (heuristic)."""
    in_str = None
    i = 0
    while i < len(line):
        c = line[i]
        if in_str:
            if c == "\\" and i + 1 < len(line):
                i += 2
                continue
            if c == in_str:
                in_str = None
            i += 1
            continue
        if c == '"' or c == "'":
            in_str = c
            i += 1
            continue
        if c == "#":
            return line[:i]
        i += 1
    return line


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" \t"))


def _looks_string_plus(lhs: str, rhs: str, full: str) -> bool:
    """String-ish += ; drop numeric / list / Media / tuple noise."""
    rhs = rhs.strip()
    if not rhs:
        return False
    if RE_NUM.match(rhs) or RE_LEN.match(rhs) or ".count(" in rhs:
        return False
    if ".media" in full or lhs == "media":
        return False
    if ("[" in rhs or rhs.startswith("(")) and '"' not in rhs and "'" not in rhs:
        return False
    if '"' in rhs or "'" in rhs or "str(" in rhs or ".format" in rhs or "%" in rhs:
        return True
    if BARE_NAME.match(rhs) and not COUNTER_LHS.match(lhs):
        return True
    return False



def _for_names(header: str) -> list[str]:
    m = RE_FOR_HEAD.search(header)
    if not m:
        return []
    return [n for n in RE_IDENT.findall(m.group(1)) if n != "_"]


def _arg_uses(code: str, arg_re: re.Pattern[str], names: list[str]) -> bool:
    if not names:
        return False
    m = arg_re.search(code)
    if not m:
        return False
    args = re.sub(r"(\"|\').*?\1", " ", m.group(1))
    idents = set(RE_IDENT.findall(args))
    return any(n in idents for n in names)


def scan_file(path: str | Path) -> List[Finding]:
    path = str(path)
    findings: List[Finding] = []
    try:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return findings
    lines = text.splitlines()
    loop_indent = None
    loop_names: list[str] = []
    func_indent = None
    for i, raw in enumerate(lines, 1):
        code = _strip_comment(raw)
        stripped = code.strip()
        if not stripped:
            continue
        ind = _indent(code)
        if loop_indent is not None and ind <= loop_indent:
            if RE_LOOP.search(stripped) is None or not stripped.endswith(":"):
                loop_indent = None
                loop_names = []
        if func_indent is not None and ind <= func_indent:
            if not RE_DEF.match(stripped) and not stripped.startswith("class "):
                func_indent = None
        if RE_DEF.match(stripped) and stripped.endswith(":"):
            func_indent = ind
        if RE_LOOP.search(stripped) and stripped.endswith(":"):
            loop_indent = ind
            loop_names = _for_names(stripped)
            # do not continue — a for-line itself is not a body hit
            continue
        in_loop = loop_indent is not None and ind > loop_indent
        in_func = func_indent is not None and ind > func_indent
        if in_loop:
            m = RE_STR_PLUS.search(stripped)
            if m and _looks_string_plus(m.group(1), m.group(2), stripped):
                findings.append(Finding("pp-str-plus-in-loop", path, i, MSG["pp-str-plus-in-loop"]))
            if RE_LIST_PLUS.search(stripped):
                findings.append(Finding("pp-list-plus-rebind", path, i, MSG["pp-list-plus-rebind"]))
            if RE_PRINT.search(stripped):
                findings.append(Finding("pp-print-in-loop", path, i, MSG["pp-print-in-loop"]))
            if RE_JSON.search(stripped) and not _arg_uses(stripped, RE_JSON_ARG, loop_names):
                findings.append(Finding("pp-json-in-loop", path, i, MSG["pp-json-in-loop"]))
            if RE_DEEPCOPY.search(stripped):
                findings.append(Finding("pp-deepcopy-in-loop", path, i, MSG["pp-deepcopy-in-loop"]))
            if RE_OPEN.search(stripped) and not _arg_uses(stripped, RE_OPEN_ARG, loop_names):
                findings.append(Finding("pp-open-in-loop", path, i, MSG["pp-open-in-loop"]))
        # PP004 removed 2026-10-22 — id tombstoned.
    return findings


def scan_path(root: str | Path) -> List[Finding]:
    root = Path(root)
    out: List[Finding] = []
    if root.is_file():
        if root.suffix == ".py":
            out.extend(scan_file(root))
        return out
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
        base = Path(dirpath)
        # Skip management commands (CLI; cold)
        if "management" in base.parts and "commands" in base.parts:
            dirnames[:] = []
            continue
        for name in filenames:
            if not name.endswith(".py"):
                continue
            if name.startswith("test_") or name.endswith("_tests.py"):
                continue
            out.extend(scan_file(base / name))
    return out
