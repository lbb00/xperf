## 5. Computation

### 5.1 `comptime`: move work to compile time

- **Lookup tables:** Build them in a `comptime` block so they live in read-only data and require no runtime initialization. For large loops, raise the compile-time branch quota with `@setEvalBranchQuota`.
- **Generic specialization:** A `comptime N: usize` parameter generates specialized code for each N. `inline for` unrolls the loop at compile time.
- Assert relationships between constants at compile time with `comptime std.debug.assert(...)`, as TigerStyle recommends.

> Example: `examples/p01_comptime_lut.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
const crc_table: [256]u32 = blk: {
    @setEvalBranchQuota(256 * 8 * 4);
    var t: [256]u32 = undefined;
    for (&t, 0..) |*e, i| {
        var c: u32 = @intCast(i);
        for (0..8) |_| c = if (c & 1 != 0) 0xEDB88320 ^ (c >> 1) else c >> 1;
        e.* = c;
    }
    break :blk t;
};

fn crc32(data: []const u8) u32 {
    var c: u32 = 0xFFFFFFFF;
    for (data) |b| c = crc_table[(c ^ b) & 0xFF] ^ (c >> 8);
    return ~c;
}

/// See the English guide for context.
fn dot(comptime N: usize, a: [N]f32, b: [N]f32) f32 {
    var s: f32 = 0;
    inline for (0..N) |i| s += a[i] * b[i];
    return s;
}

test "comptime LUT" {
    try std.testing.expectEqual(std.hash.Crc32.hash("hello"), crc32("hello"));
    try std.testing.expectEqual(@as(f32, 11), dot(2, .{ 1, 2 }, .{ 3, 4 }));
}
```

**Not a good fit:** large tables increase binary size and compile time. A table larger than L1/L2 cache may be slower than computing the values.

### 5.2 SIMD: `@Vector`

- `@Vector(N, T)` supports element-wise arithmetic, comparisons (which return `@Vector(N, bool)`), `@reduce`, `@shuffle`, `@select`, and `@splat`.
- Arrays and vectors can be converted directly, for example `const v: V = arr[i..][0..N].*;`. Since 0.16, runtime vector indexing is disallowed; convert to an array before accessing individual elements.
- `std.simd.suggestVectorLength(T)` returns a compile-time lane count recommended for the target CPU.
- **LLVM loop auto-vectorization is disabled in 0.16/0.17** to avoid miscompilations. It is expected to return with LLVM 23 in 0.18. A loop that previously auto-vectorized in ReleaseFast may now be slower; write hot loops with explicit `@Vector` when measurements justify it.
- Standard library routines such as `std.mem.findScalar` (formerly `indexOfScalar`) already use vectorization. Prefer them first.

#### Prefer `std.mem.findScalar` / `eql` before hand-rolled byte loops

`findScalarPos` (`lib/std/mem.zig` ~L1309–1370 @ `8f0c6ce4`) walks with unrolled 2×`@Vector` blocks, `@reduce(.Or)`, `simd.firstTrue`, then tapering lengths, then a scalar tail. Lane width comes from `std.simd.suggestVectorLength`. Hand-written `for` + `==` on `[]u8` rarely beats this and often loses when auto-vectorization is off.

`eql` for unique-representation types routes through `eqlBytes` (~L839+): length/`ptr` fast outs, ≤16-byte XOR corners, then chunked vector (or `usize`) scan with an overlapping last chunk. Prefer `std.mem.eql` over element loops for bytes and POD.

**Evidence (corpus / U):** `mem.zig` `findScalarPos`, `eql`/`eqlBytes`; no local findScalar-vs-naive JSONL yet (open in `zig-lang-perf-patterns.md`). **Evidence (local, related):** p16 measures explicit `@Vector` sum vs scalar under disabled auto-vectorization — not a findScalar shootout.

