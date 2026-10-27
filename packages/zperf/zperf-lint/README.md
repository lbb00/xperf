# `zperf-lint`

Performance and memory anti-pattern checker for Zig 0.17.0. Zig + `std.zig.Ast`, one file at a time, no types. Findings are review prompts, not compiler errors.

Licensed under the [MIT License](LICENSE).

## Build

Requires Zig 0.17.0 and has no third-party dependencies.

```sh
zig build -Doptimize=fast
zig build test --summary all
zig build run -- ../examples
```

The executable is written to `zig-out/bin/zperf-lint`.

## Usage

```text
zperf-lint [options] <file-or-directory>...

  -f, --format <text|json>       Output format (default: text)
  --enable <rules,...>           Enable only these rules (IDs or names)
  --disable <rules,...>          Disable rules
  --large-struct-bytes <N>       zp-large-struct-by-value threshold (default: 64)
  --hot-fn <names,...>           Add hot function names for zp-per-packet-alloc; a trailing * is a prefix wildcard
  --hot-fn-preset <name>         Append a named hot-fn set (`server`: accept/handleRequest/serve/…)
  --no-hot-propagation           Do not propagate hot status through local calls
  --strict-log-in-loop           zp-print-hot also flags `std.log.*` / `log.*` in loops (default: `debug.print` only)
  --include-tests                Also lint `build.zig`, `**/tests/**`, `**/*test*.zig`, `**/testing/**`, `**/Build/**`, `**/*benchmark*.zig`, `**/benchmarks/**`
  --include-scripts              Also lint files under `scripts/` (skipped by default)
  --include-compiler-rt          Also lint `compiler_rt` / `lib/compiler_rt` (skipped by default)
  -j, --jobs <N>                 Worker count (default: CPU count)
  --profile                      Print cumulative phase timings to stderr
  --no-fail                      Return 0 even when findings or parse errors exist (JSON includes `parse_errors`)
  --list-rules                   List rules, fixes, and false-positive risks
  -h, --help
```

Directories are traversed recursively for `.zig` files. `.zig-cache` and `zig-out` are skipped. **Default path skips** (opt-in flags in parentheses):

| Skip | Flag to include |
|------|-----------------|
| `build.zig`, `t.zig`, `**/tests/**`, `**/testing/**`, `*test*.zig` | `--include-tests` |
| `**/Build/**`, `Build.zig` (std.Build graph) | `--include-tests` |
| `*benchmark*.zig`, `**/benchmarks/**` | `--include-tests` |
| `*fuzz*.zig`, `**/fuzz/**` | `--include-tests` |
| `scripts/` | `--include-scripts` |
| `compiler_rt/`, `lib/compiler_rt/`, `compiler_rt.zig` | `--include-compiler-rt` |

Rule names and IDs both work, for example `--enable=zp-shift-on-read,page-allocator-small`. Output order is stable across worker counts.

Exit codes: `0` means no findings (or `--no-fail`); `1` means findings; `2` means invalid arguments, I/O errors, or source parse errors. With `--no-fail`, parse errors are still reported (stderr + JSON `parse_errors`) but do **not** force exit 2, so other files' findings remain usable.

### Tip Zig / parse resilience

Zig tip syntax `errdefer |err| expr` is not accepted by `std.zig.Ast` on 0.17.0. When the first parse fails, zperf-lint rewrites payload captures to a 0.17-parseable block (`errdefer { const err: anyerror = undefined; _ = expr; }`) and retries — similar to the Zig 0.16 `**` compatibility path. Files that still fail to parse are listed in JSON `parse_errors`; with `--no-fail` the run exits 0. Column positions in rewritten files may shift slightly after the insert.

### Zig 0.16 compatibility

The Zig 0.17 tokenizer removed `**` array repetition. If parsing fails, the checker retries after replacing `**` outside strings and comments with same-length `* ` sequences. This preserves byte offsets and line/column locations and prints a compatibility notice to stderr. The compatibility fixture is `fixtures/compat016.zig`.

### Text output

The message line carries the Chinese message, then the English one. The `建议:` line (suggested fix) and the summary line are Chinese.

```text
fixtures/bad/zp-shift-on-read.zig:8:29: warning[zp-shift-on-read shift-on-read] 读走前缀后把剩余数据整体搬回开头 / remaining bytes shifted back to the front after consuming a prefix: std.mem.copyForwards(self.ready.items[0..], self.ready.items[k..])
    建议: 若每次读取后立即搬移，小块读取时总成本可达 O(n²)；改用读游标，缓冲区耗尽时清零，或仅在已消费至少一半/追加空间不足时压缩，以保证搬移被后续读取摊销；持续流量下也可用环形缓冲/std.fifo

共检查 1 个文件，发现 1 处（warning 1, info 0, hint 0）
```

### JSON output

The tool prints one line; it is wrapped here for reading.

```json
{
  "tool": "zperf-lint",
  "files": 1,
  "count": 1,
  "findings": [
    {
      "file": "fixtures/bad/zp-shift-on-read.zig",
      "line": 8,
      "column": 29,
      "rule": "zp-shift-on-read",
      "name": "shift-on-read",
      "severity": "warning",
      "message_zh": "读走前缀后把剩余数据整体搬回开头",
      "message_en": "remaining bytes shifted back to the front after consuming a prefix",
      "detail": "std.mem.copyForwards(self.ready.items[0..], self.ready.items[k..])",
      "fix": "若每次读取后立即搬移，小块读取时总成本可达 O(n²)；改用读游标，缓冲区耗尽时清零，或仅在已消费至少一半/追加空间不足时压缩，以保证搬移被后续读取摊销；持续流量下也可用环形缓冲/std.fifo"
    }
  ],
  "parse_errors": []
}
```

The `message_zh` and `fix` fields are Chinese; documentation and source comments are maintained in English.

## Suppressions

```zig
// zperf-lint: ignore zp-alloc-hot       // Ignore this line and the next line.
const buf = try gpa.alloc(u8, n); // zperf-lint: ignore alloc-in-loop
// zperf-lint: ignore             // Ignore all rules on this line and the next.
// zperf-lint: ignore-file zp-packable-bools,zp-usize-index-field
// zperf-lint: ignore zp-print-hot -- Intentional diagnostic output.
```

## Rules

Severity levels are `warning` (likely problem), `info` (review recommended), `hint` (usually relevant only on a hot path), and `off`. The severity column is the default from `src/rules.zig`.

`off` rules were demoted after G3/r4 triage on zig std/compiler, tigerbeetle, and ghostty (OK-idiom mass). As built, the command line never reports an `off` rule: `--enable` only selects among the active rules, and only the fixture tests turn `off` rules on (`include_off_rules` in `src/lint.zig`). The nine default-on rules are **zp-page-allocator-small, zp-broad-runtime-safety, zp-static-string-map, zp-queue-ordered-remove, zp-shift-on-read, zp-invariant-float-div, zp-arena-reset-free-all, zp-create-destroy-hot, zp-fixed-size-alloc-hot**. Options that tune an `off` rule (`--large-struct-bytes`, `--strict-log-in-loop`, `--hot-fn`, `--hot-fn-preset`) therefore have no visible effect on the command line.

| ID | Name | Severity | Detection |
|---|---|---|---|
| zp-alloc-hot | `alloc-in-loop` | off | Heap allocation in a loop body; skips arena-like receivers and soft-arena args (`sema.arena`, `*.arena`, same as zp-append-without-reserve). |
| zp-append-without-reserve | `append-without-reserve` | off | Append in a loop without prior capacity reservation; skips arena/`alloc` args and test blocks. |
| zp-page-allocator-small | `page-allocator-small` | warning | Direct use of `page_allocator` / `*.page_allocator` for small or container allocations (not `huge_page_allocator`). |
| zp-debug-allocator | `debug-allocator` | off | GeneralPurposeAllocator/DebugAllocator use without a visible build-mode selection. |
| zp-large-struct-by-value | `large-struct-by-value` | off | Passing a large locally declared struct by value. |
| zp-print-hot | `print-in-loop` | off | `std.debug.print` inside a loop; `std.log.*` only with `--strict-log-in-loop`. |
| zp-unbuffered-io | `unbuffered-io` | off | Empty-buffer reader/writer; skips tests, `readVec`/`writeVec`, same-line buffer comments, bulk helpers, one-shot writes. |
| zp-missing-free | `missing-free` | off | Allocation or initialization without visible deinit/free/destroy or ownership transfer. |
| zp-broad-runtime-safety | `broad-runtime-safety` | warning | `@setRuntimeSafety(false)` covers a broad scope. |
| zp-packable-bools | `packable-bools` | off | Several `bool` fields that may be packed or stored out of band. |
| zp-usize-index-field | `usize-index-field` | off | An index-like field uses `usize`. |
| zp-aos-single-field | `aos-single-field` | off | A loop over an array of structs accesses only one field. |
| zp-catch-unreachable-alloc | `catch-unreachable-alloc` | off | A fallible allocation is followed by `catch unreachable`. |
| zp-oversized-enum-tag | `oversized-enum-tag` | off | An explicitly declared enum tag is wider than its value set needs. |
| zp-optional-scalar-field | `optional-scalar-field` | off | An optional scalar struct field may add padding. |
| zp-bool-array | `bool-array` | off | A bool array or slice is used as a bit set. |
| zp-static-string-map | `static-string-map` | info | A string hash map is populated only with literal keys. |
| zp-runtime-div-hot | `runtime-div-in-loop` | off | Division or modulo by a runtime value inside a loop; skipped under `crypto/` / `compiler_rt/` paths and soft-div fn names (`udiv*`, …). Residual FPs: non-crypto number-theory / codec loops. |
| zp-queue-ordered-remove | `queue-ordered-remove` | warning | `orderedRemove` is used as a queue operation or repeatedly in a loop. |
| zp-shift-on-read | `shift-on-read` | warning | Remaining bytes are shifted to the start after consuming a prefix. |
| zp-per-packet-alloc | `per-packet-alloc` | off | Heap allocation on an inferred or explicitly marked packet/frame hot path. |
| zp-invariant-float-div | `invariant-float-div` | hint | A loop-invariant floating-point divisor appears in an array-store kernel. |
| zp-map-put-without-ensure | `map-put-without-ensure` | off | HashMap `put`/`getOrPut` in a loop without prior `ensure*`. |
| zp-catch-unreachable-io | `catch-unreachable-io` | off | `catch unreachable` on fallible I/O (not close/eventfd/kevent). |
| zp-arena-reset-free-all | `arena-reset-free-all` | warning | `ArenaAllocator.reset(.free_all)` or arena deinit+recreate inside a loop; prefer retain_capacity / retain_with_limit. |
| zp-create-destroy-hot | `create-destroy-in-loop` | info | `allocator.create(T)` paired with `destroy` in the same loop; prefer MemoryPool(T). |
| zp-fixed-size-alloc-hot | `fixed-size-alloc-in-loop` | info | `alloc(u8, comptime_int)` (≥16) in a loop; prefer a size-class buffer pool. |

Rules are syntax-based and conservative: no reliable types, ownership, ABI, bounds, or true hotness. See `src/rules.zig` and `--list-rules` for fixes and caveats.

### Hot-path inference

zp-per-packet-alloc (currently `off`) recognizes common callback and processing names such as `onPacket`, `receiveChunk`, `enqueueJob`, and `processFrame`; `callconv(.c)` functions with bodies are also treated as possible entry points. Add `// zperf-lint: hot` immediately above a function or pass names with `--hot-fn`. Use `--hot-fn-preset=server` to append accept/handleRequest/serve/readLoop/… globs (see `server_hot_preset` in `src/main.zig`). Local calls propagate hot status by up to two levels; use `--no-hot-propagation` to disable that behavior. Diagnostic notes include the inference chain.

## Tests and fixtures

`fixtures/bad/<slug>.zig` contains triggering examples; `fixtures/good/<slug>.zig` contains non-triggering examples. `fixture_test.zig` checks rule coverage, clean fixtures, suppressions, rule selection, and parse errors. Additional fixtures cover Zig 0.16 compatibility and hot-path propagation. Layout estimation also has unit tests in `src/lint.zig`.

Run `zig build test --summary all` to execute the test suite.
