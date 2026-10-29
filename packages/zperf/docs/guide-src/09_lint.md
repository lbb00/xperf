## 9. zperf-lint: find anti-patterns automatically

`zperf-lint/` is a Zig 0.17 static checker. It parses with `std.zig.Ast.parse`, walks AST nodes linearly (not recursively), and uses token ranges to decide loop/function membership.

```sh
cd zperf-lint
zig build -Doptimize=fast       # creates zig-out/bin/zperf-lint
zig build test                  # unit tests and rule fixtures
./zig-out/bin/zperf-lint src/ path/to/file.zig --format json --disable zp-static-string-map
```

The rule catalog is in [`zperf-lint/README.md`](../zperf-lint/README.md), or run `zperf-lint --list-rules`. The Severity column is the default from `src/rules.zig`. Rules marked `off` were demoted after triage on mature Zig trees; as built the command line does not report them, and `--enable` only selects among the active rules.

| ID | Name | Severity | Detection |
|---|---|---|---|
| zp-alloc-hot | `alloc-in-loop` | off | heap allocation inside a loop body |
| zp-append-without-reserve | `append-without-reserve` | off | append in a loop without prior ensureTotalCapacity/ensureUnusedCapacity |
| zp-page-allocator-small | `page-allocator-small` | warning | std.heap.page_allocator used directly for small or container allocations |
| zp-debug-allocator | `debug-allocator` | off | GeneralPurposeAllocator/DebugAllocator used without switching on builtin.mode |
| zp-large-struct-by-value | `large-struct-by-value` | off | large struct passed by value |
| zp-print-hot | `print-in-loop` | off | std.debug.print inside a loop (std.log only with --strict-log-in-loop) |
| zp-unbuffered-io | `unbuffered-io` | off | reader/writer created with an empty buffer (&.{}) |
| zp-missing-free | `missing-free` | off | allocated or initialized resource is never freed, deinit-ed, or handed off in this function |
| zp-broad-runtime-safety | `broad-runtime-safety` | warning | @setRuntimeSafety(false) covers too large a scope |
| zp-packable-bools | `packable-bools` | off | struct has several bool fields (1 byte each) |
| zp-usize-index-field | `usize-index-field` | off | index-like field uses usize (8 bytes on 64-bit) |
| zp-aos-single-field | `aos-single-field` | off | loop over array-of-structs touches only one field |
| zp-catch-unreachable-alloc | `catch-unreachable-alloc` | off | `catch unreachable` on a fallible allocation |
| zp-oversized-enum-tag | `oversized-enum-tag` | off | enum explicit tag type is wider than needed |
| zp-optional-scalar-field | `optional-scalar-field` | off | optional scalar field (?u32 etc.) adds a flag byte padded by alignment |
| zp-bool-array | `bool-array` | off | array/slice of bool used as a bit set |
| zp-static-string-map | `static-string-map` | info | StringHashMap populated only with literal keys |
| zp-runtime-div-hot | `runtime-div-in-loop` | off | division/modulo by a runtime value inside a loop |
| zp-queue-ordered-remove | `queue-ordered-remove` | warning | ArrayList removal shifts all following elements |
| zp-shift-on-read | `shift-on-read` | warning | remaining bytes shifted back to the front after consuming a prefix |
| zp-per-packet-alloc | `per-packet-alloc` | off | heap allocation on a per-packet / per-frame hot path |
| zp-invariant-float-div | `invariant-float-div` | hint | floating-point division by a loop-invariant value inside a loop |
| zp-map-put-without-ensure | `map-put-without-ensure` | off | HashMap put/getOrPut in a loop without prior ensureTotalCapacity/ensureUnusedCapacity |
| zp-catch-unreachable-io | `catch-unreachable-io` | off | `catch unreachable` on fallible I/O (read/write/accept/connect/send/recv/…) |
| zp-arena-reset-free-all | `arena-reset-free-all` | warning | ArenaAllocator.reset(.free_all) or deinit+recreate inside a loop |
| zp-create-destroy-hot | `create-destroy-in-loop` | info | allocator.create(T) paired with destroy in the same loop |
| zp-fixed-size-alloc-hot | `fixed-size-alloc-in-loop` | info | alloc(u8, comptime_int) of fixed size inside a loop |
| zp-open-file-hot | `open-file-in-loop` | hint | openFile / openFileAbsolute inside a loop |
| zp-clock-hot | `clock-in-loop` | hint | Io.Clock now inside a loop |
| zp-json-hot | `json-in-loop` | hint | json.parseFromSlice of an unchanged payload inside a loop |
| zp-alloc-print-hot | `alloc-print-in-loop` | hint | allocPrint / Allocator.print of a loop-invariant value |