> Example: `examples/p02_simd.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

const lanes = std.simd.suggestVectorLength(f32) orelse 4;
const V = @Vector(lanes, f32);

/// See the English guide for context.
fn sum(xs: []const f32) f32 {
    var acc: V = @splat(0);
    var i: usize = 0;
    while (i + lanes <= xs.len) : (i += lanes) {
        const v: V = xs[i..][0..lanes].*;
        acc += v;
    }
    var s = @reduce(.Add, acc);
    while (i < xs.len) : (i += 1) s += xs[i];
    return s;
}

/// See the English guide for context.
fn findByte(hay: []const u8, needle: u8) ?usize {
    const n = 16;
    const B = @Vector(n, u8);
    const nv: B = @splat(needle);
    var i: usize = 0;
    while (i + n <= hay.len) : (i += n) {
        const chunk: B = hay[i..][0..n].*;
        const mask: u16 = @bitCast(chunk == nv);
        if (mask != 0) return i + @ctz(mask);
    }
    while (i < hay.len) : (i += 1) if (hay[i] == needle) return i;
    return null;
}

test "simd" {
    var xs: [37]f32 = undefined;
    for (&xs, 0..) |*x, i| x.* = @floatFromInt(i);
    try std.testing.expectEqual(@as(f32, 666), sum(&xs));
    try std.testing.expectEqual(@as(?usize, 20), findByte("aaaaaaaaaaaaaaaaaaaaXaaa", 'X'));
    try std.testing.expectEqual(@as(?usize, 20), std.mem.findScalar(u8, "aaaaaaaaaaaaaaaaaaaaXaaa", 'X'));
}

test "@shuffle / @select" {
    const a: @Vector(4, i32) = .{ 1, 2, 3, 4 };
    const b: @Vector(4, i32) = .{ 10, 20, 30, 40 };
    const rev = @shuffle(i32, a, undefined, @Vector(4, i32){ 3, 2, 1, 0 });
    try std.testing.expectEqual(@Vector(4, i32){ 4, 3, 2, 1 }, rev);
    const mx = @select(i32, a > @as(@Vector(4, i32), @splat(2)), a, b);
    try std.testing.expectEqual(@Vector(4, i32){ 10, 20, 3, 4 }, mx);
}
```

**Evidence (local):** `examples/p16_simd_vs_scalar.zig` compares a scalar `f32` sum to an explicit `@Vector(suggestVectorLength(f32), f32)` + `@reduce(.Add)` loop over N=8e6 (4 passes, best-of-7, `-O fast`). Auto-vectorization remains off in 0.17, so the scalar path is not LLVM-vectorized. JSONL: `zig-perf-research/bench-results/p16_simd_vs_scalar.jsonl` (re-run before citing).

