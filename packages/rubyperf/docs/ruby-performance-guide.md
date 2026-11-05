# Ruby performance guide (v0)

Fewer quadratic builders, quieter hot paths.

> **Scope: MRI Ruby 3+.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`benchmark`, stackprof). JRuby and TruffleRuby differ — re-bench.

## Contents

- [1. Strings, arrays, and hashes](#1-strings-arrays-and-hashes)
- [2. Hot I/O](#2-hot-io)
- [3. Compile and parse](#3-compile-and-parse)
- [Lint map](#lint-map)

## 1. Strings, arrays, and hashes

`s += piece` allocates a new string each time; prefer `s << piece` (or a buffer). `arr = arr + [x]` copies; prefer `<<` / `push`.

`Hash#merge` in a loop was removed. On Ruby 4.0.8 the suggested literal build was slower than `merge` (~0.78×, and again ~0.65×) and allocated about twice as many objects. See `evidence/_removed/rb-hash-merge-in-loop.REMOVED.md`.

Lint: `rb-string-plus-hot`, `rb-array-plus-rebind` (default off).

## 2. Hot I/O

`puts` / `print` in a tight loop flushes. Gate debug output or buffer.

Lint: `rb-puts-hot` (default off).

## 3. Compile and parse

`Regexp.new` compiles on every call. A regexp literal is cached. `JSON.parse` / `generate` on a fixed payload repeats the parse. A changing payload cannot be hoisted. These lints are hint and have a microbench. `Date.parse` / `Time.parse` / `DateTime.parse` was removed for the same reason as a fixed-string parse: the after side only wins by not parsing.

`File.read` of one path was about 346× versus reading once. `File.open` is the same lint. A path that changes every iteration cannot be hoisted. `Process.clock_gettime` was about 2.3× and `send` about 1.9×; those were checked and not given a rule.

Lint: `rb-regexp-new-hot`, `rb-json-hot`, `rb-file-read-hot` (default hint).

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| rb-string-plus-hot | string `+=` in loop | off |
| rb-array-plus-rebind | Array `+` / concat rebinding in loop | off |
| rb-puts-hot | `puts` / `print` in loop | off |
| rb-regexp-new-hot | `Regexp.new` in loop | hint (measured; not corpus-triaged) |
| rb-json-hot | `JSON.parse` / `generate` in loop | hint (measured; not corpus-triaged) |

Enable an `off` rule with `--severity <rule>=hint`. Escalate to `error` only with measured `evidence/rb-*.jsonl` — see [evidence-policy.md](evidence-policy.md). `rb-date-parse-in-loop` and `rb-hash-merge-in-loop` were removed.

## References

- [XPerf playbook](../../../docs/playbook.md)
