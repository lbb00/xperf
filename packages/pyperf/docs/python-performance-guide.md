# Python performance guide (v0)

Fewer quadratic builders, quieter hot paths.

> **Scope: CPython 3.10+.** Claims that assert speedups name a local example or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## How to read this

1. **Measure first** (`timeit`, `py-spy`, `cProfile`).
2. Treat each chapter as a checklist.
3. PyPy / other VMs differ — re-bench.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Strings and lists](#1-strings-and-lists)
- [2. Hot I/O](#2-hot-io)
- [Lint map](#lint-map)

## 1. Strings and lists

`s += piece` in a loop is quadratic on CPython. Prefer `''.join(...)` or `io.StringIO`. Repeated `xs = xs + [item]` similarly copies; prefer `append`.

Companion lint: **pp-str-plus-in-loop**, **pp-list-plus-rebind**.

## 2. Hot I/O

`print` in a tight loop flushes and formats. Gate debug output or buffer.

Companion lint: **pp-print-in-loop**.

## 3. Parse and deep copy

`json.loads` / `json.dumps` and `deepcopy` inside a loop repeat work that belongs outside it when the value does not change. A changing payload cannot be hoisted. These lints are **hint** and have a microbench. `re.compile` was removed: CPython caches it, and the measured difference stayed under 3×. `datetime.strptime` / `strftime` was removed: a fixed string is faster only when the call is skipped, and a changing string has nothing to hoist.

`open` of one path inside a loop repeats the open. One measured shape, a one-byte file, was about 409×. A path that changes every iteration cannot be hoisted. `time.perf_counter_ns` was about 2.9× and `getattr` about 1.4×; those were checked and not given a rule.

Companion lint: **pp-json-in-loop**, **pp-deepcopy-in-loop**, **pp-open-in-loop**.
## Lint map

| ID | Smell | Default |
|----|-------|---------|
| pp-str-plus-in-loop | string `+=` in loop | off (G3) |
| pp-list-plus-rebind | list `+` rebinding in loop | hint |
| pp-print-in-loop | `print(` in loop | off (G3) |
| pp-json-in-loop | `json.loads` / `dumps` in loop | hint (measured; not corpus-triaged) |
| pp-deepcopy-in-loop | `deepcopy` in loop | hint (measured; not corpus-triaged) |

Escalate only with `evidence/pp-*.jsonl` — see [evidence-policy.md](evidence-policy.md). The ad-hoc `re.METHOD(literal)` rule (PP004) was removed; see [rule-ids.md](rule-ids.md). `pp-regex-compile-in-loop` and `pp-datetime-format-in-loop` were removed.

## References

- [XPerf playbook](../../../docs/playbook.md)
