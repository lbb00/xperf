# Swift performance guide (v0)

Fewer force-unwraps on hot paths, fewer quadratic string builders.

> **Scope: Swift 5.9+.** Claims that assert speedups name a local example or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## 0. Scope and method

1. **Measure first** (Instruments, `swift package benchmark` when available).
2. Treat each chapter as a checklist.
3. ARC and specialization change costs — re-bench after toolchain bumps.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Optionals and hot paths](#1-optionals-and-hot-paths)
- [2. Strings, collections, and printing](#2-strings-collections-and-printing)
- [3. Formatters, JSON, and regular expressions](#3-formatters-json-and-regular-expressions)
- [Lint map](#lint-map)

## 1. Optionals and hot paths

Force-unwrap (`!`) in a tight loop crashes on nil and skips safer control flow. Prefer `guard let` / `if let` once per iteration or hoist.

Force-unwrap and `if let` took the same time on a non-nil array, so there is no lint for it.
## 2. Strings, collections, and printing

Repeated `s += piece` can be costly; prefer reserved capacity / builders when measured. Hot `print` is I/O-bound — gate it. Appending to an empty `Array` in a sized loop reallocates as it grows; call `reserveCapacity` first when the final count is known.

Companion lint: **sp-print-in-loop** (off; about 10× a `String` when stdout is discarded), **sp-array-no-reserve** (hint; about 5× on many small arrays, about 1.6× on one large fill). String `+=` with `reserveCapacity` was slower, and `map` then `joined` was about 1.2×, so those lints were removed.

## 3. Formatters, JSON, and regular expressions

`DateFormatter`, `JSONDecoder`, and `NSRegularExpression` do heavy setup. Building one on every iteration of a hot loop repeats that work; create it once and reuse it. `JSONSerialization.jsonObject` belongs with the JSON case. A Swift `Regex` value is a different API and is not flagged. These lints are **hint**. Each has a JSONL microbench and stays hint. They are not part of the 2026-10-22 corpus-ready verdict.

`String(contentsOfFile:)` of one path was about 414× versus reading once. A path that changes every iteration cannot be hoisted.

`Date()` every iteration was about 244× versus one sample. A loop that needs a fresh timestamp has nothing to hoist. `DateFormatter` stays its own rule.

`value(forKey:)` every iteration was about 35× versus reading the property. A name that changes every iteration cannot become a direct property. This is the same family as Go `FieldByName`.

Companion lint: **sp-dateformatter-in-loop**, **sp-json-decode-in-loop**, **sp-regex-in-loop**, **sp-file-read-in-loop**, **sp-clock-in-loop**, **sp-value-for-key-in-loop**.
## Lint map

| ID | Smell | Default |
|----|-------|---------|
| sp-print-in-loop | `print(` in loop | off (about 10× a String; stdout discarded) |
| sp-array-no-reserve | empty Array then append without `reserveCapacity` | hint (about 5× small, about 1.6× one large fill) |
| sp-dateformatter-in-loop | date formatter constructed in a loop | hint (JSONL present; not corpus-triaged) |
| sp-json-decode-in-loop | JSON decoder or jsonObject in a loop | hint (JSONL present; not corpus-triaged) |
| sp-regex-in-loop | regular expression constructed in a loop | hint (JSONL present; not corpus-triaged) |

Enable an `off` rule with `--severity <rule>=hint`. The five rules from 2026-10-22 still have no JSONL. The three rows added 2026-10-23 have a JSONL microbench and stay **hint**. They are not part of the 2026-10-22 corpus-ready verdict. See [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
