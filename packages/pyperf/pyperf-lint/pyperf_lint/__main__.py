#!/usr/bin/env python3
"""CLI for pyperf-lint."""
from __future__ import annotations

import argparse
import json
import sys

from .scan import scan_path

SEV = {"off": 0, "hint": 1, "error": 2}
DEFAULT = {
    "pp-str-plus-hot": "off",
    "pp-list-plus-rebind": "hint",
    "pp-print-hot": "off",
    "pp-json-hot": "hint",
    "pp-deepcopy-hot": "hint",
    "pp-open-hot": "hint",
}  # PP004 removed 2026-10-22

def main(argv=None):
    p = argparse.ArgumentParser(prog="pyperf-lint")
    p.add_argument("paths", nargs="+")
    p.add_argument("--format", choices=("text", "json"), default="text")
    p.add_argument("--severity", action="append", default=[], metavar="RULE=LEVEL")
    p.add_argument("--strict-hints", action="store_true")
    p.add_argument("--no-fail", action="store_true")
    p.add_argument("--scope", choices=("all", "loop"), default="all",
                   help="all=report everywhere (default); loop=former in-loop-only match")
    args = p.parse_args(argv)

    sev = dict(DEFAULT)
    for spec in args.severity:
        if "=" not in spec:
            sys.stderr.write("bad --severity " + spec + "\n")
            return 2
        rule, level = spec.split("=", 1)
        if rule not in sev or level not in SEV:
            sys.stderr.write("bad --severity " + spec + "\n")
            return 2
        sev[rule] = level

    findings = []
    for path in args.paths:
        findings.extend(scan_path(path, scope=args.scope))

    nerr = nhint = 0
    rows = []
    lines = []
    for f in findings:
        level = sev.get(f.rule, "hint")
        if level == "off":
            continue
        if level == "error":
            nerr += 1
        else:
            nhint += 1
        if args.format == "json":
            rows.append({
                "rule": f.rule,
                "severity": level,
                "path": f.path,
                "line": f.line,
                "message": f.message,
            })
        else:
            lines.append("%s:%d: %s %s: %s" % (f.path, f.line, level, f.rule, f.message))

    if args.format == "json":
        json.dump(rows, sys.stdout)
        sys.stdout.write("\n")
    else:
        if lines:
            print("\n".join(lines))
        shown = nerr + nhint
        if shown:
            print("%d finding(s) (%d error, %d hint)" % (shown, nerr, nhint), file=sys.stderr)
        else:
            print("ok", file=sys.stderr)

    if args.no_fail:
        return 0
    if nerr > 0 or (args.strict_hints and nhint > 0):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
