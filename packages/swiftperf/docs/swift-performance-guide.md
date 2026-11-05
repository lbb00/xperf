# Swift performance guide (v0)

Fewer force-unwraps on hot paths, fewer quadratic string builders.

> **Scope: Swift 5.9+.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (Instruments, `swift package benchmark` when available). ARC and specialization change costs — re-bench after toolchain bumps.

## Contents

- [1. Optionals and hot paths](#1-optionals-and-hot-paths)
- [2. Strings, collections, and printing](#2-strings-collections-and-printing)
- [3. Formatters, JSON, and regular expressions](#3-formatters-json-and-regular-expressions)
- [Lint map](#lint-map)

## 1. Optionals and hot paths

Force-unwrap (`!`) in a tight loop crashes on nil and skips safer control flow. Prefer `guard let` / `if let` once per iteration or hoist.

Force-unwrap and `if let` took the same time on a non-nil array, so there is no lint for it.

## 2. Strings, collections, and printing

Repeated `s += piece` can be costly; prefer reserved capacity / builders when measured. Hot `print` is I/O-bound — gate it. Appending to an empty `Array` in a sized loop reallocates as it grows; call `reserveCapacity` first when the final count is known.

Lint: `sp-print-hot` (default off; about 10× a `String` when stdout is discarded); `sp-array-no-reserve` (default hint; about 5× on many small arrays, about 1.6× on one large fill). String `+=` with `reserveCapacity` was slower, and `map` then `joined` was about 1.2×, so those lints were removed.

## 3. Formatters, JSON, and regular expressions

`DateFormatter`, `JSONDecoder`, and `NSRegularExpression` do heavy setup. Building one on every iteration of a hot loop repeats that work; create it once and reuse it. `JSONSerialization.jsonObject` belongs with the JSON case. A Swift `Regex` value is a different API and is not flagged. These lints are hint. Each has a JSONL microbench and stays hint. They are not part of the 2026-10-22 corpus-ready verdict.

`String(contentsOfFile:)` of one path was about 414× versus reading once. A path that changes every iteration cannot be hoisted.

`Date()` every iteration was about 244× versus one sample. A loop that needs a fresh timestamp has nothing to hoist. `DateFormatter` stays its own rule.

`value(forKey:)` every iteration was about 35× versus reading the property. A name that changes every iteration cannot become a direct property. This is the same family as Go `FieldByName`.

Lint: `sp-dateformatter-hot`, `sp-json-decode-hot`, `sp-regex-hot`, `sp-file-read-hot`, `sp-clock-hot`, `sp-value-for-key-hot` (default hint).

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| sp-print-hot | `print(` in loop | off (about 10× a String; stdout discarded) |
| sp-array-no-reserve | empty Array then append without `reserveCapacity` | hint (about 5× small, about 1.6× one large fill) |
| sp-dateformatter-hot | date formatter constructed in a loop | hint (JSONL present; not corpus-triaged) |
| sp-json-decode-hot | JSON decoder or jsonObject in a loop | hint (JSONL present; not corpus-triaged) |
| sp-regex-hot | regular expression constructed in a loop | hint (JSONL present; not corpus-triaged) |

Enable an `off` rule with `--severity <rule>=hint`. The five rules from 2026-10-22 still have no JSONL. The three rows added 2026-10-23 have a JSONL microbench and stay hint. They are not part of the 2026-10-22 corpus-ready verdict. See [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
