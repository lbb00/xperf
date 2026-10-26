# Ruby performance guide (v0)

Fewer quadratic builders, quieter hot paths.

> **Scope: MRI Ruby 3+.** Claims that assert speedups name a local example or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## 0. Scope and method

1. **Measure first** (`benchmark`, stackprof).
2. Treat each chapter as a checklist.
3. JRuby / TruffleRuby differ — re-bench.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Strings, arrays, and hashes](#1-strings-arrays-and-hashes)
- [2. Hot I/O](#2-hot-io)
- [Lint map](#lint-map)

## 1. Strings, arrays, and hashes

`s += piece` allocates a new string each time; prefer `s << piece` (or a buffer). `arr = arr + [x]` copies; prefer `<<` / `push`.

`Hash#merge` in a loop was removed. On Ruby 4.0.8 the suggested literal build was slower than `merge` (~0.78×, and again ~0.65×) and allocated about twice as many objects. See `evidence/_removed/rb-hash-merge-in-loop.REMOVED.md`.

Companion lint: **rb-string-plus-in-loop**, **rb-array-plus-rebind**.

## 2. Hot I/O

`puts` / `print` in a tight loop flushes. Gate debug output or buffer.

Companion lint: **rb-puts-in-loop**.

## 3. Compile and parse

`Regexp.new` compiles on every call. A regexp literal is cached. `JSON.parse` / `generate` on a fixed payload repeats the parse. A changing payload cannot be hoisted. These lints are **hint** and have a microbench. `Date.parse` / `Time.parse` / `DateTime.parse` was removed for the same reason as a fixed-string parse: the after side only wins by not parsing.

`File.read` of one path was about 346× versus reading once. `File.open` is the same lint. A path that changes every iteration cannot be hoisted. `Process.clock_gettime` was about 2.3× and `send` about 1.9×; those were checked and not given a rule.

Companion lint: **rb-regexp-new-in-loop**, **rb-json-in-loop**, **rb-file-read-in-loop**.
## Lint map

| ID | Smell | Default |
|----|-------|---------|
| rb-string-plus-in-loop | string `+=` in loop | off |
| rb-array-plus-rebind | Array `+` / concat rebinding in loop | off |
| rb-puts-in-loop | `puts` / `print` in loop | off |
| rb-regexp-new-in-loop | `Regexp.new` in loop | hint (measured; not corpus-triaged) |
| rb-json-in-loop | `JSON.parse` / `generate` in loop | hint (measured; not corpus-triaged) |

Enable an `off` rule with `--severity <rule>=hint`. Escalate to `error` only with measured `evidence/rb-*.jsonl` — see [evidence-policy.md](evidence-policy.md). `rb-date-parse-in-loop` and `rb-hash-merge-in-loop` were removed.

## References

- [XPerf playbook](../../../docs/playbook.md)
