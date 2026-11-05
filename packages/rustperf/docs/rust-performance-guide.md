# Rust performance guide (v0)

Less allocator chatter, fewer surprise string / print stalls.

> **Scope: Rust edition 2021+.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`cargo bench`, `criterion`, `perf`). LLVM optimizations change costs — re-bench after toolchain bumps.

## Contents

- [1. Allocation and clone](#1-allocation-and-clone)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [3. Regex](#3-regex)
- [Lint map](#lint-map)

## 1. Allocation and clone

Prefer reuse and capacity over `Vec::new` / `.clone()` / `.to_string()` inside hot loops when profiles show pressure.

```rust
// prefer: pre-sized or reused buffer
let mut v = Vec::with_capacity(n);
for i in 0..n { v.push(i); }
```

Lint: `rs-alloc-hot` (default off after G3; G4 measured).

## 2. Strings and hot I/O

`format!("{s}…")` / `s = format!(…)` accumulation in a loop is alloc-heavy (copies the growing prefix). Prefer `with_capacity` + `write!`, or collect then join. Plain `+=` / `push_str` on one growing `String` was about 1× versus `with_capacity` on a large fill, so that lint was removed. Keep `println!` / `eprintln!` out of tight loops (gate or buffer).

A large `Vec::new` plus `push` was about 1× versus `with_capacity`, so that lint was removed. Avoid `.collect::<Vec<_>>()` inside per-item loops when a reused buffer or streaming count will do.

Lint: `rs-format-rebind-hot` (default error; G4: ~99× vs `write!`); `rs-println-hot`, `rs-collect-vec-hot` (default hint).

## 3. Regex

`Regex::new` inside a loop recompiles the pattern. On `regex` 1.13.1 and rustc 1.99, constructing every iteration and matching a short haystack was about 963× versus constructing once (both sides still match). This lint is hint. `HashMap::new` plus one insert, 20000 times, was about 1.5× versus clearing one map on two quiet rustc 1.99 runs (`rs-map-new-hot`, hint).

`File::open` of one path was about 416× on rustc 1.99 versus opening once. `Instant::now` was about 20× on rustc 1.99 versus one sample. A changing path cannot be hoisted, and a loop that needs a fresh timestamp has nothing to hoist.

Lint: `rs-regex-new-hot`, `rs-file-open-hot`, `rs-clock-hot` (default hint).

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| rs-alloc-hot | alloc/clone in loop | off (G3 OK-idiom; G4 measured) |
| rs-println-hot | println! / eprintln! in loop | hint |
| rs-format-rebind-hot | `format!` rebind accum in loop | error (G4: ~99× vs `write!`) |
| rs-collect-vec-hot | collect::<Vec> in loop | hint |
| rs-regex-new-hot | `Regex::new` in loop | hint (JSONL about 963× on a short haystack) |

See [evidence-policy.md](evidence-policy.md). Demote `rs-format-rebind-hot` with `--severity rs-format-rebind-hot=hint` if one-shot wraps dominate. Amortized `+=` and large `Vec::new` plus push were removed.

## References

- [XPerf playbook](../../../docs/playbook.md)