Example output from the rule fixtures. The message line has the Chinese message, then the English one; the `建议:` line (suggested fix) and the summary line are Chinese:

```text
$ zperf-lint fixtures/bad/zp-shift-on-read.zig
fixtures/bad/zp-shift-on-read.zig:8:29: warning[zp-shift-on-read shift-on-read] 读走前缀后把剩余数据整体搬回开头 / remaining bytes shifted back to the front after consuming a prefix: std.mem.copyForwards(self.ready.items[0..], self.ready.items[k..])
    建议: 若每次读取后立即搬移，小块读取时总成本可达 O(n²)；改用读游标，缓冲区耗尽时清零，或仅在已消费至少一半/追加空间不足时压缩，以保证搬移被后续读取摊销；持续流量下也可用环形缓冲/std.fifo

共检查 1 个文件，发现 1 处（warning 1, info 0, hint 0）
$ echo $?
1
```

Use `// zperf-lint: ignore zp-alloc-hot` to suppress a rule on the current and next line, or `// zperf-lint: ignore-file zp-packable-bools` to suppress a rule for the whole file. Some examples use these directives because they intentionally demonstrate an anti-pattern. The linter itself should report no findings in `examples/`.

Version 0.3 added:

- **zp-queue-ordered-remove:** ArrayList removals that shift the rest of a queue (`orderedRemove(0)` or repeated `orderedRemove` in a loop).
- **zp-shift-on-read:** Prefix consumption followed by moving remaining bytes to the start (`copyForwards(buf[0..], buf[k..])`, `@memmove`, or `replaceRange(..., 0, n, &.{})`).
- **zp-per-packet-alloc:** Heap allocations in likely per-packet or per-frame functions. The checker infers hot functions from names such as `on*`, `handle*`, `recv*`, `enqueue`, and `tick`; users can also write `// zperf-lint: hot` or pass `--hot-fn`. Hotness propagates through direct calls up to two levels in the same file. Findings include a reason chain such as `[hot: pump (marked hot) → stash]`.
- **zp-invariant-float-div:** Floating-point division by a loop-invariant value inside a loop. Without fast-math, the compiler does not replace it with multiplication by a reciprocal; ReleaseFast does not enable fast-math (see §5.7).

For Zig 0.16 sources, `.{x} ** N` is normalized to an equal-length equivalent before parsing because the 0.17 tokenizer removed `**` array repetition.

**A self-hosting lesson:** `Ast.tokenLocation(0, tok)` scans from the start of the file. Calling it for every finding and function made rule analysis O(n²); in zperf-lint 0.3, the rule phase took four times as long as parsing. The fix was to build a line-start offset table in one pass and use binary search. Reusing each file's arena with `reset(.retain_capacity)` (§2.2), and parallelizing files with `Io.Group` while writing to separate result slots (§6.2), reduced a Zig 0.17 standard-library scan of 563 files from 527 ms to 41 ms and peak RSS from 64 MiB to 17 MiB, with byte-for-byte identical output. See the [zperf-lint README](../zperf-lint/README.md).

**Limitations:** zperf-lint is syntax-based and has no type information. It estimates struct size from field types, cannot determine whether division is integer division, and infers ownership transfer from tokens. Each rule lists its false-positive risk. Treat findings as code-review prompts, not compiler errors.

### Pairing zperf-lint with other Zig linters

Zig has several general-purpose tools: [ZLint](https://github.com/DonIsaac/zlint) focuses on correctness, [ziglint](https://github.com/rockorager/ziglint) on style and deprecated APIs, [Zwanzig](https://github.com/forketyfork/zwanzig) includes ZIR path-sensitive analysis, and [zbc](https://github.com/ericsssan/zbc) checks lifecycle and ownership. Compatibility and coverage vary by Zig release; see the [community-tooling note](community-tooling.md) for this project's evaluation criteria.

They overlap little: zperf-lint is performance-oriented; zbc and Zwanzig cover resources and correctness. Run them via `zig run scripts/repo.zig -- lint-all`. Umbrella CI is the root workflow [`ci.yml`](../../../.github/workflows/ci.yml) (job `zperf`); see also [`ci/README.md`](../ci/README.md).

---