**Dispatch problem:** Vector width and instruction set are fixed at compile time. A binary built with `-Dcpu=native` may crash on an older CPU; a baseline build cannot use AVX2/AVX-512. Ghostty and Bun use Google Highway (C++) for runtime CPUID dispatch in their hottest paths. Bun's PR reports about 40% faster JavaScript parsing with inline source maps. The Zig community library `oma` compiles hot functions for x86-64-v2/v3/v4 and selects one at startup. Zig's function multiversioning proposal is [#1018](https://github.com/ziglang/zig/issues/1018).

#### Comptime CPU-feature select (AES template)

When one ISA path is enough per **binary**, gate with `builtin.cpu.has` at comptime and `@import` the matching module — zero runtime ifunc. `lib/std/crypto/aes.zig` picks aesni / armcrypto / soft that way and exposes `has_hardware_support`. Complementary to Highway-style runtime dispatch: use comptime gates for crypto and always-on SIMD helpers; use runtime multiversioning when one build must run across CPU generations.

**Evidence (corpus / U):** `crypto/aes.zig` L1–30. No local AES GB/s table here.

Sources: [0.16: loop vectorization disabled and runtime vector indices forbidden](https://ziglang.org/download/0.16.0/release-notes.html) · [0.17 loop vectorization](https://ziglang.org/download/0.17.0/release-notes.html) · [Bun PR #19134](https://github.com/oven-sh/bun/pull/19134) · [Mitchell Hashimoto on Highway in Ghostty](https://whnex.com/items/49012420) · [oma](https://github.com/ATTron/oma) · `lib/std/simd.zig` · `lib/std/mem.zig` · `lib/std/crypto/aes.zig`

### 5.3 Branchless code

For unpredictable data, such as comparisons over random values, a branch misprediction can cost more than a few extra arithmetic instructions. Common options include counting with `@intFromBool(cond)`, using `@min`, `@max`, and `@abs` (often compiled to conditional moves or min/max instructions), and selecting vector values with `@select`.

> Example: `examples/p03_branchless.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
fn countLess(xs: []const u32, pivot: u32) usize {
    var n: usize = 0;
    for (xs) |x| n += @intFromBool(x < pivot);
    return n;
}

fn clampAll(xs: []i32, lo: i32, hi: i32) void {
    for (xs) |*x| x.* = @min(@max(x.*, lo), hi);
}

fn absBranchless(x: i32) u32 {
    const m = x >> 31;
    return @bitCast((x ^ m) -% m);
}

test "branchless" {
    try std.testing.expectEqual(@as(usize, 2), countLess(&.{ 5, 1, 9, 3 }, 4));
    var a = [_]i32{ -5, 3, 99 };
    clampAll(&a, 0, 10);
    try std.testing.expectEqualSlices(i32, &.{ 0, 3, 10 }, &a);
    try std.testing.expectEqual(@as(u32, 7), absBranchless(-7));
    try std.testing.expectEqual(@as(u32, 7), @abs(@as(i32, -7)));
}
```

**Not a good fit:** when a branch is highly predictable, such as 99% of inputs taking the same path, an ordinary `if` is often faster. Branchless code may calculate both sides. Use `@branchHint(.unpredictable)` when the compiler needs to know a branch is hard to predict.

### 5.4 Labeled switches for interpreters and state machines

Since 0.14, `continue :label next_value` can jump back to a labeled switch. Each `continue` becomes a separate branch point, similar to computed goto or threaded code, so the CPU branch predictor can distinguish the source state. When operands are known at compile time, the branch can become an unconditional jump. Zig's tokenizer became 13% faster after adopting this pattern.

> Example: `examples/p04_labeled_switch.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

const Op = enum(u8) { push, add, mul, halt };

/// See the English guide for context.
/// See the English guide for context.
/// See the English guide for context.
fn run(code: []const u8) i64 {
    var stack: [16]i64 = undefined;
    var sp: usize = 0;
    var pc: usize = 0;
    loop: switch (@as(Op, @fromBackingInt(code[pc]))) {
        .push => {
            std.debug.assert(sp < stack.len);
            stack[sp] = code[pc + 1];
            sp += 1;
            pc += 2;
            continue :loop @fromBackingInt(code[pc]);
        },
        .add => {
            std.debug.assert(sp >= 2);
            sp -= 1;
            stack[sp - 1] += stack[sp]; // zbc-disable-line: index-minus-one-without-zero-guard
            pc += 1;
            continue :loop @fromBackingInt(code[pc]);
        },
        .mul => {
            std.debug.assert(sp >= 2);
            sp -= 1;
            stack[sp - 1] *= stack[sp]; // zbc-disable-line: index-minus-one-without-zero-guard
            pc += 1;
            continue :loop @fromBackingInt(code[pc]);
        },
        .halt => {
            std.debug.assert(sp >= 1);
            return stack[sp - 1]; // zbc-disable-line: index-minus-one-without-zero-guard
        },
    }
}

test "labeled switch interpreter" {
    const P = @backingInt(Op.push);
    const code = [_]u8{ P, 2, P, 3, @backingInt(Op.add), P, 4, @backingInt(Op.mul), @backingInt(Op.halt) };
    try std.testing.expectEqual(@as(i64, 20), run(&code));
}
```

**Evidence (local):** `examples/p18_labeled_switch.zig` — tiny stack VM (push/add, 200k adds × 4 passes, best-of-7, `-O fast`): `while`+`switch` vs labeled `continue :loop` vs fn-ptr opcode table. On this machine the two switches are within noise (~1.2 ns/dispatch); the fn-ptr table is ~**5×** slower. Order-of-magnitude **L** only; the upstream “tokenizer +13%” claim is **U** (not re-measured here). JSONL: `zig-perf-research/bench-results/p18_labeled_switch.jsonl`.

**Corpus proof:** `lib/std/zig/tokenizer.zig` `next` uses labeled `state: switch` + `continue :state`; keywords go through `StaticStringMap`. The “+13%” figure is **U** (0.14 release notes), not re-measured on this machine (see p18).

Sources: [0.14 labeled switches](https://ziglang.org/download/0.14.0/release-notes.html#Labeled-Switch) · `lib/std/zig/tokenizer.zig`

### 5.5 Branch hints and prefetching

- `@branchHint(.likely | .unlikely | .cold | .unpredictable | .none)` must be the **first statement** in a block or function body. At the start of a function, it describes the function as a whole. `.cold` allows the optimizer to place code on a separate memory page.
- `@prefetch(ptr, .{ .rw, .locality, .cache })` changes performance but not program semantics; an invalid pointer is not itself illegal. TigerStyle recommends writing all options explicitly instead of relying on defaults.
- In ReleaseFast, `unreachable` and `std.debug.assert` become optimizer assumptions. Violating them is undefined behavior.

> Example: `examples/p05_hints.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

fn parseDigit(c: u8) !u4 {
    if (c < '0' or c > '9') {
        @branchHint(.cold);
        return error.InvalidDigit;
    }
    return @intCast(c - '0');
}

fn reportError(msg: []const u8) void {
    @branchHint(.cold);
    std.log.err("{s}", .{msg});
}

fn sumWithPrefetch(xs: []const u64) u64 {
    var s: u64 = 0;
    for (xs, 0..) |x, i| {
        if (i + 64 < xs.len) {
// See the English guide for context.
            @prefetch(&xs[i + 64], .{ .rw = .read, .locality = 3, .cache = .data });
        }
        s +%= x;
    }
    return s;
}

test "hints" {
    try std.testing.expectEqual(@as(u4, 7), try parseDigit('7'));
    try std.testing.expectError(error.InvalidDigit, parseDigit('x'));
    var xs: [200]u64 = undefined;
    for (&xs, 0..) |*x, i| x.* = i;
    try std.testing.expectEqual(@as(u64, 19900), sumWithPrefetch(&xs));
    _ = &reportError;
}
```

**Not a good fit:** manual prefetching rarely helps sequential access that hardware prefetchers already recognize and may make it slower. Try it only for irregular access such as pointer chasing or indirect indexing, and measure the result.

Sources: [0.14 `@branchHint`](https://ziglang.org/download/0.14.0/release-notes.html#New-branchHint-Builtin-Replacing-setCold) · [Language reference: `@prefetch`](https://ziglang.org/documentation/0.17.0/#prefetch)

### 5.6 Loop shape, inlining, and parameters

- **Move hot loops into standalone functions that take raw parameters instead of `self`** (TigerStyle). The compiler no longer needs to prove that an alias cannot modify `self.field` before keeping it in a register. The code is also easier to inspect for repeated work.
- **Use multiple accumulators or unroll loops** when measurements show a dependency chain is limiting throughput. `inline for` can create a fixed number of independent accumulators. Unrolling increases code size and instruction-cache pressure.
- **`inline fn` is a language guarantee, not a hint.** The language reference calls it “semantic inlining”; compile-time-known arguments are compile-time-known inside the function. It can increase binary size and compile time, and can even hurt runtime performance. Usually let the compiler decide; use it when compile-time propagation or a specific stack-frame shape is required.
- Pass large structs as `*const T` when they exceed 16 bytes and copying is not intended (TigerStyle). “Push ifs up, fors down”: move branches outside loops and move loops into batch-processing functions.
- **Initialize large structs in place:** `fn init(self: *Big) void { self.* = .{...}; }` avoids constructing a temporary on the stack and copying it (TigerStyle).

> Example: `examples/p09_hot_loop.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

const Mesh = struct {
    xs: []f32,
    scale: f32,

/// See the English guide for context.
    fn scaleSlow(self: *Mesh) void {
        for (self.xs) |*x| x.* *= self.scale;
    }
/// See the English guide for context.
    fn scaleFast(self: *Mesh) void {
        scaleKernel(self.xs, self.scale);
    }
};

fn scaleKernel(xs: []f32, scale: f32) void {
    for (xs) |*x| x.* *= scale;
}

/// See the English guide for context.
fn sum4(xs: []const u64) u64 {
    var acc: [4]u64 = @splat(0);
    var i: usize = 0;
    while (i + 4 <= xs.len) : (i += 4) {
        inline for (0..4) |k| acc[k] +%= xs[i + k];
    }
    var s = acc[0] +% acc[1] +% acc[2] +% acc[3];
    for (xs[i..]) |x| s +%= x;
    return s;
}

/// See the English guide for context.
const Big = struct { data: [256]u8 };
fn checksum(b: *const Big) u32 {
    var s: u32 = 0;
    for (b.data) |x| s +%= x;
    return s;
}

/// See the English guide for context.
inline fn sq(x: f32) f32 {
    return x * x;
}

test "hot loops" {
    var data = [_]f32{ 1, 2, 3 };
    var m: Mesh = .{ .xs = &data, .scale = 2 };
    m.scaleSlow();
    m.scaleFast();
    try std.testing.expectEqual(@as(f32, 12), data[2]);
    try std.testing.expectEqual(@as(u64, 15), sum4(&.{ 1, 2, 3, 4, 5 }));
    const big: Big = .{ .data = @splat(1) };
    try std.testing.expectEqual(@as(u32, 256), checksum(&big));
    try std.testing.expectEqual(@as(f32, 9), sq(3));
}
```

Sources: [TigerStyle: Performance and Cache Invalidation](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md#performance) · [matklad: Push Ifs Up And Fors Down](https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html) · [Language reference: `inline fn`](https://ziglang.org/documentation/0.17.0/#inline-fn)

### 5.7 Local safety settings and floating-point modes

- `@setRuntimeSafety(false)` applies to its enclosing scope. A nested scope can override it. In ReleaseSafe, use it only to disable bounds and overflow checks in a verified hot section; ReleaseFast already disables them. Keep the scope as small as possible. zperf-lint rule zp-broad-runtime-safety reports uses that cover a large function body.
- `@setFloatMode(.optimized)` allows assumptions such as no NaN/Inf, ignoring the sign of zero, replacing division with a reciprocal, and floating-point contraction such as FMA. It is similar to `-ffast-math` and can produce small differences from strict IEEE behavior.
- `@mulAdd(T, a, b, c)` requests an explicit FMA.

> Example: `examples/p07_safety.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
fn sumUnchecked(xs: []const u32) u32 {
    @setRuntimeSafety(false);
    var s: u32 = 0;
    for (xs) |x| s += x;
    return s;
}

fn dotFast(a: []const f32, b: []const f32) f32 {
    @setFloatMode(.optimized);
    std.debug.assert(a.len == b.len);
    var s: f32 = 0;
    for (a, b) |x, y| s += x * y;
    return s;
}

test "safety toggles" {
    try std.testing.expectEqual(@as(u32, 6), sumUnchecked(&.{ 1, 2, 3 }));
    try std.testing.expectApproxEqAbs(@as(f32, 11), dotFast(&.{ 1, 2 }, &.{ 3, 4 }), 1e-6);
    try std.testing.expectEqual(@as(f32, 7), @mulAdd(f32, 2, 3, 1));
}
```

**Not a good fit:** do not disable safety checks in code without test coverage or fuzzing. In Zig, violating the resulting assumptions can cause undefined behavior.

Source: [Language reference: `@setRuntimeSafety` and `@setFloatMode`](https://ziglang.org/documentation/0.17.0/#setRuntimeSafety)

### 5.8 Integer techniques

- **Avoid runtime integer division when it is a measured bottleneck.** LLVM can replace division by a compile-time constant with multiplication and shifts; division by a runtime value needs a division instruction. A power-of-two capacity lets `% cap` become `& (cap - 1)`.
- Wrapping arithmetic: `+%`, `-%`, `*%`. Saturating arithmetic: `+|`, `-|`, `*|`. Explicit overflow: `@addWithOverflow` and `@mulWithOverflow`.
- Bit-operation builtins include `@popCount`, `@clz`, `@ctz`, `@byteSwap`, and `@bitReverse`. Zig 0.17 added `@divCeil`, so code no longer needs `std.math.divCeil(...) catch unreachable`.
- TigerStyle also recommends `@divExact`, `@divFloor`, and `divCeil` to make rounding intent explicit.

> Example: `examples/p08_int_tricks.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
const Ring = struct {
    const cap = 1024;
    comptime {
        std.debug.assert(std.math.isPowerOfTwo(cap));
    }
    buf: [cap]u32 = undefined,
    head: u32 = 0,

    fn push(r: *Ring, v: u32) void {
        r.buf[r.head & (cap - 1)] = v;
        r.head +%= 1;
    }
};

test "整数技巧" {
    var r: Ring = .{};
    for (0..2000) |i| r.push(@intCast(i));
    try std.testing.expectEqual(@as(u32, 1999), r.buf[1999 & 1023]);

// See the English guide for context.
    const x: u32 = 1000;
    try std.testing.expectEqual(@as(u32, 142), x / 7);
    try std.testing.expectEqual(@as(u32, 3), @divCeil(@as(u32, 7), 3));
    try std.testing.expectEqual(@as(u32, 125), x >> 3);

    const r2 = @mulWithOverflow(@as(u8, 200), 2);
    try std.testing.expectEqual(@as(u1, 1), r2[1]);
    try std.testing.expectEqual(@as(u8, 255), @as(u8, 200) +| 100);
    try std.testing.expectEqual(@as(u32, 3), @popCount(@as(u32, 0b1011)));
    try std.testing.expectEqual(@as(u32, 28), @clz(@as(u32, 0b1011)));
    try std.testing.expectEqual(@as(u64, 0x0807060504030201), @byteSwap(@as(u64, 0x0102030405060708)));
    try std.testing.expectEqual(@as(u32, 16), try std.math.ceilPowerOfTwo(u32, 9));
}
```

### 5.9 `@memcpy`, `@memset`, and vectorized standard-library routines

`@memcpy(dest, src)` and `@memset(slice, value)` lower to optimized memcpy/memset implementations. `@memcpy` requires non-overlapping source and destination with equal lengths (checked in Debug/Safe); use `@memmove` when ranges overlap. Routines such as `std.mem.findScalar` and `std.mem.eql` are already optimized for vectors, so prefer them to handwritten byte loops — see §5.2 for `findScalarPos` / `eqlBytes` structure.

Substring search: `std.mem.find` uses Boyer–Moore–Horspool with a skip table (`mem.zig`), not a naive O(nm) scan. Prefer it for multi-byte needles.

### 5.10 Sorting: prefer `std.sort.pdq`

Default quality sort in std is **pdqsort** (`std.sort.pdq` / `lib/std/sort/pdq.zig`). Use `std.sort.block` when the block algorithm fits the constraint set in its docs; insertion-style helpers exist for tiny n. Do not reimplement quicksort in application code without a measured reason.

**Evidence (corpus / U):** `lib/std/sort.zig` exports; no local sort shootout in this repo.

---

