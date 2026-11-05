# Go performance guide (v0)

Less allocation chatter, fewer surprise `fmt` / string-growth stalls.

> **Scope: Go 1.21+.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`go test -bench`, `pprof`, `benchstat`). Escape analysis and inlining change costs — re-bench after toolchain bumps.

## Contents

- [1. Allocation](#1-allocation)
- [2. Strings and formatting](#2-strings-and-formatting)
- [3. Compile, encode, and reflect](#3-compile-encode-and-reflect)
- [Lint map](#lint-map)

## 1. Allocation

Prefer reusing buffers (`sync.Pool`, pre-sized slices) over `make`/`new` inside tight loops when profiles show alloc pressure. Escape analysis may keep small values on the stack — do not rewrite without a bench.

Lint: `gp-make-hot` (default off after G3); `gp-append-nil-slice` (empty slice + append in size-hinted loop; default hint).

## 2. Strings and formatting

Repeated `s += piece` in a loop is quadratic. Prefer `strings.Builder` or `bytes.Buffer`. Hot-path `fmt.Sprintf` / `fmt.Printf` also allocate; gate debug prints or use cheaper appenders when measured.

Lint: `gp-string-plus-hot`, `gp-fmt-hot` (default off after G3); `gp-defer-hot` (`defer` in loop; default hint).

## 3. Compile, encode, and reflect

`regexp.Compile` / `MustCompile` and `json.Marshal` / `Unmarshal` inside a loop repeat work that can be done once when the pattern or payload does not change. `FieldByName`, `MethodByName`, and `reflect.New` inside a loop are the reflect lint. `TypeOf` on a concrete value was about 1.3× and is not matched. `time.Parse` was removed: a fixed timestamp is faster only when the parse is skipped, and a changing timestamp has nothing to hoist. These lints are hint.

`os.Open` of one path was about 2300× versus opening once. `time.Now` was about 104× versus one sample. That clock rule is not the removed `time.Parse` rule. A changing path cannot be hoisted, and a loop that needs a fresh timestamp has nothing to hoist.

Lint: `gp-regexp-compile-hot`, `gp-json-marshal-hot`, `gp-reflect-hot`, `gp-os-open-hot`, `gp-time-now-hot` (default hint).

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| gp-make-hot | `make`/`new` in loop | off (G3) |
| gp-string-plus-hot | string `+=` in loop | off (G3) |
| gp-fmt-hot | `fmt.Sprintf`/`Printf` in loop | off (G3) |
| gp-append-nil-slice | empty slice + append in size-hinted loop | hint |
| gp-defer-hot | `defer` in loop | hint |
| gp-regexp-compile-hot | `regexp.Compile` in loop | hint (measured; not corpus-triaged) |
| gp-json-marshal-hot | `json.Marshal` / `Unmarshal` in loop | hint (measured; not corpus-triaged) |
| gp-reflect-hot | `FieldByName` / `MethodByName` / `reflect.New` in loop | hint (JSONL; `TypeOf` is not matched) |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
