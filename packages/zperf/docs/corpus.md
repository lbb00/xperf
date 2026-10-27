# zperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter. Lint with:

```sh
cd packages/zperf/zperf-lint && zig build -Doptimize=fast
./zig-out/bin/zperf-lint --no-fail -f json <corpus-dir>/<tree>
```

## Pins

Cloned 2026-10-22 (Asia/Shanghai).

| Tree | URL | Commit | Size | `.zig` |
|------|-----|--------|------|-------:|
| **zig** (`lib/std`, `src`) | https://codeberg.org/ziglang/zig.git | `8f0c6ce407f9` | part of 312M | 1072 tree-wide |
| **tigerbeetle** (`src/`) | https://github.com/tigerbeetle/tigerbeetle.git | `0450c32b2c3c` | 14M | 248 |
| **ghostty** | https://github.com/ghostty-org/ghostty.git | `67edd20a0292` | 63M | 603 |
| **http.zig** (secondary) | https://github.com/karlseguin/http.zig.git | `e8272bfd5727` | 1.1M | 33 |

Primary G2 set: **zig (std + compiler)** + **tigerbeetle** + **ghostty** (≥3 large production trees).
http.zig is a compact secondary.

Checker is **Zig**, `std.zig.Ast`, same-language.
Default path skips: tests / Build / benchmarks / **fuzz** / scripts / `compiler_rt`
(see [`zperf-lint/README.md`](../zperf-lint/README.md)).

## G3/r4 results (2026-10-22)

Finding counts under the default rule map, per run: r1 → r3 → **r4**.

| Tree | r1 → r3 → **r4** (defaults) |
|------|------------------------------|
| **zig** `lib/std` | **403 → 391 → 12** |
| **zig** `src` (compiler) | **859 → 856 → 3** |
| **tigerbeetle** `src/` | **252 → 184 → 1** |
| **ghostty** | **441 → 425 → 9** |
| **http.zig** (secondary) | **25 → 24 → 1** |

**Default-off after G3/r4** (OK-idiom mass on mature Zig): zp-alloc-hot, zp-append-without-reserve, zp-debug-allocator, zp-large-struct-by-value, zp-print-hot, zp-unbuffered-io, zp-missing-free, zp-packable-bools, zp-usize-index-field, zp-aos-single-field, zp-catch-unreachable-alloc, zp-oversized-enum-tag, zp-optional-scalar-field, zp-bool-array, zp-runtime-div-hot, zp-per-packet-alloc, zp-map-put-without-ensure, zp-catch-unreachable-io. The CLI does not report `off` rules (see [`zperf-lint/README.md`](../zperf-lint/README.md#rules)).

**Default-on:** zp-page-allocator-small, zp-broad-runtime-safety, zp-static-string-map, zp-queue-ordered-remove, zp-shift-on-read, zp-invariant-float-div, zp-arena-reset-free-all, zp-create-destroy-hot, zp-fixed-size-alloc-hot.

### Reverse-opt + demotion

- Path skip: `*fuzz*.zig`, `**/fuzz/**` (folded into `--include-tests`)
- zp-page-allocator-small: exact `page_allocator` / `*.page_allocator` (not `huge_page_allocator`)
- zp-debug-allocator: only `DebugAllocator(` / `GPA(` instantiations; skip re-exports + test context
- zp-print-hot: skip `if (log)` / `if (logging)` diagnostic gates
- **r4:** demote almost-all OK-idiom rules to default **`off`**; keep the TP-bearing rules (the default-on list above) on the default map

### corpus-ready: **yes**

G3 + r4 demotion complete. Sample on full r4 residuals **n=26**: TP **73.1%**, OK-idiom **26.9%**,
FP+DOC+SKIP-path **0%**. Honest TP on zp-queue-ordered-remove / zp-shift-on-read / zp-broad-runtime-safety / zp-fixed-size-alloc-hot. No mass escalate without G4.

## Inventory

```text
<corpus-dir>/
  zig/            # symlink → zig-corpus/zig
  tigerbeetle/    # symlink
  ghostty/        # symlink
  http.zig/       # symlink (secondary)
```

Do not commit corpus sources into `packages/zperf`.
