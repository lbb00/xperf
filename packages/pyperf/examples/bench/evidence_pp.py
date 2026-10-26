#!/usr/bin/env python3
"""Evidence microbench for pp-str-plus-in-loop–PP004 → packages/pyperf/evidence/PP*.jsonl"""
from __future__ import annotations

import gc
import os
import re
import statistics
import sys
import time
from pathlib import Path

WARM = int(os.environ.get("PP_WARM", "3"))
ROUNDS = int(os.environ.get("PP_ROUNDS", "9"))
OUT = Path(os.environ.get("EVIDENCE_DIR") or (Path(__file__).resolve().parents[2] / "evidence"))


def median(xs: list[float]) -> float:
    return float(statistics.median(xs))


def time_many(fn) -> float:
    for _ in range(WARM):
        fn()
    samples: list[float] = []
    sink = 0
    for _ in range(ROUNDS):
        gc.collect()
        t0 = time.perf_counter()
        sink += fn()
        t1 = time.perf_counter()
        samples.append((t1 - t0) * 1e3)
    if sink != sink:
        raise RuntimeError("nan")
    return median(samples)


def iso_ts() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ver = f"CPython {sys.version.split()[0]}"
    ts = iso_ts()
    lines_by: dict[str, list[str]] = {}

    def emit(rule: str, case: str, role: str, med: float, ops: int, ratio: float) -> None:
        obj = (
            f'{{"rule":"{rule}","case":"{case}","role":"{role}","python":"{ver}",'
            f'"median_ms":{med:.6f},"ops":{ops},"ratio":{ratio:.6f},"ts":"{ts}"}}'
        )
        lines_by.setdefault(rule, []).append(obj)
        print(f"  {rule} {role} {case} median={med:.3f} ms ops={ops} ratio={ratio:.3f}", file=sys.stderr)

    # --- pp-str-plus-in-loop: str += vs join ---
    n1 = int(os.environ.get("PP001_N", "50000"))
    parts = ["x"] * n1
    print(f"pp-str-plus-in-loop str-plus n={n1}", file=sys.stderr)
    med1a = time_many(lambda: len("".join(parts)))
    med1b = time_many(lambda: _str_plus(parts))
    emit("pp-str-plus-in-loop", "str_join", "after", med1a, n1, 1.0)
    emit("pp-str-plus-in-loop", "str_plus", "before", med1b, n1, med1b / max(med1a, 1e-9))

    n1s = int(os.environ.get("PP001_N_SMALL", "100"))
    parts_s = parts[:n1s]
    med1sa = time_many(lambda: len("".join(parts_s)))
    med1sb = time_many(lambda: _str_plus(parts_s))
    emit("pp-str-plus-in-loop", "small_join", "after", med1sa, n1s, 1.0)
    emit("pp-str-plus-in-loop", "small_str_plus", "before", med1sb, n1s, med1sb / max(med1sa, 1e-9))

    # --- pp-list-plus-rebind: list + [x] vs append ---
    n2 = int(os.environ.get("PP002_N", "20000"))
    print(f"pp-list-plus-rebind list-plus n={n2}", file=sys.stderr)
    med2a = time_many(lambda: _list_append(n2))
    med2b = time_many(lambda: _list_plus(n2))
    emit("pp-list-plus-rebind", "list_append", "after", med2a, n2, 1.0)
    emit("pp-list-plus-rebind", "list_plus_rebind", "before", med2b, n2, med2b / max(med2a, 1e-9))

    n2s = int(os.environ.get("PP002_N_SMALL", "100"))
    med2sa = time_many(lambda: _list_append(n2s))
    med2sb = time_many(lambda: _list_plus(n2s))
    emit("pp-list-plus-rebind", "small_append", "after", med2sa, n2s, 1.0)
    emit("pp-list-plus-rebind", "small_list_plus", "before", med2sb, n2s, med2sb / max(med2sa, 1e-9))

    # --- pp-print-in-loop: print in loop vs join once (stdout discarded) ---
    n3 = int(os.environ.get("PP003_N", "20000"))
    items = list(range(n3))
    print(f"pp-print-in-loop print-loop n={n3}", file=sys.stderr)
    devnull = open(os.devnull, "w")

    def print_loop():
        old = sys.stdout
        sys.stdout = devnull
        try:
            for x in items:
                print(x)
        finally:
            sys.stdout = old
        return n3

    def print_join():
        old = sys.stdout
        sys.stdout = devnull
        try:
            print("\n".join(str(x) for x in items))
        finally:
            sys.stdout = old
        return n3

    med3a = time_many(print_join)
    med3b = time_many(print_loop)
    emit("pp-print-in-loop", "print_join_once", "after", med3a, n3, 1.0)
    emit("pp-print-in-loop", "print_in_loop", "before", med3b, n3, med3b / max(med3a, 1e-9))
    devnull.close()

    # --- PP004: ad-hoc re.sub vs compiled (many calls) ---
    n4 = int(os.environ.get("PP004_N", "20000"))
    samples = [f"Hello World #{i}!! Foo-Bar  " for i in range(32)]
    print(f"PP004 re-adhoc calls={n4}", file=sys.stderr)

    _NON = re.compile(r"[^\w\s-]")
    _DASH = re.compile(r"[-\s]+")

    def slug_compiled(value: str) -> str:
        value = _NON.sub("", value.lower())
        return _DASH.sub("-", value).strip("-_")

    def slug_adhoc(value: str) -> str:
        value = re.sub(r"[^\w\s-]", "", value.lower())
        return re.sub(r"[-\s]+", "-", value).strip("-_")

    def run_compiled():
        s = 0
        for i in range(n4):
            s += len(slug_compiled(samples[i % 32]))
        return s

    def run_adhoc():
        s = 0
        for i in range(n4):
            s += len(slug_adhoc(samples[i % 32]))
        return s

    med4a = time_many(run_compiled)
    med4b = time_many(run_adhoc)
    emit("PP004", "re_compiled", "after", med4a, n4, 1.0)
    emit("PP004", "re_adhoc", "before", med4b, n4, med4b / max(med4a, 1e-9))

    n4s = int(os.environ.get("PP004_N_SMALL", "100"))

    def run_compiled_s():
        s = 0
        for i in range(n4s):
            s += len(slug_compiled(samples[i % 32]))
        return s

    def run_adhoc_s():
        s = 0
        for i in range(n4s):
            s += len(slug_adhoc(samples[i % 32]))
        return s

    med4sa = time_many(run_compiled_s)
    med4sb = time_many(run_adhoc_s)
    emit("PP004", "small_compiled", "after", med4sa, n4s, 1.0)
    emit("PP004", "small_adhoc", "before", med4sb, n4s, med4sb / max(med4sa, 1e-9))

    for rule, lines in lines_by.items():
        path = OUT / f"{rule}.jsonl"
        path.write_text("\n".join(lines) + "\n")
        print(f"wrote {path}", file=sys.stderr)
        print("\n".join(lines))


def _str_plus(parts: list[str]) -> int:
    s = ""
    for p in parts:
        s += p
    return len(s)


def _list_append(n: int) -> int:
    xs: list[int] = []
    for i in range(n):
        xs.append(i)
    return len(xs)


def _list_plus(n: int) -> int:
    xs: list[int] = []
    for i in range(n):
        xs = xs + [i]
    return len(xs)


if __name__ == "__main__":
    main()
