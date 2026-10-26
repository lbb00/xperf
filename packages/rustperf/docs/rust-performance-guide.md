# Rust performance guide (v0)

Less allocator chatter, fewer surprise string / print stalls.

> **Scope: Rust edition 2021+.** Claims that assert speedups name a local example, an upstream source, or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## 0. Scope and method

1. **Measure first** (`cargo bench`, `criterion`, `perf`).
2. Treat each chapter as a checklist, not a rewrite mandate.
3. LLVM optimizations change costs — re-bench after toolchain bumps.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Allocation and clone](#1-allocation-and-clone)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [Lint map](#lint-map)

## 1. Allocation and clone

Prefer reuse and capacity over `Vec::new` / `.clone()` / `.to_string()` inside hot loops when profiles show pressure.

```rust
// prefer: pre-sized or reused buffer
let mut v = Vec::with_capacity(n);
for i in 0..n { v.push(i); }
```

## 2. Strings and hot I/O

`format!("{s}…")` / `s = format!(…)` accumulation in a loop is alloc-heavy (copies the growing prefix) — **rs-format-rebind-in-loop**. Prefer `with_capacity` + `write!`, or collect then join. Plain `+=` / `push_str` on one growing `String` was about 1× versus `with_capacity` on a large fill, so that lint was removed. Keep `println!` / `eprintln!` out of tight loops (gate or buffer).

A large `Vec::new` plus `push` was about 1× versus `with_capacity`, so that lint was removed. Avoid `.collect::<Vec<_>>()` inside per-item loops when a reused buffer or streaming count will do (**rs-collect-vec-in-loop**).

## 3. Regex

`Regex::new` inside a loop recompiles the pattern. On `regex` 1.13.1 and rustc 1.99, constructing every iteration and matching a short haystack was about 963× versus constructing once (both sides still match). This lint is **hint**. `HashMap::new` plus one insert, 20000 times, was about 1.5× versus clearing one map on two quiet rustc 1.99 runs (`rs-map-new-in-loop`, hint).

`File::open` of one path was about 416× on rustc 1.99 versus opening once. `Instant::now` was about 20× on rustc 1.99 versus one sample. A changing path cannot be hoisted, and a loop that needs a fresh timestamp has nothing to hoist.

Companion lint: **rs-regex-new-in-loop**, **rs-file-open-in-loop**, **rs-clock-in-loop**.
## Lint map

| ID | Smell | Default |
|----|-------|---------|
| rs-alloc-in-loop | alloc/clone in loop | off (G3 OK-idiom; G4 measured) |
| rs-println-in-loop | println! / eprintln! in loop | hint |
| rs-format-rebind-in-loop | `format!` rebind accum in loop | **error** (G4: ~99× vs `write!`) |
| rs-collect-vec-in-loop | collect::<Vec> in loop | hint |
| rs-regex-new-in-loop | `Regex::new` in loop | hint (JSONL about 963× on a short haystack) |

See [evidence-policy.md](evidence-policy.md). Demote rs-format-rebind-in-loop with `--severity rs-format-rebind-in-loop=hint` if one-shot wraps dominate. Amortized `+=` and large `Vec::new` plus push were removed.

## References

- [XPerf playbook](../../../docs/playbook.md)
