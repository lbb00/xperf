# zperf: Zig Performance Guide

Less memory, more throughput.

> **Target: Zig 0.17.0.** Examples under `examples/` are checked with Zig 0.17.0 on x86_64 Linux (`zig test` Debug and `-O fast`, or `zig build-exe`). Reproduce with `cd examples && zig build test`.
> Numbers come from release notes, original PRs, or are labeled as local measurements. Nothing is invented.
>
> Companion: `zperf-lint/` — static checks for performance and memory anti-patterns (Chapter 9).

## Contents

- [0. Version notes: performance changes from 0.14 to 0.17](#0-version-notes-performance-changes-from-014-to-017)
- [1. Method: measure before changing code](#1-method-measure-before-changing-code)
- [2. Memory](#2-memory)
- [3. C memory techniques and their Zig equivalents](#3-c-memory-techniques-and-their-zig-equivalents)
- [4. Case study: reducing the memory used by a hybrid car](#4-case-study-reducing-the-memory-used-by-a-hybrid-car)
- [5. Computation](#5-computation)
- [6. Concurrency and I/O](#6-concurrency-and-io)
- [7. Builds and tooling](#7-builds-and-tooling)
- [8. Measurement and verification](#8-measurement-and-verification)
- [9. zperf-lint: find anti-patterns automatically](#9-zperf-lint-find-anti-patterns-automatically)
- [10. Quick reference](#10-quick-reference)
- [References](#references)

---

## 0. Version notes: performance changes from 0.14 to 0.17

Zig is pre-1.0; releases can break APIs. Tutorials aimed at 0.11–0.13 often no longer compile. The table below lists changes that matter for this guide (from the official release notes).

| Version | Change | Impact |
|---|---|---|
| 0.14 | `@branchHint(.likely/.unlikely/.cold/.unpredictable)` replaces `@setCold` | Branch hints use the new builtin |
| 0.14 | Labeled switches support `continue :label value` | Efficient interpreter and state-machine dispatch; the tokenizer became 13% faster |
| 0.14 | `GeneralPurposeAllocator` was rewritten and renamed `DebugAllocator`; `SmpAllocator` was added | Allocator selection changed |
| 0.14 | The Allocator vtable gained `remap`; `page_allocator` gained `mremap` support | ArrayList growth may avoid copying |
| 0.15 | **Writergate** introduced `std.Io.Writer` and `Reader`; callers provide buffers and must flush | I/O buffering APIs changed |
| 0.15 | `std.ArrayList` became unmanaged by default; `BoundedArray`, `LinearFifo`, and `RingBuffer` were removed | Container APIs changed |
| 0.16 | **I/O as an Interface** requires an `Io` value for I/O; `pub fn main(init: std.process.Init)` is the new entry point | Files, timers, and threads use `Io` |
| 0.16 | `std.Thread.Pool` was removed in favor of `Io.Group`, `io.async`, and `io.concurrent` | Parallel task APIs changed |
| 0.16 | `ArenaAllocator` became thread-safe and lock-free; `ThreadSafeAllocator` was removed | An arena can be shared across threads |
| 0.16 | `std.mem.indexOf*` was renamed to `find*`; hash maps continued the move to unmanaged containers | APIs changed |
| 0.16 / 0.17 | LLVM loop auto-vectorization was disabled to avoid miscompilations; restoration is expected in 0.18 | Explicit `@Vector` use matters more |
| 0.16 | Pointers in packed structs and unions, and runtime vector indexing, were disallowed | Packing and vector access changed |
| 0.17 | `DebugAllocator` was deprecated in favor of `SafeAllocator`, which is thread-safe and reports leaks | Debug allocator selection changed |
| 0.17 | `StackFallbackAllocator` and `std.heap.stackFallback` became `BufferFirstAllocator` | Small-buffer optimization API changed |
| 0.17 | `@backingInt` and `@fromBackingInt` replaced `@intFromEnum` and `@enumFromInt`; `@divCeil` was added | Handle, index, and division code changed |
| 0.17 | Array repetition `a ** n` was removed in favor of `@splat` | Array initialization changed |
| 0.17 | `std.builtin` became `std.lang`; `OptimizeMode` became `Optimize`, with `.debug/.safe/.fast/.small` tags; the CLI uses `-O fast` | Build scripts changed |
| 0.17 | `@bitCast` now reinterprets logical bit representations and no longer accepts extern structs; `fmt.allocPrint` became `Allocator.print`; bit-set types were renamed to `Integer`, `Static`, and `Dynamic` | Bit operations and formatting changed |

Comments beginning with `// 0.1x:` in the examples mark version-specific differences.

Sources: [0.14.0 release notes](https://ziglang.org/download/0.14.0/release-notes.html) · [0.15.1 release notes](https://ziglang.org/download/0.15.1/release-notes.html) · [0.16.0 release notes](https://ziglang.org/download/0.16.0/release-notes.html) · [0.17.0 release notes](https://ziglang.org/download/0.17.0/release-notes.html) · [downloads](https://ziglang.org/download/)

---

## 1. Method: measure before changing code

TigerBeetle's TigerStyle order:

1. **Estimate at design time.** Bandwidth and latency for network, disk, memory, and CPU. The largest reported gains (up to 1000×) come from design changes, before profiling is possible.
2. **Fix the slowest resource first** (network > disk > memory > CPU), weighted by frequency. A cache miss repeated often enough can cost as much as an `fsync`.
3. **Batch.** Amortize network, disk, memory, and CPU across batches; give the CPU large, predictable units of work.
4. **Make hot work explicit.** e.g. a hot loop as a standalone function with raw parameters instead of `self` (see §5.6).

Andrew Kelley's *Practical Data-Oriented Design*: **less memory can mean faster code** — fewer allocations and better cache use. This guide starts with memory, then computation.

Sources: [TigerStyle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md) · [Practical Data-Oriented Design (Handmade Seattle 2021)](https://handmade-seattle.com/media-sub/practical-data-oriented-design) · [Zig PR #7920](https://github.com/ziglang/zig/pull/7920)

## 2. Memory

### 2.1 Choose the right allocator

Zig has no implicit global allocator. Allocation APIs take a `std.mem.Allocator` explicitly, so the caller can swap allocators without rewriting business logic.

| Allocator | Use | Notes (verified against Zig 0.17 source) |
|---|---|---|
| `std.heap.smp_allocator` | General allocator for multithreaded ReleaseFast programs | Global singleton; **size-class freelists per thread**; large blocks use `mmap`. Thread metadata is `align(std.atomic.cache_line)` to avoid false sharing (`lib/std/heap/SmpAllocator.zig`). Asserts `!builtin.single_threaded`. Zig reports performance comparable to glibc malloc during self-hosting. |
| `std.heap.c_allocator` | Programs already linked with libc | Requires `link_libc`; otherwise compilation fails. Calls `malloc` and `free` directly. |
| `std.heap.page_allocator` | Large, long-lived allocations, or as an arena's backing allocator | Page-aligns every allocation and issues an `mmap` system call. Do not use it for small objects. |
| `std.heap.ArenaAllocator` | Groups of allocations with the same lifetime, such as a request, frame, or compilation unit | Thread-safe and lock-free since 0.16. Individual frees are mostly ineffective; `deinit` or `reset` reclaims memory in one operation. |
| `std.heap.FixedBufferAllocator` | Known upper bounds and no heap allocations | Returns `error.OutOfMemory` when full; `reset()` is O(1). |
| `std.heap.BufferFirstAllocator` | Small-buffer optimization: use a supplied buffer first, then fall back to a general allocator | New name in 0.17; previously `StackFallbackAllocator`. |
| `std.heap.MemoryPool(T)` | Frequent creation and destruction of many objects of one type | Uses an arena and free list; `initCapacity` prewarms it. |
| `std.heap.SafeAllocator` | Debug and ReleaseSafe builds that need leak and double-free checks | Replaced the deprecated `DebugAllocator` in 0.17; `deinit()` returns the leak count. |
| `std.heap.wasm_allocator` | WebAssembly | |

**Juicy Main defaults.** With `pub fn main(init: std.process.Init)`, `init.gpa` is `SafeAllocator` in Debug/Safe. In Fast/Small it picks `c_allocator` (if libc is linked), else `wasm_allocator`, else `smp_allocator`. `init.arena` is a process-wide arena backed by `page_allocator` (`lib/std/start.zig`).

To select an allocator yourself, for example in a library test harness or without Juicy Main:

> Example: `examples/m12_gpa_select.zig` (checked with Zig 0.17.0 using `zig run`).

```zig
const std = @import("std");
const builtin = @import("builtin");

/// See the English guide for context.
/// See the English guide for context.
var safe_state: std.heap.SafeAllocator = .init(std.heap.page_allocator, .{});

pub fn main() !void {
    const gpa, const is_safe = switch (builtin.mode) {
        .debug, .safe => .{ safe_state.allocator(), true },
// See the English guide for context.
        .fast, .small => .{ if (builtin.link_libc) std.heap.c_allocator else if (!builtin.single_threaded) std.heap.smp_allocator else std.heap.page_allocator, false },
    };
    defer if (is_safe) {
        const leaks = safe_state.deinit();
        if (leaks != 0) std.process.exit(1);
    };

    const xs = try gpa.alloc(u64, 1000);
    defer gpa.free(xs);
    @memset(xs, 0);
}
```

Do not hard-code an allocator in a library. Accept an `Allocator` parameter and let the caller choose.

Sources: [0.14 SmpAllocator and DebugAllocator](https://ziglang.org/download/0.14.0/release-notes.html#SmpAllocator) · [0.16 lock-free ArenaAllocator](https://ziglang.org/download/0.16.0/release-notes.html) · [0.17 SafeAllocator](https://ziglang.org/download/0.17.0/release-notes.html) · `lib/std/heap.zig`, `lib/std/heap/SmpAllocator.zig`, and `lib/std/start.zig` (0.17.0)

**Evidence (local):** `examples/p14_alloc_shootout.zig` compares smp/c GPA alloc+free, `ArenaAllocator.reset(.retain_capacity)`, and `FixedBufferAllocator.reset` for a fixed 8×64-byte per-request pattern. JSONL: `zig-perf-research/bench-results/p14_alloc_shootout.jsonl` on this machine (re-run before citing; see that directory’s README).

**SmpAllocator layout (corpus):** Each `Thread` slot pads with `_: void align(std.atomic.cache_line) = {}`, then holds per–size-class `next_addrs` / `frees` freelist heads (`zig-corpus/zig` @ `8f0c6ce4`, `lib/std/heap/SmpAllocator.zig` ~L48–95). Same false-sharing lesson as §6.1, baked into the default multithreaded heap. Prefer it over inventing a parallel freelist unless you need a different size-class policy.

### 2.2 Arena plus `reset(.retain_capacity)`: reusable allocations in a loop

For workloads that allocate and discard a batch at a time (requests, frames, batches), keep one arena and call `reset(.retain_capacity)` at the end of each batch. That resets the arena pointer and keeps capacity already taken from the OS. In steady state you often avoid further system calls and fragmentation.

`ArenaAllocator.ResetMode` (Zig 0.17) offers three policies:

| Mode | Effect | When |
|---|---|---|
| `.retain_capacity` | Keep all previously acquired capacity | Steady request/frame size |
| `.retain_with_limit = N` | Same, but shrink retained capacity to at most N bytes | Keepalive / long-lived connections where one huge body must not pin peak RSS |
| `.free_all` | Release everything back to the child allocator | Shutdown, or you explicitly want the OS pages back |

Unbounded `.retain_capacity` on a connection that occasionally sees a multi-megabyte body can **ratchet** RSS: after the spike the arena still holds the peak. Cap the retain size. http.zig's `requestDone` does `req_arena.reset(.{ .retain_with_limit = retain_allocated_bytes })` (a few KiB by default, configurable). Upstream [http.zig#176](https://github.com/karlseguin/http.zig/issues/176) reported RSS growing with concurrency when retain and pool limits were missing.

> Example: `examples/m01_arena.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
fn handleRequests(gpa: std.mem.Allocator, requests: []const []const u8) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();

    var total: usize = 0;
    for (requests) |req| {
// See the English guide for context.
        defer _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();

        const upper = try arena.alloc(u8, req.len);
        for (upper, req) |*d, s| d.* = std.ascii.toUpper(s);
        const msg = try arena.print("{s}!", .{upper}); // 0.17: fmt.allocPrint -> Allocator.print
        total += msg.len;
    }
    return total;
}

test "arena retain_capacity" {
    const reqs = [_][]const u8{ "get", "post", "delete" };
    try std.testing.expectEqual(@as(usize, 16), try handleRequests(std.testing.allocator, &reqs));
}
```

> Example: `examples/m16_arena_retain_limit.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// Keepalive-style request loop: reset with a byte cap so one huge request
/// does not pin peak RSS forever. See Zig ArenaAllocator.ResetMode.retain_with_limit
/// and http.zig requestDone → retain_with_limit (MIT).
fn handleWithBound(gpa: std.mem.Allocator, bodies: []const []const u8, retain_limit: usize) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();

    var total: usize = 0;
    for (bodies) |body| {
        defer _ = arena_state.reset(.{ .retain_with_limit = retain_limit });
        const arena = arena_state.allocator();
        const copy = try arena.dupe(u8, body);
        total += copy.len;
    }
    return total;
}

test "arena retain_with_limit" {
    var big: [200]u8 = undefined;
    @memset(&big, 'x');
    const bodies = [_][]const u8{ "small", &big, "again" };
    const n = try handleWithBound(std.testing.allocator, &bodies, 64);
    try std.testing.expectEqual(@as(usize, 5 + 200 + 5), n);
}
```

**Evidence (upstream):** [http.zig#176](https://github.com/karlseguin/http.zig/issues/176) (RSS steps under burst concurrency); http.zig `src/worker.zig` `requestDone` → `retain_with_limit`. **Evidence (API):** `lib/std/heap/ArenaAllocator.zig` `ResetMode`. Local RSS-after-keepalive microbench is still open (see `zig-perf-research/import-backlog.md`).

**Not a good fit:** unrelated lifetimes, or per-object free. A long-lived arena without a retain limit can grow without bound.

### 2.3 FixedBufferAllocator and BufferFirstAllocator: allocators backed by a stack buffer

> Example: `examples/m02_fba.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

test "FixedBufferAllocator: 零堆分配" {
    var buf: [4096]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buf);
    const a = fba.allocator();

    var list: std.ArrayList(u32) = .empty;
    try list.appendSlice(a, &.{ 1, 2, 3 });
    try std.testing.expectEqual(@as(usize, 3), list.items.len);

// See the English guide for context.
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 8192));
    fba.reset();
}
```

In 0.17, `BufferFirstAllocator` packages small-buffer optimization as an allocator. It uses the supplied buffer first and falls back to a general allocator when the buffer is too small.

> Example: `examples/m03_buffer_first.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
fn joinPath(gpa: std.mem.Allocator, parts: []const []const u8) !usize {
    var stack_buf: [256]u8 = undefined;
    var sfa: std.heap.BufferFirstAllocator = .init(&stack_buf, gpa);
    const a = sfa.allocator();
    const joined = try std.mem.join(a, "/", parts);
    defer a.free(joined);
    return joined.len;
}

test "BufferFirstAllocator" {
    try std.testing.expectEqual(@as(usize, 7), try joinPath(std.testing.allocator, &.{ "usr", "bin" }));
    const big: [1000]u8 = @splat('x');
    try std.testing.expectEqual(@as(usize, 2001), try joinPath(std.testing.allocator, &.{ &big, &big }));
}
```

**Recipe.** Size the stack (or caller-owned) buffer for the **common** path — path joins, short format, header parse — then pass a long-lived GPA/arena as `fallback_allocator`. Hot calls stay off the heap when they fit; overflow still works. Implementation (`lib/std/heap/BufferFirstAllocator.zig`): `alloc` tries `FixedBufferAllocator` first, else `fallback.rawAlloc`; `resize` / `remap` / `free` route by `ownsPtr` on the fixed buffer so fallback-owned slabs are not mistaken for stack bytes.

| Choice | When |
|---|---|
| `FixedBufferAllocator` alone | Hard upper bound; OOM is a bug or a reject |
| `BufferFirstAllocator` | Usually small, occasionally large |
| Arena / GPA only | Unbounded or already pooled |

**Evidence (API / corpus):** `BufferFirstAllocator.zig` @ `8f0c6ce4`. **Evidence (local):** `m03_buffer_first.zig` compiles the pattern (no timing). A BufferFirst hit-rate microbench vs FBA-only vs GPA is still open (`zig-perf-research/zig-lang-perf-patterns.md` P0 bench). Do not invent hit-rate numbers.

**Watch stack use.** The OS controls the main-thread stack (often 8 MiB on Linux). `std.Thread.spawn` uses `SpawnConfig.stack_size` (16 MiB by default in 0.17). Large stack buffers can overflow. `zig build-exe -fstack-report` reports per-function stack use, and `--stack <size>` adjusts the main-thread stack.

### 2.4 MemoryPool: O(1) allocation for objects of one type

> Example: `examples/m04_pool.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

const Node = struct { value: u64, next: ?*Node };

test "MemoryPool: 定长对象 O(1) 分配/回收，free list 复用" {
    const gpa = std.testing.allocator;
    var pool: std.heap.MemoryPool(Node) = try .initCapacity(gpa, 64);
    defer pool.deinit(gpa);

    const a = try pool.create(gpa);
    a.* = .{ .value = 1, .next = null };
    pool.destroy(a);
    const b = try pool.create(gpa);
    try std.testing.expect(a == b);
}
```

In 0.17, `memory_pool.Options` supports `.growable = false`: prewarm, then freeze capacity for a static policy. Ghostty's write path checks `Write` objects out of a `std.heap.MemoryPool(Write)` around async I/O completion (`termio/Exec.zig`) — same pattern for short-lived, fixed-size hot-path objects.

#### Size-class buffer pools (`tryAlloc`)

`MemoryPool(T)` covers one type. Servers often need many **equal-sized byte buffers** (headers, bodies, frames). Preallocate `count` buffers of length `buf_len`, then:

1. **`tryAlloc`** — pooled buffer or `null` (no heap fallback on the hot path).
2. Empty pool or oversized request — allocate dynamically; count misses (`alloc_buffer_empty` / large-path metrics in http.zig).
3. **Release** — push the buffer back on the free stack.

Common sizes stay in the pool; outliers go elsewhere. Contended checkout is a later problem ([http.zig#199](https://github.com/karlseguin/http.zig/issues/199)); get the pool correct before lock-free indexing.

> Example: `examples/m15_buffer_pool.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// Equal-size buffer pool with tryAlloc (no fallback).
/// API shape inspired by http.zig Buffer.Pool (MIT); original teaching code.
const BufferPool = struct {
    buffers: [][]u8,
    available: usize,
    buf_len: usize,

    fn init(gpa: std.mem.Allocator, count: usize, buf_len: usize) !BufferPool {
        const buffers = try gpa.alloc([]u8, count);
        errdefer gpa.free(buffers);
        for (buffers) |*slot| {
            // zperf-lint: ignore zp-alloc-in-loop -- one-time pool warm-up, not a hot-path pattern
            slot.* = try gpa.alloc(u8, buf_len);
        }
        return .{ .buffers = buffers, .available = count, .buf_len = buf_len };
    }

    fn deinit(self: *BufferPool, gpa: std.mem.Allocator) void {
        for (self.buffers) |b| gpa.free(b);
        gpa.free(self.buffers);
        self.* = undefined;
    }

    /// Hot path: never allocates. Null means the pool is empty.
    fn tryAlloc(self: *BufferPool) ?[]u8 {
        if (self.available == 0) return null;
        self.available -= 1;
        return self.buffers[self.available];
    }

    fn release(self: *BufferPool, buf: []u8) void {
        std.debug.assert(buf.len == self.buf_len);
        std.debug.assert(self.available < self.buffers.len);
        self.buffers[self.available] = buf;
        self.available += 1;
    }
};

test "buffer pool tryAlloc / release" {
    var pool = try BufferPool.init(std.testing.allocator, 2, 64);
    defer pool.deinit(std.testing.allocator);

    const a = pool.tryAlloc().?;
    const b = pool.tryAlloc().?;
    try std.testing.expect(pool.tryAlloc() == null);
    pool.release(a);
    pool.release(b);
    try std.testing.expect(pool.tryAlloc() != null);
}
```

**Evidence (upstream):** http.zig `src/buffer.zig` pool + metrics; [http.zig#199](https://github.com/karlseguin/http.zig/issues/199) (checkout contention). **Evidence (local):** `examples/p20_buffer_pool.zig` times always-hit `tryAlloc`/`release` vs same-size GPA `alloc`+`free` (4 KiB × 200k ops, best-of-7, `-O fast`). JSONL: `zig-perf-research/bench-results/p20_buffer_pool.jsonl` (re-run before citing). Miss / contended checkout not timed here.

### 2.5 Static allocation (TigerStyle)

TigerBeetle's rule: **allocate everything at startup; after init, do not allocate or free.** That removes allocation latency jitter and use-after-free from the steady state. Fix limits for queues, loops, and connection counts.

> Example: `examples/m11_static.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
const Server = struct {
    const connections_max = 128;
    const message_size_max = 4096;

    messages: []align(64) [message_size_max]u8,
    free: std.bit_set.Static(connections_max),

    fn init(gpa: std.mem.Allocator) !Server {
        const messages = try gpa.alignedAlloc([message_size_max]u8, .@"64", connections_max);
        return .{ .messages = messages, .free = .full };
    }
    fn deinit(s: *Server, gpa: std.mem.Allocator) void {
        gpa.free(s.messages);
        s.* = undefined;
    }
    fn acquire(s: *Server) ?u32 {
        const i = s.free.findFirstSet() orelse return null;
        s.free.unset(i);
        return @intCast(i);
    }
    fn release(s: *Server, i: u32) void {
        std.debug.assert(!s.free.isSet(i));
        s.free.set(i);
    }
};

test "static allocation" {
    comptime std.debug.assert(Server.message_size_max % 64 == 0);
    var s = try Server.init(std.testing.allocator);
    defer s.deinit(std.testing.allocator);
    const i = s.acquire().?;
    s.messages[i][0] = 42;
    s.release(i);
}
```

#### Enforce the phase with a wrapper allocator

TigerBeetle wraps the child allocator in a **phase machine** (`StaticAllocator`):

1. **`init`** — `alloc` / `resize` allowed (startup, including `errdefer` frees).
2. **`static`** — alloc/resize/free through the wrapper **assert** (steady state).
3. **`deinit`** — free allowed; alloc forbidden.

Call `transition_from_init_to_static()` after open, then transition again before teardown. The stub below shows the lifecycle without vendoring TigerBeetle's type.

> Example: `examples/m14_static_phases.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// Teaching stub: allocator that asserts a lifecycle phase.
/// Inspired by TigerBeetle's StaticAllocator (Apache-2.0); original code for the guide.
const Phase = enum { init, static, deinit };

const PhaseAllocator = struct {
    child: std.mem.Allocator,
    phase: Phase = .init,

    fn allocator(self: *PhaseAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn transitionToStatic(self: *PhaseAllocator) void {
        std.debug.assert(self.phase == .init);
        self.phase = .static;
    }

    fn transitionToDeinit(self: *PhaseAllocator) void {
        std.debug.assert(self.phase == .static);
        self.phase = .deinit;
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        std.debug.assert(self.phase == .init);
        return self.child.rawAlloc(len, alignment, ret_addr);
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        std.debug.assert(self.phase == .init);
        return self.child.rawResize(memory, alignment, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        std.debug.assert(self.phase == .init);
        return self.child.rawRemap(memory, alignment, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        // Allow free during init (errdefer) and deinit; forbid during static.
        std.debug.assert(self.phase != .static);
        self.child.rawFree(memory, alignment, ret_addr);
    }
};

test "phase allocator: alloc only in init" {
    var phase: PhaseAllocator = .{ .child = std.testing.allocator };
    const a = phase.allocator();
    const buf = try a.alloc(u8, 32);
    phase.transitionToStatic();
    // Steady-state: no more alloc/resize/free through this wrapper.
    phase.transitionToDeinit();
    a.free(buf);
}
```

#### Size the object / message pool from concurrency

Static allocation only works if the pool is **large enough to always make progress**. TigerBeetle's `MessagePool` sizes from worst-case concurrent holders: journal read/write IOPS, pipeline depth, connection send queues, grid repair reads, plus a small burst (+1) so a parse or ping cannot deadlock the replica. For any fixed-size frame pool:

1. List every concurrent holder (connections × in-flight, disk IOPS, pipelines, loops).
2. Add one for “holding a message while allocating the next”.
3. Assert `messages_max > 1` (and stronger invariants) at comptime when constants allow.
4. Prefer sector- or cache-line-aligned buffers when the pool feeds Direct I/O or hot DMA.

Manual check (not a lint): can every producer still get a buffer when every consumer is stalled at its documented maximum? If not, raise the constant or shed load — do not allocate mid-tick.

**Not a good fit:** tools with unknown input sizes, such as compilers and format converters. Arbitrary limits can create bugs. When `BoundedArray` was removed, the Zig release notes advised against guessing a limit: accept a caller-provided buffer or use dynamic allocation.

**Evidence (upstream):** TigerBeetle `src/static_allocator.zig`, `src/message_pool.zig` capacity calculus; [TIGER_STYLE Safety](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md#safety). Local steady-state p99 vs GPA mid-flight alloc is open on the import backlog.

Sources: [TigerStyle: Safety](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md#safety) · [0.15 removal of BoundedArray](https://ziglang.org/download/0.15.1/release-notes.html) · TigerBeetle `docs/concepts/performance.md`

### 2.6 Reserve first: grow once and remove allocation failures from the main path

Appending one item at a time can cause repeated growth and copying. A less obvious problem is that an out-of-memory error halfway through can leave a data structure partially updated. matklad's pattern is to **reserve the full capacity first, then use operations that cannot fail**, with `errdefer comptime unreachable` to let the compiler verify the later operations.

> Example: `examples/m09_reserve_first.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
fn appendPair(gpa: std.mem.Allocator, keys: *std.ArrayList(u32), vals: *std.ArrayList(u64), k: u32, v: u64) !void {
    try keys.ensureUnusedCapacity(gpa, 1);
    try vals.ensureUnusedCapacity(gpa, 1);
    errdefer comptime unreachable;
    keys.appendAssumeCapacity(k);
    vals.appendAssumeCapacity(v);
}

test "reserve first" {
    const gpa = std.testing.allocator;
    var keys: std.ArrayList(u32) = .empty;
    defer keys.deinit(gpa);
    var vals: std.ArrayList(u64) = .empty;
    defer vals.deinit(gpa);

    try keys.ensureTotalCapacity(gpa, 1000);
    try vals.ensureTotalCapacity(gpa, 1000);
    for (0..1000) |i| try appendPair(gpa, &keys, &vals, @intCast(i), i * 2);
    try std.testing.expectEqual(@as(u64, 1998), vals.items[999]);
}
```

zperf-lint rule zp-append-without-reserve checks for appends inside loops that lack a prior capacity reservation.

#### Empirical `ensureTotalCapacity` (parser / IR shape)

When the final length is unknown but **ratio to input size is stable**, reserve from that ratio instead of doubling through the parse. Zig's own AST parse does this (`lib/std/zig/Ast.zig` @ `8f0c6ce4`):

- tokens: `estimated_token_count = source.len / 8` then `tokens.ensureTotalCapacity`
- nodes: “Empirically, Zig source code has a 2:1 ratio of tokens to AST nodes” → `estimated_node_count = (tokens.len + 2) / 2`

Measure your format once (token/node counts vs bytes), bake the constant, keep a comment with the sample. Wrong constants only waste memory or re-grow — still better than append-without-ensure on huge inputs.

**Evidence (corpus):** `Ast.zig` ~L148–197. **Evidence (local):** none for the `/8` ratio (language-specific); treat as **U** pattern, not a universal constant.

Sources: [matklad: Reserve First](https://matklad.github.io/2025/08/16/reserve-first.html) · [matklad: Zig defer Patterns](https://matklad.github.io/2024/03/21/defer-patterns.html) · `lib/std/zig/Ast.zig`

### 2.7 Bounded stack lists (replacement for BoundedArray)

> Example: `examples/m10_stack_list.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

// See the English guide for context.
test "栈上有界列表" {
    var buffer: [8]i32 = undefined;
    var stack: std.ArrayList(i32) = .initBuffer(&buffer);
    try stack.appendSliceBounded(&.{ 1, 2, 3 });
    try stack.appendBounded(4);
    try std.testing.expectEqual(@as(usize, 4), stack.items.len);
    try stack.appendSliceBounded(&.{ 5, 6, 7, 8 });
    try std.testing.expectError(error.OutOfMemory, stack.appendBounded(9));
}
```

### 2.8 SoA (`MultiArrayList`), out-of-band booleans, and hot/cold separation

In an array of structs (AoS), every element may need padding for alignment. A struct of arrays (SoA) stores each field in a separate array. This removes padding and lets loops that use only one or two fields load only the relevant cache lines. Zig's compiler uses SoA for tokens and AST nodes: a token stores a 1-byte tag and 4-byte offset; an AST node stores a 1-byte tag, 4-byte `main_token`, and 8-byte data. SoA avoids padding each node to 16 bytes.

> Example: `examples/m05_soa.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

const Monster = struct {
    hp: u32,
    pos: [2]f32,
    kind: enum(u8) { human, orc, elf },
};

test "MultiArrayList: SoA 去 padding、按字段遍历" {
    const gpa = std.testing.allocator;
    var list: std.MultiArrayList(Monster) = .empty;
    defer list.deinit(gpa);

    try list.ensureTotalCapacity(gpa, 3);
    list.appendAssumeCapacity(.{ .hp = 10, .pos = .{ 0, 0 }, .kind = .orc });
    list.appendAssumeCapacity(.{ .hp = 20, .pos = .{ 1, 1 }, .kind = .elf });
    list.appendAssumeCapacity(.{ .hp = 30, .pos = .{ 2, 2 }, .kind = .orc });

    const s = list.slice();
    var orc_hp: u32 = 0;
    for (s.items(.kind), s.items(.hp)) |k, hp| {
        if (k == .orc) orc_hp += hp;
    }
    try std.testing.expectEqual(@as(u32, 40), orc_hp);
// See the English guide for context.
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Monster));
}
```

`MultiArrayList` stores all field arrays in one allocation and orders sub-arrays by alignment. If a loop accesses several fields, call `slice()` once and cache the field pointers.

**Domain IR packing (corpus).** Zig IR (`lib/std/zig/Zir.zig`) keeps instructions in a `MultiArrayList`, rare operands in `extra: []u32`, and text in `string_bytes: []u8`. Small tags stay dense; uncommon payloads stay out of the hot SoA columns. Same idea for any bytecode / AST-extra blob: put the common fields in SoA, shove the rest into a side array keyed by index.

**Evidence (corpus):** `Zir.zig` field layout (`instructions`, `extra`, `string_bytes`). No local packing bench.

Andrew Kelley's talk also describes two layout changes that preserve behavior: **move booleans out of the struct** (represent the property by which array an item belongs to) and **separate hot and cold fields**.

> Example: `examples/m13_out_of_band.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
const Monster = struct { hp: u32, x: u32, y: u32 };

const World = struct {
    alive: std.ArrayList(Monster) = .empty,
    dead: std.ArrayList(Monster) = .empty,

    fn kill(w: *World, gpa: std.mem.Allocator, i: usize) !void {
        try w.dead.ensureUnusedCapacity(gpa, 1);
        w.dead.appendAssumeCapacity(w.alive.swapRemove(i));
    }
    fn tick(w: *World) void {
        // zperf-lint: ignore zp-aos-single-field
        for (w.alive.items) |*m| m.hp -|= 1;
    }
};

/// See the English guide for context.
const Hot = struct { pos: [2]f32, vel: [2]f32 };
const Cold = struct { name: []const u8, created_ms: u64 };

test "out-of-band bool + hot/cold split" {
    const gpa = std.testing.allocator;
    var w: World = .{};
    defer w.alive.deinit(gpa);
    defer w.dead.deinit(gpa);
    try w.alive.appendSlice(gpa, &.{ .{ .hp = 3, .x = 0, .y = 0 }, .{ .hp = 5, .x = 1, .y = 1 } });
    try w.kill(gpa, 0);
    w.tick();
    try std.testing.expectEqual(@as(usize, 1), w.alive.items.len);
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(Monster));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Hot));
    _ = Cold;
}
```

**Evidence (local):** `examples/p15_soa_bandwidth.zig` sums one hot `u32` field over N=4e6 (4 passes, best-of-7, `-O fast`) for AoS vs `MultiArrayList.items(.hp)` vs a parallel `[]u32`. JSONL: `zig-perf-research/bench-results/p15_soa_bandwidth.jsonl` (re-run before citing).

**Not a good fit:** code that always reads or writes an entire element, such as serializing full records one by one. SoA must touch N arrays in that case. The difference may also be negligible for small collections.

Sources: [Practical Data-Oriented Design](https://handmade-seattle.com/media-sub/practical-data-oriented-design) · [talk transcript](https://josherich.me/podcast/andrew-kelley-practical-data-oriented-design-dod) · [PR #7920: AST memory layout redesign](https://github.com/ziglang/zig/pull/7920) · [Mitchell Hashimoto: Zig Parser](https://mitchellh.com/zig/parser) · `lib/std/multi_array_list.zig`

### 2.9 Bit packing: packed structs and arbitrary-width integers

- Fields in `packed struct(uN)` are tightly packed in declaration order from the least-significant bit. There is no padding. They can be converted to the backing integer with `@bitCast`, compared directly (0.14+), and used for atomic operations.
- Arbitrary-width integers such as `u3` and `i7` use only 3 or 7 bits inside packed containers. In ordinary structs and arrays they are still stored in whole bytes (`@sizeOf(u3) == 1`, `@sizeOf([8]u3) == 8`).
- `std.PackedIntArray` is gone in 0.17. Use `std.mem.readPackedInt` and `writePackedInt` to pack N 3-bit integers tightly (see the complete example in Chapter 4).

> Example: `examples/m06_packed.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

const Flags = packed struct(u8) {
    visible: bool,
    dirty: bool,
    selected: bool,
    layer: u3,
    _pad: u2 = 0,
};

// zperf-lint: ignore zp-packable-bools
const Loose = struct { visible: bool, dirty: bool, selected: bool, layer: u8 };

test "packed struct 把 4 个字段压进 1 字节" {
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Flags));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(Loose));

    var f: Flags = .{ .visible = true, .dirty = false, .selected = true, .layer = 5 };
    f.dirty = true;
    const raw: u8 = @bitCast(f);
    try std.testing.expectEqual(@as(u8, 0b00_101_111), raw);
    try std.testing.expect(f == @as(Flags, @bitCast(raw)));
}

test "u3 等窄整数在普通 struct/数组里仍按字节存储" {
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(u3));
    try std.testing.expectEqual(@as(usize, 3), @bitSizeOf(u3));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf([8]u3));

// See the English guide for context.
    var bytes: [3]u8 = @splat(0);
    for (0..8) |i| std.mem.writePackedInt(u3, &bytes, i * 3, @intCast(i), .little);
    try std.testing.expectEqual(@as(u3, 6), std.mem.readPackedInt(u3, &bytes, 6 * 3, .little));
}
```

**Not a good fit:** hot data with frequent access to individual fields. Each access needs shifts and masks. Since 0.16, packed structs and unions cannot contain pointers; store a `usize` and use `@ptrFromInt` when needed.

### 2.10 Indices instead of pointers, handles, tagged pointers, and NaN boxing

On 64-bit platforms, a pointer takes 8 bytes, while most arrays have fewer than 2^32 elements. A `u32` index (preferably a non-exhaustive `enum(u32)` for type safety) uses half the space, can be copied or serialized as a whole, and survives array relocation. Zig's `InternPool` uses 32-bit indices for types and constants. TigerStyle also recommends explicit-width types such as `u32` instead of architecture-dependent `usize`.

#### Concurrent intern: shard, then lock on miss (advanced)

The compiler `InternPool` (`src/InternPool.zig` @ `8f0c6ce4`) keeps **power-of-two shards** and per-thread `locals`. Lookups hash to a shard, `acquire` the shared map, and take the shard mutex only on miss/insert (`trackZir` ~L227+). Indices bake a thread id into high bits so ownership stays cheap. Application-level string/type pools under contention can copy the shape: shard → shared read → lock only to insert — not a global mutex on every intern.

**Evidence (corpus / U):** `InternPool.zig` L22–26 (shards/locals), `trackZir`; [PR #15569](https://github.com/ziglang/zig/pull/15569). No local shard-vs-global-mutex bench in this repo.

> Example: `examples/m07_index.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
const NodeIndex = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    fn from(i: usize) NodeIndex {
        return @fromBackingInt(@intCast(i));
    }
    fn get(self: NodeIndex) u32 {
        return @backingInt(self);
    }
};

const Node = struct { value: i32, left: NodeIndex, right: NodeIndex };

test "索引代替指针" {
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(Node));
    const nodes = [_]Node{
        .{ .value = 2, .left = .from(1), .right = .none },
        .{ .value = 1, .left = .none, .right = .none },
    };
    try std.testing.expectEqual(@as(i32, 1), nodes[nodes[0].left.get()].value);
}
```

To detect a stale handle after a slot is reused (the ABA problem), add a generation counter:

> Example: `examples/x06_generation.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
fn SlotMap(comptime T: type, comptime capacity: u32) type {
    return struct {
        const Self = @This();
        pub const Handle = packed struct(u64) { index: u32, generation: u32 };

        items: [capacity]T = undefined,
        generations: [capacity]u32 = @splat(0),
        free: [capacity]u32 = undefined,
        free_len: u32 = 0,
        len: u32 = 0,

        pub fn insert(s: *Self, v: T) ?Handle {
            const i: u32 = if (s.free_len > 0) blk: {
                s.free_len -= 1;
                break :blk s.free[s.free_len];
            } else if (s.len < capacity) blk: {
                s.len += 1;
                break :blk s.len - 1;
            } else return null;
            s.items[i] = v;
            return .{ .index = i, .generation = s.generations[i] };
        }
        pub fn remove(s: *Self, h: Handle) void {
            std.debug.assert(s.generations[h.index] == h.generation);
            s.generations[h.index] +%= 1;
            s.free[s.free_len] = h.index;
            s.free_len += 1;
        }
        pub fn get(s: *Self, h: Handle) ?*T {
            if (s.generations[h.index] != h.generation) return null;
            return &s.items[h.index];
        }
    };
}

test "generational handles" {
    var map: SlotMap(f32, 4) = .{};
    const a = map.insert(1.5).?;
    map.remove(a);
    const b = map.insert(2.5).?;
    try std.testing.expectEqual(a.index, b.index);
    try std.testing.expect(map.get(a) == null);
    try std.testing.expectEqual(@as(f32, 2.5), map.get(b).?.*);
}
```

Aligned pointers have unused low bits that can hold tags:

> Example: `examples/x05_tagged_ptr.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
const Tag = enum(u3) { leaf, branch, deleted };

const TaggedPtr = packed struct(usize) {
    tag: Tag,
    addr_hi: @Int(.unsigned, @bitSizeOf(usize) - 3),

    fn init(p: *align(8) u64, tag: Tag) TaggedPtr {
        return .{ .tag = tag, .addr_hi = @intCast(@intFromPtr(p) >> 3) };
    }
    fn ptr(self: TaggedPtr) *align(8) u64 {
        return @ptrFromInt(@as(usize, self.addr_hi) << 3);
    }
};

test "tagged pointer" {
    var x: u64 align(8) = 7;
    const tp: TaggedPtr = .init(&x, .branch);
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(TaggedPtr));
    try std.testing.expectEqual(Tag.branch, tp.tag);
    try std.testing.expectEqual(@as(u64, 7), tp.ptr().*);
}
```

Interpreters often use NaN boxing to fit floats, integers, and pointers into 8 bytes:

> Example: `examples/x08_nanbox.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
const Value = packed struct(u64) {
    bits: u64,

    const qnan: u64 = 0x7ff8_0000_0000_0000;
    const tag_int: u64 = 0x0001_0000_0000_0000;
    const tag_ptr: u64 = 0x0002_0000_0000_0000;
    const payload_mask: u64 = 0x0000_ffff_ffff_ffff;

    fn fromFloat(f: f64) Value {
        return .{ .bits = @bitCast(f) };
    }
    fn fromInt(i: u32) Value {
        return .{ .bits = qnan | tag_int | i };
    }
    fn fromPtr(p: *const anyopaque) Value {
        return .{ .bits = qnan | tag_ptr | (@intFromPtr(p) & payload_mask) };
    }
    fn isFloat(v: Value) bool {
        return (v.bits & qnan) != qnan or (v.bits & (tag_int | tag_ptr)) == 0;
    }
    fn isInt(v: Value) bool {
        return (v.bits & (qnan | tag_int | tag_ptr)) == (qnan | tag_int);
    }
    fn asInt(v: Value) u32 {
        return @truncate(v.bits & payload_mask);
    }
    fn asFloat(v: Value) f64 {
        return @bitCast(v.bits);
    }
};

test "NaN-boxing" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Value));
    const a: Value = .fromFloat(3.5);
    const b: Value = .fromInt(42);
    try std.testing.expect(a.isFloat() and !a.isInt());
    try std.testing.expectEqual(@as(f64, 3.5), a.asFloat());
    try std.testing.expect(b.isInt() and !b.isFloat());
    try std.testing.expectEqual(@as(u32, 42), b.asInt());
    var x: u32 = 0;
    try std.testing.expect(!Value.fromPtr(&x).isFloat());
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(union(enum) { f: f64, i: u32, p: *anyopaque }));
}
```

When the “array” is a single relocatable mmap slab with mixed interior types, prefer **byte offsets into that base** over raw pointers—see §2.17.

**Not a good fit:** tagged pointers and NaN boxing rely on platform assumptions such as addresses using only the low 48 bits, and debuggers cannot inspect them easily. Use them only when value representation is a measured bottleneck, such as in an interpreter or VM.

Sources: [InternPool PR #15569](https://github.com/ziglang/zig/pull/15569) · [TigerStyle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md) · [0.16: pointers disallowed in packed structs](https://ziglang.org/download/0.16.0/release-notes.html)

### 2.11 String interning and small-string optimization

Store strings in one `bytes` array and refer to them with `u32` offsets. The hash table stores only `u32` values and uses `StringIndexAdapter` to compare strings in `bytes`. Duplicate strings are stored once, and lookups compare integer indices.

> Example: `examples/m08_intern.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
/// See the English guide for context.
const StringPool = struct {
    bytes: std.ArrayList(u8) = .empty,
    table: std.HashMapUnmanaged(u32, void, std.hash_map.StringIndexContext, 80) = .empty,

    fn deinit(p: *StringPool, gpa: std.mem.Allocator) void {
        p.bytes.deinit(gpa);
        p.table.deinit(gpa);
        p.* = undefined;
    }

    fn intern(p: *StringPool, gpa: std.mem.Allocator, s: []const u8) !u32 {
        const gop = try p.table.getOrPutContextAdapted(
            gpa,
            s,
            std.hash_map.StringIndexAdapter{ .bytes = &p.bytes },
            std.hash_map.StringIndexContext{ .bytes = &p.bytes },
        );
        if (gop.found_existing) return gop.key_ptr.*;
        const off: u32 = @intCast(p.bytes.items.len);
        try p.bytes.ensureUnusedCapacity(gpa, s.len + 1);
        p.bytes.appendSliceAssumeCapacity(s);
        p.bytes.appendAssumeCapacity(0);
        gop.key_ptr.* = off;
        return off;
    }

    fn get(p: *const StringPool, off: u32) []const u8 {
        const rest = p.bytes.items[off..];
        return rest[0..std.mem.findScalar(u8, rest, 0).?]; // 0.16: indexOfScalar -> findScalar
    }
};

test "string interning" {
    const gpa = std.testing.allocator;
    var pool: StringPool = .{};
    defer pool.deinit(gpa);
    const a = try pool.intern(gpa, "hello");
    const b = try pool.intern(gpa, "world");
    const c = try pool.intern(gpa, "hello");
    try std.testing.expectEqual(a, c);
    try std.testing.expect(a != b);
    try std.testing.expectEqualStrings("world", pool.get(b));
}
```

#### HashMap `*Adapted`: look up without owning the key yet

`getOrPutAdapted` / `getOrPutContextAdapted` (`lib/std/hash_map.zig`) take a **borrowed** key plus an adapter that hashes/equals against the map’s stored key type. That avoids `alloc.dupe` on the miss path until you know the entry is new — the footgun is `dupe` then `put` on every lookup. `m08_intern.zig` uses `StringIndexAdapter` over the shared `bytes` buffer for exactly this.

Also prefer `ArrayHashMap` when you **iterate all entries** often (contiguous keys/values, `swapRemove`); plain `HashMap` wins on point lookups with less movement ([Ghostty#2076](https://github.com/ghostty-org/ghostty/pull/2076) is a related upstream story — **U**).

**Evidence (API / corpus):** `hash_map.zig` `getOrPutAdapted` (~L272, ~L1109) and std tests; adapter use in `m08_intern.zig`. No local Adapted-vs-dupe microbench.

Small-string optimization (SSO) stores strings up to 15 bytes inline in a 16-byte struct (the size of a slice) without touching the heap.

> Example: `examples/x09_sso.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
const SmallString = extern union {
    inline_: extern struct { bytes: [15]u8, len: u8 },
    heap: extern struct { ptr: [*]u8, len: u32, _pad: [3]u8, tag: u8 },

    const heap_tag = 0x80;

    fn init(gpa: std.mem.Allocator, s: []const u8) !SmallString {
        if (s.len <= 15) {
            var r: SmallString = .{ .inline_ = .{ .bytes = undefined, .len = @intCast(s.len) } };
            @memcpy(r.inline_.bytes[0..s.len], s);
            return r;
        }
        const p = try gpa.dupe(u8, s);
        return .{ .heap = .{ .ptr = p.ptr, .len = @intCast(s.len), ._pad = undefined, .tag = heap_tag } };
    }
    fn isHeap(self: *const SmallString) bool {
        return self.inline_.len & heap_tag != 0;
    }
    fn slice(self: *const SmallString) []const u8 {
        return if (self.isHeap()) self.heap.ptr[0..self.heap.len] else self.inline_.bytes[0..self.inline_.len];
    }
    fn deinit(self: *SmallString, gpa: std.mem.Allocator) void {
        if (self.isHeap()) gpa.free(self.heap.ptr[0..self.heap.len]);
        self.* = undefined;
    }
};

test "SSO" {
    const gpa = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(SmallString));
    var a: SmallString = try .init(gpa, "hello");
    defer a.deinit(gpa);
    var b: SmallString = try .init(gpa, "this string is definitely longer than 15");
    defer b.deinit(gpa);
    try std.testing.expect(!a.isHeap());
    try std.testing.expect(b.isHeap());
    try std.testing.expectEqualStrings("hello", a.slice());
    try std.testing.expectEqualStrings("this string is definitely longer than 15", b.slice());
}
```

### 2.12 Hidden costs of optionals, error unions, and slices

| Type (x86_64) | `@sizeOf` | Notes |
|---|---:|---|
| `?*T` | 8 | Optional pointer: null is represented by a null address, with no extra storage |
| `?u32` | 8 | 4 bytes plus a 1-byte tag, padded to 4-byte alignment |
| `?u64` | 16 | Twice the size |
| `anyerror` | 2 | Default 16-bit error code |
| `anyerror!u64` | 16 | |
| `[]u8` | 16 | Pointer plus `usize` length (a fat pointer) |
| `[*:0]const u8` | 8 | Sentinel-terminated; length is found by scanning |

In hot structs, replace `?u32` with a sentinel such as `maxInt(u32)` or `enum(u32) { none = maxInt(u32), _ }` to save half the storage. A standalone thin slice `{ptr, u32 len}` is usually padded back to 16 bytes. The real savings come from an **offset plus length** into a shared buffer (8 bytes), as in §2.11.

> Example: `examples/x01_optional.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

// zperf-lint: ignore zp-optional-scalar-field
const WithOpt = struct { parent: ?u32, depth: u32 };
const WithSentinel = struct {
    parent: u32,
    depth: u32,
    const none = std.math.maxInt(u32);
};

test "optional 的代价与哨兵值" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(?u32));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(*u8));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(?*u8));
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(WithOpt));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(WithSentinel));
// See the English guide for context.
}

test "error union 与切片的大小" {
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(anyerror));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(anyerror!u64));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf([]u8)); // ptr + usize len
    try std.testing.expectEqual(@as(usize, 8), @sizeOf([*:0]const u8));
// See the English guide for context.
    const Thin = extern struct { ptr: [*]const u8, len: u32 };
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Thin));
    const ThinSoA = struct { offset: u32, len: u32 };
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(ThinSoA));
}
```

### 2.13 Replace hash maps with enum containers and compile-time tables

For enum keys, `std.EnumArray(E, V)` is an `[N]V`, `std.EnumSet(E)` is a bit set, and `std.EnumMap` combines a bit set and an array. None need hashing or allocation. For compile-time-known string keys, use `std.StaticStringMap(V).initComptime`, a read-only table bucketed by string length.

> Example: `examples/x02_enum_containers.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

const Kind = enum { int, float, string, bool };

const keywords = std.StaticStringMap(Kind).initComptime(.{
    .{ "int", .int },
    .{ "float", .float },
    .{ "string", .string },
    .{ "bool", .bool },
});

test "EnumArray 代替 HashMap(enum, V)" {
    var counts: std.EnumArray(Kind, u32) = .initFill(0);
    counts.getPtr(.float).* += 1;
    try std.testing.expectEqual(@as(u32, 1), counts.get(.float));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(@TypeOf(counts)));
}

test "StaticStringMap：编译期构建的只读字符串表（按长度分桶），零运行时分配" {
    try std.testing.expectEqual(Kind.float, keywords.get("float").?);
    try std.testing.expect(keywords.get("double") == null);
}
```

### 2.14 Zero-copy parsing and memory-mapped files

Return slices into the input buffer instead of duplicating parsed data. If the input is memory-mapped, the whole path can avoid copying file contents. Since 0.16, `Io.File.createMemoryMap` is the cross-platform wrapper around `std.posix.mmap`.

> Example: `examples/x03_zero_copy.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
const Field = struct { key: []const u8, value: []const u8 };

fn parseLine(line: []const u8) ?Field {
    const eq = std.mem.findScalar(u8, line, '=') orelse return null; // 0.16: indexOfScalar -> findScalar
    return .{
        .key = std.mem.trim(u8, line[0..eq], " "),
        .value = std.mem.trim(u8, line[eq + 1 ..], " "),
    };
}

test "zero-copy" {
    const input = "name = zig\nversion= 0.17\n";
    var it = std.mem.splitScalar(u8, input, '\n');
    var n: usize = 0;
    while (it.next()) |line| {
        const f = parseLine(line) orelse continue;
// See the English guide for context.
        try std.testing.expect(@intFromPtr(f.key.ptr) >= @intFromPtr(input.ptr));
        n += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), n);
}
```

> Example: `examples/x07_mmap.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

// See the English guide for context.
test "memory-mapped file" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile(io, "data.bin", .{ .read = true });
    defer file.close(io);
    try file.writeStreamingAll(io, "hello mmap");

    var map = try file.createMemoryMap(io, .{ .len = 10, .protection = .{ .read = true } });
    defer map.destroy(io);
    try std.testing.expectEqualStrings("hello mmap", map.memory[0..10]);
}
```

**Note:** zero-copy results live as long as the input buffer. If another process truncates a memory-mapped file, access can raise `SIGBUS`.

### 2.15 Variable-length encoding and delta encoding

For monotonic sequences such as ordered IDs and timestamps, encode deltas with LEB128. Small deltas then take only one byte. `std.Io.Writer.writeUleb128` and `std.Io.Reader.takeLeb128` provide these operations directly.

> Example: `examples/x04_varint.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
fn encode(w: *std.Io.Writer, ids: []const u64) !void {
    var prev: u64 = 0;
    for (ids) |id| {
        try w.writeUleb128(id - prev);
        prev = id;
    }
}

fn decode(r: *std.Io.Reader, out: []u64) !void {
    var prev: u64 = 0;
    for (out) |*o| {
        prev += try r.takeLeb128(u64);
        o.* = prev;
    }
}

test "delta + varint" {
    const ids = [_]u64{ 1_000_000, 1_000_003, 1_000_010, 1_000_200 };
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try encode(&w, &ids);
    try std.testing.expectEqual(@as(usize, 3 + 1 + 1 + 2), w.end);

    var r: std.Io.Reader = .fixed(w.buffered());
    var out: [4]u64 = undefined;
    try decode(&r, &out);
    try std.testing.expectEqualSlices(u64, &ids, &out);
}
```

### 2.16 Fragmentation, huge pages, and other notes

- **Fragmentation:** Mixing many small objects with different sizes and lifetimes in one general-purpose heap can fragment memory. Group allocations by lifetime (arena), by size (`MemoryPool` / size-class pools), or use static allocation.
- **Huge pages:** TLB misses can limit large, randomly accessed data such as hash tables and arrays. On Linux, `madvise(MADV_HUGEPAGE)` can request transparent huge pages for an `mmap` region. Measure the result with `perf stat -e dTLB-load-misses`.
- **ArrayList growth:** Since 0.14, the Allocator has `remap`, and `page_allocator` supports `mremap`. Large ArrayList growth may therefore remap pages instead of copying them.
- **`Deque` + `remap`:** `std.Deque` grows with `Allocator.remap` when the ring can stay in place; only then splits head/tail for a moving grow (`lib/std/deque.zig`). Prefer remap-friendly allocators behind large rings.

### 2.17 Relocatable slabs and idle physical reclaim (advanced)

#### Store offsets, not pointers, into a base page

When a region must **move, snapshot, or compress in place**, interior pointers dangle. Ghostty terminal pages store typed **byte offsets** (`Offset(T)`) into one slab instead of `*T`. Resolve with `base + byte` (alignment assert); relocate with a byte copy or remap — no pointer walk. Same idea as §2.10 indices; the “array” is an opaque mmap'd page of mixed layouts.

Anonymous `mmap` (`MAP_PRIVATE|MAP_ANONYMOUS`) is a common slab source: page-aligned, zero-filled by the OS, and free of general-purpose allocator freelist overhead for large pages (complementary to zp-page-allocator-small's warning against `page_allocator` for *small* objects).

> Example: `examples/m17_offset_slab.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// Typed byte offset into a relocatable base slab (no raw pointers stored).
/// API shape inspired by Ghostty terminal Offset(T) (MIT); original teaching code.
fn Offset(comptime T: type) type {
    return struct {
        byte: u32 = 0,

        const Self = @This();

        fn ptr(self: Self, base: []u8) [*]T {
            const addr = @intFromPtr(base.ptr) + self.byte;
            std.debug.assert(addr % @alignOf(T) == 0);
            return @ptrFromInt(addr);
        }

        fn slice(self: Self, base: []u8, len: usize) []T {
            return self.ptr(base)[0..len];
        }
    };
}

const Cell = struct { ch: u32, style: u16 };

test "offset into relocatable slab" {
    var slab: [256]u8 align(@alignOf(Cell)) = undefined;
    const off: Offset(Cell) = .{ .byte = 0 };
    const cells = off.slice(slab[0..], 4);
    cells[0] = .{ .ch = 'A', .style = 1 };
    cells[1] = .{ .ch = 'B', .style = 2 };

    // Relocate: copy slab bytes; offsets stay valid relative to the new base.
    var moved: [256]u8 align(@alignOf(Cell)) = undefined;
    @memcpy(moved[0..], slab[0..]);
    const again = off.slice(moved[0..], 4);
    try std.testing.expectEqual(@as(u32, 'A'), again[0].ch);
    try std.testing.expectEqual(@as(u32, 'B'), again[1].ch);
}
```

#### Idle compression with a retained virtual mapping

Cold data can keep its **virtual address** while dropping **physical** pages. Ghostty's scrollback path LZ4-compresses idle terminal pages, retains the mapping, then uses `MADV_DONTNEED` on Linux (and the Darwin reusable-free equivalent) so RSS falls without reallocating on restore. Upstream [ghostty#13264](https://github.com/ghostty-org/ghostty/pull/13264) reports roughly **70–90%** physical savings (up to ~94% on repetitive corpora) with incremental idle drain on the order of ~100 µs/page—cite those numbers as **upstream measurements**, not as results from this repo until a local ScrollbackCompression-style bench exists.

Constraints from that design:

1. Prefer **ratio and decompress throughput** over exotic SIMD in the compressor.
2. Keep the compressed form only when it saves memory versus leaving the page resident.
3. Restore must recommit/fault pages before readers touch the data again.

**Evidence (upstream):** Ghostty `src/terminal/size.zig` / `page.zig` (offsets + anon mmap); `src/terminal/compress/Page.zig` + [PR #13264](https://github.com/ghostty-org/ghostty/pull/13264). **Evidence (local):** `m17_offset_slab.zig` teaches the offset API only (no timing).

**Not a good fit:** short-lived heaps where compress+madvise costs exceed the idle window; platforms without a reliable decommit primitive.

---

## 3. C memory techniques and their Zig equivalents

Common C bit-packing and layout tricks map to Zig with clearer layout rules.

| C | Zig | Key difference |
|---|---|---|
| `enum Color {...}` (often `int`-sized; implementation-defined) | `enum { ... }` with the smallest inferred tag (3 values → `u2`), or explicit `enum(u8)` | Stored enums still occupy whole bytes, but use only the tag width inside a packed struct |
| Bit field `unsigned x:4;` | `packed struct(u16) { x: u4, ... }` with arbitrary-width `uN`/`iN` fields | C bit order and unit-crossing rules are implementation-defined; Zig places the first field in the least-significant bits consistently across platforms |
| Bit flags with `#define F_A 1<<0` and `unsigned flags` | Boolean fields in `packed struct(u8)`, `std.EnumSet(E)`, or `std.bit_set.Integer(N)`, `Static(N)`, or `Dynamic` | Type-safe; unrelated flags and enum values cannot be mixed accidentally |
| `sizeof`, `_Alignof`, and `offsetof` | `@sizeOf`, `@alignOf`, and `@offsetOf`, plus `@bitSizeOf` and `@bitOffsetOf` | Zig also supports bit-level queries |
| Struct fields laid out in declaration order | Ordinary structs may be reordered by the compiler; `extern struct` follows the C ABI declaration order | Only `extern struct` needs manual field ordering |
| `#pragma pack(1)` / `__attribute__((packed))` | `extern struct` with field-level `align(1)`, or `packed struct` | Unaligned access can be slower |
| `union` | `extern union` for C compatibility and type punning; bare `union` has a hidden safety tag in Debug/Safe; `union(enum)` has an explicit tag | A tagged union's tag is padded to the payload's alignment |
| Choosing `signed` or `unsigned` | Choose by value range: `i7` is [-64, 63], `u7` is [0, 127] | Zig checks overflow by default in Debug/Safe; use `+%` for wrapping arithmetic |
| Bytes versus bits | `bool` takes 1 byte, `[N]bool` takes N bytes, and a bit set takes N/8 bytes | Bit sets save 8× for large collections of flags |

### 3.1 Enum tag width

> Example: `examples/c01_enum_width.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

// See the English guide for context.
const Color = enum { red, green, blue };
const Opcode = enum(u8) { nop, add, sub, _ };

test "enum 大小" {
    try std.testing.expectEqual(u2, @typeInfo(Color).@"enum".tag_type);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Color));
    try std.testing.expectEqual(@as(usize, 2), @bitSizeOf(Color));
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Opcode));
    const op: Opcode = @fromBackingInt(@as(u8, 200));
    try std.testing.expect(op != .add);
}
```

### 3.2 Bit fields to packed structs

> Example: `examples/c02_bitfield.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

// C:
// struct Hdr { unsigned version:4; unsigned ihl:4; unsigned dscp:6; unsigned ecn:2; };
// See the English guide for context.
// See the English guide for context.
const Hdr = packed struct(u16) {
    ihl: u4,
    version: u4,
    ecn: u2,
    dscp: u6,
};

const Signedness = struct { delta: i7, count: u7 };

test "packed struct 等价 C 位域" {
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(Hdr));
    try std.testing.expectEqual(@as(usize, 16), @bitSizeOf(Hdr));
    try std.testing.expectEqual(@as(u16, 8), @bitOffsetOf(Hdr, "ecn"));
    const h: Hdr = .{ .version = 4, .ihl = 5, .dscp = 0, .ecn = 0 };
    const raw: u16 = @bitCast(h);
    try std.testing.expectEqual(@as(u16, 0x45), raw);
// See the English guide for context.
    try std.testing.expectEqual(raw, @backingInt(h));
// See the English guide for context.
    try std.testing.expectEqual(@as(i7, -64), std.math.minInt(i7));
    try std.testing.expectEqual(@as(u7, 127), std.math.maxInt(u7));
    _ = Signedness;
}
```

### 3.3 `sizeof`, `alignof`, `offsetof`, and `#pragma pack`

> Example: `examples/c03_layout.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

// See the English guide for context.
// See the English guide for context.
const Bad = extern struct { a: u8, b: u64, c: u8 }; // 1 + 7pad + 8 + 1 + 7pad = 24
const Good = extern struct { b: u64, a: u8, c: u8 }; // 8 + 1 + 1 + 6pad = 16
const Auto = struct { a: u8, b: u64, c: u8 };

// See the English guide for context.
const Packed1 = extern struct { a: u8, b: u32 align(1) };

test "sizeof/alignof/offsetof 对应" {
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(Bad));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Good));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(Bad, "b"));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(Good));
    try std.testing.expect(@sizeOf(Auto) <= 16);
    try std.testing.expectEqual(@as(usize, 5), @sizeOf(Packed1));
    try std.testing.expectEqual(@as(usize, 1), @offsetOf(Packed1, "b"));
}
```

Sorting `Bad` by alignment drops it from 24 bytes to 16. A local walk of that shape was only about 1.2×, so the lint was removed. Keep the order when the layout is an ABI.

### 3.4 Unions: C, bare, and tagged

> Example: `examples/c04_union.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

const Untagged = union { i: u32, f: f32 };
const Tagged = union(enum) { i: u32, f: f32 };
const CUnion = extern union { i: u32, f: f32 };

test "union 开销" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Tagged)); // 4 + tag(1) + 3 pad
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(CUnion));
    const u: CUnion = .{ .f = 1.0 };
    try std.testing.expectEqual(@as(u32, 0x3f800000), u.i);
    _ = Untagged;
}

// See the English guide for context.
test "MultiArrayList(tagged union) 拆 tag" {
    const gpa = std.testing.allocator;
    var list: std.MultiArrayList(Tagged) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, .{ .i = 1 });
    try list.append(gpa, .{ .f = 2.0 });
    try std.testing.expectEqual(@as(usize, 2), list.items(.tags).len);
    try std.testing.expectEqual(Tagged{ .f = 2.0 }, list.get(1));
}
```

**Note:** Since 0.17, `@bitCast` does not accept extern structs. For low-level type punning, use `@ptrCast` or `extern union`.

### 3.5 Flag sets: EnumSet and bit_set

> Example: `examples/c05_flags.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

const Perm = enum { read, write, exec, admin };

test "flags：EnumSet / bit_set" {
    // C: #define READ 1, WRITE 2 ... ; unsigned flags;
    var p: std.EnumSet(Perm) = .empty; // 0.17: initEmpty -> .empty
    p.insert(.read);
    p.insert(.exec);
    try std.testing.expect(p.contains(.exec));
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(std.EnumSet(Perm)));

    var small: std.bit_set.Integer(64) = .empty;
    small.set(63);
    try std.testing.expectEqual(@as(usize, 1), small.count());

    var big: std.bit_set.Static(1000) = .empty;
    big.set(999);
    try std.testing.expectEqual(@as(?usize, 999), big.findFirstSet());

// See the English guide for context.
    const gpa = std.testing.allocator;
    var dyn: std.bit_set.Dynamic = try .initEmpty(gpa, 10_000);
    defer dyn.deinit(gpa);
    dyn.set(1234);
    try std.testing.expect(dyn.isSet(1234));
// See the English guide for context.
}
```

Sources: [Zig 0.17.0 language reference](https://ziglang.org/documentation/0.17.0/) · [0.17 `@bitCast` changes](https://ziglang.org/download/0.17.0/release-notes.html) · [0.17 bit_set renames](https://ziglang.org/download/0.17.0/release-notes.html) · `lib/std/enums.zig` and `lib/std/bit_set.zig`

---

## 4. Case study: reducing the memory used by a hybrid car

This example is inspired by Liu Yanpeng's video “Write Code to Save Memory”: <https://v.douyin.com/KoVqTHbb9L0/>. It walks through the video's four C representations in Zig. Tests assert every size with `@sizeOf` or `@bitSizeOf`.

The C code evolves in four steps:

1. `enum Car { ELECTRIC = 1, BENZINE = 2, DIESEL = 3 };`
2. Store the two power sources of a hybrid car as two `int` values: `struct { int type1; int type2; }`, which is 8 bytes on a 64-bit system.
3. Use bit flags instead: `ELECTRIC = 1`, `BENZINE = 1 << 1`, `DIESEL = 1 << 2`, and `int types = ELECTRIC | BENZINE;`. This takes 4 bytes.
4. Use three 1-bit fields: `struct { uint8_t electric:1; uint8_t benzine:1; uint8_t diesel:1; }`. This takes 1 byte.

| Step | C | Zig equivalent | Size |
|---|---|---|---|
| Two ints | `struct { int type1, type2; }` | `extern struct { type1: CarC, type2: CarC }` (`enum(c_int)`) | 8 bytes |
| Small tag | — | `struct { type1: Car, type2: Car }`, where `Car = enum(u2)` | 2 bytes (`@bitSizeOf(Car) == 2`) |
| Bit flags | `unsigned int` | Bitwise OR of `c_uint` constants | 4 bytes |
| Bit fields | Three `uint8_t x:1` fields | `packed struct(u8) { electric: bool, benzine: bool, diesel: bool, _pad: u5 = 0 }` | 1 byte (8 bits, 3 used) |
| Bit set | — | `std.EnumSet(FuelKind)` | 1 byte |
| 1,000 cars | — | Pack 3 bits per car with `readPackedInt`/`writePackedInt` | 375 bytes (versus 1,000 bytes for `[1000]Fuel` and 8,000 bytes for two ints) |

> Example: `examples/c06_car_case.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

// See the English guide for context.
const CarC = enum(c_int) { electric = 1, benzine = 2, diesel = 3 };
const HybridC = extern struct { type1: CarC, type2: CarC };

// See the English guide for context.
const Car = enum(u2) { electric = 1, benzine = 2, diesel = 3 };
const Hybrid = struct { type1: Car, type2: Car };

// See the English guide for context.
const ELECTRIC: c_uint = 1;
const BENZINE: c_uint = 1 << 1;
const DIESEL: c_uint = 1 << 2;

// See the English guide for context.
const Fuel = packed struct(u8) {
    electric: bool,
    benzine: bool,
    diesel: bool,
    _pad: u5 = 0,
};

// See the English guide for context.
const FuelKind = enum { electric, benzine, diesel };

/// See the English guide for context.
fn PackedArray(comptime T: type, comptime n: usize) type {
    return struct {
        bytes: [(n * @bitSizeOf(T) + 7) / 8]u8 = @splat(0),
        fn set(self: *@This(), i: usize, v: T) void {
            std.mem.writePackedInt(T, &self.bytes, i * @bitSizeOf(T), v, .little);
        }
        fn get(self: *const @This(), i: usize) T {
            return std.mem.readPackedInt(T, &self.bytes, i * @bitSizeOf(T), .little);
        }
    };
}

test "car case study" {
// See the English guide for context.
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(HybridC));
// See the English guide for context.
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(Hybrid));
    try std.testing.expectEqual(@as(usize, 2), @bitSizeOf(Car));

// See the English guide for context.
    const types: c_uint = ELECTRIC | BENZINE;
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(@TypeOf(types)));
    try std.testing.expect(types & DIESEL == 0);

// See the English guide for context.
    const f: Fuel = .{ .electric = true, .benzine = true, .diesel = false };
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Fuel));
    try std.testing.expectEqual(@as(usize, 8), @bitSizeOf(Fuel));
    const wire: u8 = @bitCast(f);
    try std.testing.expectEqual(@as(u8, 0b011), wire);
    try std.testing.expectEqual(f, @as(Fuel, @bitCast(wire)));

    var set: std.EnumSet(FuelKind) = .empty;
    set.insert(.electric);
    set.insert(.benzine);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(std.EnumSet(FuelKind)));
    try std.testing.expect(!set.contains(.diesel));

// See the English guide for context.
    var cars: PackedArray(u3, 1000) = .{};
    try std.testing.expectEqual(@as(usize, 375), @sizeOf(@TypeOf(cars)));
    cars.set(999, @truncate(wire));
    try std.testing.expectEqual(@as(u3, 0b011), cars.get(999));
    try std.testing.expectEqual(@as(usize, 1000), @sizeOf([1000]Fuel));
    try std.testing.expectEqual(@as(usize, 8000), @sizeOf([1000]HybridC));
}
```

Notes:

- **Percentages.** 64 bits → 8 bits is one-eighth the size (87.5% reduction), not “800% savings”. Packing 3 bits from 64 is about 95% reduction.
- **Zig layout is defined.** C leaves bit order, storage-unit crossing, and signedness of `int` bit fields to the implementation. Zig puts the first `packed struct(u8)` field in the LSB and allows `@bitCast` to `u8` for wire formats.
- **When it matters.** Irrelevant for a handful of UI objects. Relevant for kernels, drivers, embedded, protocol headers, and millions of instances where layout hits cache and peak RSS.
- **Cost.** Packed access needs shifts and masks; `readPackedInt` can be slower. Measure first.

---

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

## 6. Concurrency and I/O

### 6.1 False sharing and cache-line alignment

When two threads frequently write variables on the same cache line, the line repeatedly moves between CPU cores. Separate per-thread data with `align(std.atomic.cache_line)`. `std.atomic.cache_line` is a compile-time value derived from the target CPU.

`std.heap.smp_allocator` already pads each per-thread freelist slot with `align(std.atomic.cache_line)` (§2.1). Custom hot atomics next to each other still need the same treatment — the heap’s padding does not help your counters.

> Example: `examples/p06_false_sharing.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
const PaddedCounter = struct {
    value: std.atomic.Value(u64) align(std.atomic.cache_line) = .init(0),
};

fn worker(c: *PaddedCounter, n: usize) void {
    for (0..n) |_| _ = c.value.fetchAdd(1, .monotonic);
}

test "false sharing" {
    try std.testing.expect(@sizeOf(PaddedCounter) >= std.atomic.cache_line);
    var counters: [4]PaddedCounter = @splat(.{});
    var threads: [4]std.Thread = undefined;
    for (&threads, &counters) |*t, *c| t.* = try std.Thread.spawn(.{}, worker, .{ c, 10_000 });
    for (threads) |t| t.join();
    var total: u64 = 0;
    for (&counters) |*c| total += c.value.load(.monotonic);
    try std.testing.expectEqual(@as(u64, 40_000), total);
}
```

**Evidence (local):** `examples/p17_false_sharing.zig` times adjacent `Atomic(u64)` counters versus `align(std.atomic.cache_line)` padded counters for 2/4/8 threads × 2e6 `fetchAdd(.monotonic)` each (best-of-5, `-O fast`). JSONL: `zig-perf-research/bench-results/p17_false_sharing.jsonl` (re-run before citing).

### 6.2 Parallel tasks with `Io.Group` (replacement for `Thread.Pool` in 0.16)

Zig 0.16 removed `std.Thread.Pool`. The migration guide maps `spawnWg` to `Io.Group.async`. Use `io.concurrent` when tasks must actually run concurrently rather than merely be asynchronous; it may return `error.ConcurrencyUnavailable`. After moving to `Io`, replace synchronization primitives such as `Thread.Mutex` with `Io.Mutex`, `Io.Condition`, and `Io.Event`. A group suits many tasks with the same lifetime; spawning N tasks has O(1) overhead.

> Example: `examples/p11_group.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");
const Io = std.Io;

/// See the English guide for context.
fn sumChunk(xs: []const u64, out: *u64) void {
    var s: u64 = 0;
    for (xs) |x| s +%= x;
    out.* = s;
}

fn parallelSum(io: Io, xs: []const u64) !u64 {
    const chunks = 4;
    var partial: [chunks]u64 = @splat(0);
    const step = (xs.len + chunks - 1) / chunks;
    var g: Io.Group = .init;
    errdefer g.cancel(io);
    for (0..chunks) |c| {
        const lo = @min(c * step, xs.len);
        const hi = @min(lo + step, xs.len);
        g.async(io, sumChunk, .{ xs[lo..hi], &partial[c] });
    }
    try g.await(io);
    var s: u64 = 0;
    for (partial) |p| s +%= p;
    return s;
}

test "Io.Group" {
    var xs: [1000]u64 = undefined;
    for (&xs, 0..) |*x, i| x.* = i;
    try std.testing.expectEqual(@as(u64, 499500), try parallelSum(std.testing.io, &xs));
}
```

**Avoid shared writes:** have each task write to its own slot and merge the results at the end. This is often faster than an atomic counter or lock.

### 6.3 Buffered I/O with the new `Io.Writer` (Writergate)

Since 0.15, callers provide the writer's buffer. The migration guide: “Please use buffering! And don't forget to flush!” The interface also supports splat (repeat a byte without materializing it), `sendFile` (fd-to-fd copy), and vectored writes — fewer syscalls and less memory traffic when they flow through the I/O stack.

**Drain / splat / Allocating (corpus).** `Io.Writer.writeSplat` / `writeSplatHeader` (`lib/std/Io/Writer.zig` ~L181+) coalesce repeated trailing slices without materializing a huge temporary. Concrete writers implement `drain` to flush buffer + vectored tails (including splat counts). `Writer.Allocating` grows an ArrayList-backed buffer and treats flush as a no-op until you take the bytes — useful for “print into memory” without a separate `ArrayList` + formatter dance (`Allocating` ~L2644+). Empty `.buffer = &.{}` still means unbuffered (every write can hit `drain` immediately).

> Example: `examples/p10_io_writer.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");

/// See the English guide for context.
fn writeReport(w: *std.Io.Writer, rows: []const u32) !void {
    for (rows, 0..) |r, i| try w.print("{d}: {d}\n", .{ i, r });
    try w.splatByteAll('-', 10);
    try w.writeByte('\n');
}

test "buffered writer to file" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const file = try tmp.dir.createFile(io, "out.txt", .{});
    defer file.close(io);

    var buf: [4096]u8 = undefined;
    var fw = file.writer(io, &buf);
    try writeReport(&fw.interface, &.{ 7, 8, 9 });
    try fw.interface.flush();
}

test "Allocating writer" {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try writeReport(&aw.writer, &.{1});
    try std.testing.expectEqualStrings("0: 1\n----------\n", aw.written());
}
```

**Anti-patterns:** `file.writer(io, &.{})` uses an empty buffer and can issue a system call for every write. Calling `std.debug.print` in a hot loop locks stderr and uses only a 64-byte buffer (see `lib/std/debug.zig`). zperf-lint rules zp-unbuffered-io and zp-print-in-loop report these patterns.

**Evidence pack (L = local, U = upstream):**

| Claim | Kind | Pointer |
|---|---|---|
| Empty Writer buffer vs 4 KiB on small `/dev/null` writes | **L** | `examples/p19_io_buffering.zig`: empty ≈ **150** ns/write vs 4 KiB ≈ **3** ns/write (~**50×** wall); `strace -c -e writev` oneshot: **100000** vs **390** `writev`. JSONL + dumps: `zig-perf-research/bench-results/p19_*` (re-run before citing). |
| Unbuffered file encode path orders-of-magnitude slower than memory / buffered | **U** | [zigimg#55](https://github.com/zigimg/zigimg/issues/55): unbuffered file write reported ~**5 s** vs memory path **ms**; even `/dev/null` ~**500 ms vs ~35 ms** (reporter’s machine — not re-measured here). |
| Generic / byte-loop Reader vs specialized buffered path | **U** | [zig#17985](https://github.com/ziglang/zig/issues/17985): default `streamUntilDelimiter` byte loop; specialized BufferedReader claimed **2×–15×** (issue discussion). |
| Type-erased AnyWriter vs concrete BufferedWriter | **U** | [zig#21566](https://github.com/ziglang/zig/issues/21566): AnyWriter kills inlining; 1 MiB byte-loop gap vs concrete writer (issue discussion). |
| Writer drain / splat / Allocating API shape | **U** | `lib/std/Io/Writer.zig` @ `8f0c6ce4` (`writeSplat`, `Allocating`) — API evidence, not a timing claim. |

Local p19 measures **syscall / buffer** cost under Writergate `Io.Writer`. Upstream issues cover **generic interfaces** and **file encode** paths; treat their absolute times as **U**, not as numbers for this machine. Prefer concrete buffered writers on hot paths; zp-unbuffered-io flags empty buffers.

**Use `writerStreaming` for stdout and stderr.** `file.writer()` uses positional I/O (`pwrite`) starting at offset zero. If stdout is redirected to a file with existing content, such as `{ echo a; ./app; } > log`, it can overwrite earlier content. This happened while writing zperf-lint. For pipes, terminals, and shared output files, use `File.stdout().writerStreaming(io, &buf)`.

### 6.4 Batch system calls with Batch and io_uring

- `Io.Batch` submits several operations together at the Operation layer. Supported operations include `FileReadStreaming`, `FileWriteStreaming`, `DeviceIoControl`, and `NetReceive`. The official guidance is to prefer Batch for optimal reusable code; use a Future when logic must run between operations.
- `Io.Uring`, the `Io` implementation based on io_uring, was still a proof of concept in 0.16, with gaps in networking, error handling, and test coverage.
- The lower-level `std.os.linux.IoUring` can submit several SQEs with one `submit()` call.

> Example: `examples/p13_uring.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
const std = @import("std");
const builtin = @import("builtin");

// See the English guide for context.
test "io_uring nop batch" {
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;
    var ring = std.os.linux.IoUring.init(8, 0) catch return error.SkipZigTest;
    defer ring.deinit();
    for (0..4) |i| _ = try ring.nop(@intCast(i));
    try std.testing.expectEqual(@as(u32, 4), try ring.submit());
    var cqes: [4]std.os.linux.io_uring_cqe = undefined;
    const n = try ring.copy_cqes(&cqes, 4);
    try std.testing.expectEqual(@as(u32, 4), n);
}
```

Sources: [0.15 Writergate](https://ziglang.org/download/0.15.1/release-notes.html#Writergate) · [0.16 I/O as an Interface, Batch, and removal of Thread.Pool](https://ziglang.org/download/0.16.0/release-notes.html) · `lib/std/os/linux/IoUring.zig`

---

## 7. Builds and tooling

### 7.1 Optimization modes and common options (0.17 names)

| Goal | `zig build-exe` flag | `build.zig` | Notes |
|---|---|---|---|
| Maximum speed | `-O fast` | `-Doptimize=fast` | Disables safety checks. Since 0.17, tags are `.debug/.safe/.fast/.small`; old names such as `ReleaseFast` changed. |
| Release build with checks | `-O safe` | `-Doptimize=safe` | Recommended default for production; disable checks locally with `@setRuntimeSafety(false)` only in verified hot code. |
| Minimum size | `-O small` | `-Doptimize=small` | |
| Target CPU | `-mcpu native` / `-mcpu x86_64_v3` | `-Dcpu=native` | Do not use `native` for binaries distributed to other machines; see §5.2. |
| LTO | `-flto` / `-fno-lto` | `exe.lto = .full` (`std.zig.LtoMode`: `none/full/thin`) | Requires the LLVM backend. |
| Strip symbols | `-fstrip` | `.strip = true` (Module option) | |
| Single-threaded | `-fsingle-threaded` | `.single_threaded = true` | Atomics and locks can be simplified; `smp_allocator` is unavailable. |
| Remove unwind tables | `-fno-unwind-tables` | `.unwind_tables = .none` | Reduces size but affects stack traces. |
| Frame pointer | `-fomit-frame-pointer` | `.omit_frame_pointer = true` | Keep frame pointers when using `perf` to inspect call stacks. |
| Stack report | `-fstack-report` | | Reports stack usage for each function. |
| libc | `-lc` | `.link_libc = true` | With libc linked, `init.gpa` uses `c_allocator` in Fast mode. |

`examples/build_example/` builds with `zig build -Doptimize=fast`:

> Example: `examples/build_example/build.zig` (checked with Zig 0.17.0 using `zig build -Doptimize=fast`).

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{}); // -Dtarget=... -Dcpu=native
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize != .debug,
            .single_threaded = false,
            .unwind_tables = .none,
            .omit_frame_pointer = true,
        }),
    });
    exe.lto = .full;
    b.installArtifact(exe);
}
```

**Local size check (x86_64 Linux):** same tiny alloc/clear program → 217,712 bytes (`-Doptimize=fast`) vs 123,696 (`-Doptimize=small`). Scale only, not a general benchmark.

### 7.2 Reduce binary size

- Combine `-O small`, `-fstrip`, and `-fno-unwind-tables`; add `-fsingle-threaded` only when the program is single-threaded.
- Avoid many distinct `std.fmt` format strings. Each format-string and argument-type combination can instantiate another generic formatting implementation. In 0.16, “Lazy Field Analysis” stopped pulling in the whole vtable when `std.Io.Writer` was used only as a namespace, reducing unnecessary code generation.
- Zig 0.16's “Improved Code Generation of For Loop Safety Checks” reduced generated code for slice iteration by about 30%, according to the release notes.

### 7.3 PGO

Zig does **not** support PGO for user programs as of this writing. [#15137](https://github.com/ziglang/zig/issues/15137) is “not planned”; research [#237](https://github.com/ziglang/zig/issues/237) on test-driven PGO is still open. Fallbacks: branch hints, hot/cold separation, data layout.

Sources: `zig build-exe --help` (0.17.0) · [0.17 rename of lang.OptimizeMode to lang.Optimize](https://ziglang.org/download/0.17.0/release-notes.html) · [0.16 Lazy Field Analysis and loop safety-check code generation](https://ziglang.org/download/0.16.0/release-notes.html) · `lib/std/Build/Step/Compile.zig`

### 7.4 Patterns from the Zig compiler / std (short)

Useful when building tools that look like compilers (parsers, LSs, bundlers). Full notes: `zig-perf-research/zig-lang-perf-patterns.md` (corpus `zig-corpus/zig` @ `8f0c6ce4`).

| Pattern | Where | Takeaway |
|---|---|---|
| Empirical `ensureTotalCapacity` | `lib/std/zig/Ast.zig` | Reserve from measured ratios to input size (§2.6) |
| SoA + `extra` + `string_bytes` | `lib/std/zig/Zir.zig` | Dense IR; rare ops out of line (§2.8) |
| Sharded intern + tid indices | `src/InternPool.zig` | Concurrent intern without a global lock (§2.10) |
| Labeled-switch tokenizer | `lib/std/zig/tokenizer.zig` | Same as §5.4; keywords via `StaticStringMap` |
| Optional tracy hooks | `src/tracy.zig` | Instrument self-host builds when chasing compile time (**U**) |
| Content-addressed build cache | `lib/std/Build/Cache.zig` | SipHash manifests for incremental artifacts (§8.4 adjacent) |

Do not cargo-cult compiler internals into small apps. Steal the **shape** (indices, SoA, shard, ensure heuristics) after measuring.

---

## 8. Measurement and verification

### 8.1 Microbenchmarks

Since 0.16, `std.time.Timer` is gone. Time through `Io`: `std.Io.Clock.Timestamp.now(io, .awake)` and `.untilNow(io)`. Use `std.mem.doNotOptimizeAway` so the compiler cannot delete the work. Run several trials; keep the **best** (or report a distribution) to cut interrupt and cold-cache noise.

Record Zig version, optimize mode, OS, and CPU model so another machine can compare runs. The example prints one **JSONL** line per result.

> Example: `examples/p12_bench.zig` (checked with Zig 0.17.0 using `zig run -O fast`).

```zig
const std = @import("std");
const bench = @import("bench_jsonl.zig");

/// Microbenchmark harness demo: Io.Clock timing + JSONL metadata line.
fn work(xs: []u64) u64 {
    var s: u64 = 0;
    for (xs) |x| s +%= x *% 2654435761;
    return s;
}

const Ctx = struct {
    xs: []u64,
    sink: u64 = 0,
};

fn runWork(ptr: *anyopaque) void {
    const ctx: *Ctx = @ptrCast(@alignCast(ptr));
    const r = work(ctx.xs);
    std.mem.doNotOptimizeAway(r);
    ctx.sink +%= r;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const n: usize = 1 << 20;
    const xs = try gpa.alloc(u64, n);
    defer gpa.free(xs);
    for (xs, 0..) |*x, i| x.* = i;

    var ctx: Ctx = .{ .xs = xs };
    // Warmup
    runWork(@ptrCast(&ctx));

    const trials: usize = 10;
    const best = bench.bestNs(io, trials, runWork, @ptrCast(&ctx));
    // One "op" = one full pass over the array (n elements).
    const iters: u64 = 1;
    try bench.writeLine(io, .{
        .name = "p12_work_sum_u64",
        .ns_per_op = bench.nsPerOp(best, iters),
        .iters = iters,
        .note = "best of 10; 1<<20 u64 mul-add; ns for whole pass",
    });
    std.mem.doNotOptimizeAway(ctx.sink);
}
```

`examples/bench_jsonl.zig` holds the shared fields (`name`, `ns_per_op`, `iters`, `zig_version`, `optimize_mode`, `os`, `cpu_model`, `note`). Comparative benches import it the same way.

**Evidence (local):** Allocator shootout under `zig-perf-research/bench-results/` (`p14_alloc_shootout`, see that directory’s `README.md`). Numbers are machine-specific; re-run before citing.

### 8.2 Tools

- **perf:** `perf stat -e cycles,instructions,cache-misses,branch-misses ./app` for overview; `perf record -g` + `perf report` for hotspots (keep frame pointers: avoid `-fomit-frame-pointer`, or set `.omit_frame_pointer = false`). Zig release-note tables (wall time, peak RSS, cache misses, branch misses) are a good template for multi-metric comparisons.
- **Compare commands:** Andrew Kelley’s [poop](https://github.com/andrewrk/poop) (“Performance Optimizer Observation Platform”) runs several commands and prints the same style of counters used in the release notes.
- **valgrind:** `valgrind --tool=cachegrind` for a cache simulation; Zig’s `-fvalgrind` keeps client requests in release builds when you need them.
- **Tracy:** Frame-oriented profiler; community Zig bindings exist.
- **Assembly:** `zig build-obj -O fast -femit-asm=out.s file.zig`, or [Compiler Explorer](https://godbolt.org/) with Zig selected, to confirm SIMD and inlining.
- **Memory:** In Debug/Safe, `SafeAllocator` reports leaks; tests should use `std.testing.allocator` (leaks fail the test). `/usr/bin/time -v` reports peak RSS.

### 8.3 Practice

1. Estimate first (Chapter 1), then write, measure, then optimize the hot path.
2. Change one variable at a time. Compare run distributions, not a single sample.
3. Keep tests and assertions after optimizing — TigerStyle: assertions turn catastrophic correctness bugs into liveness bugs.

### 8.4 Continuous / regression measurement

One-off microbenches compare A vs B on one machine. Continuous measurement asks whether a merge made the product slower. TigerBeetle’s Continuous Performance Orchestrator sketch ([PR #3737](https://github.com/tigerbeetle/tigerbeetle/pull/3737), closed unmerged) and ZLS’s LSP perf-tracking request ([issue #1522](https://github.com/zigtools/zls/issues/1522)) both point the same way: **store comparable rows every commit (or nightly), not a single absolute nanosecond gate in CI.**

**JSONL fields** (same as `examples/bench_jsonl.zig`):

| Field | Role |
|---|---|
| `name` | Stable id (`alloc_arena_retain`, `io_write_4kib_buf`, …) |
| `ns_per_op`, `iters` | Wall metric and scale |
| `zig_version`, `optimize_mode` | Toolchain / mode |
| `os`, `cpu_arch`, `cpu_model` | Filter across machines |
| `note` | Workload knobs (N, buffer size, threads) |

One JSON object per line in versioned artifacts (or a results DB). Ghostty’s FPS / frame stats ([PR #14488](https://github.com/ghostty-org/ghostty/pull/14488)) and scroll-path guards ([PR #1612](https://github.com/ghostty-org/ghostty/pull/1612)) do the same for interactive work: track a stable signal, not `assert(ns < K)`.

**Optional Linux counters:**

```sh
perf stat -e cycles,instructions,cache-misses,branch-misses,task-clock \
  ./zig-out/bin/your_bench
```

TigerBeetle’s `perf_event` wrapper sketch ([PR #3859](https://github.com/tigerbeetle/tigerbeetle/pull/3859), closed unmerged) CSV-exported cycles / misses / IPC around sections. This repo’s harness stays wall-clock JSONL; attach `perf` when you need a second axis. Do not invent counter numbers — re-run on the machine that owns the claim.

**Avoid absolute ns asserts in CI.** Hypervisors, turbo, noisy neighbors, and Zig bumps move wall time more than many real regressions. Prefer:

1. **Relative** gates on the same runner (fail if `ns_per_op` rises >N% vs that job’s previous median), or
2. **Trend dashboards** with human review, or
3. **Correctness + smoke** on PRs; heavier perf jobs nightly.

Guide microbenches are **L** (local). Upstream PR/issue numbers are **U**. Re-run before a product decision.

Sources: Zig 0.16/0.17 release notes (`Io`, `Clock`) · [poop](https://github.com/andrewrk/poop) · TigerStyle · `examples/p12_bench.zig` · `examples/bench_jsonl.zig` · [TB#3737](https://github.com/tigerbeetle/tigerbeetle/pull/3737) · [TB#3859](https://github.com/tigerbeetle/tigerbeetle/pull/3859) · [ZLS#1522](https://github.com/zigtools/zls/issues/1522) · [Ghostty#14488](https://github.com/ghostty-org/ghostty/pull/14488)

---

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
| zp-alloc-in-loop | `alloc-in-loop` | off | heap allocation inside a loop body |
| zp-append-without-reserve | `append-without-reserve` | off | append in a loop without prior ensureTotalCapacity/ensureUnusedCapacity |
| zp-page-allocator-small | `page-allocator-small` | warning | std.heap.page_allocator used directly for small or container allocations |
| zp-debug-allocator | `debug-allocator` | off | GeneralPurposeAllocator/DebugAllocator used without switching on builtin.mode |
| zp-large-struct-by-value | `large-struct-by-value` | off | large struct passed by value |
| zp-print-in-loop | `print-in-loop` | off | std.debug.print inside a loop (std.log only with --strict-log-in-loop) |
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
| zp-runtime-div-in-loop | `runtime-div-in-loop` | off | division/modulo by a runtime value inside a loop |
| zp-queue-ordered-remove | `queue-ordered-remove` | warning | ArrayList removal shifts all following elements |
| zp-shift-on-read | `shift-on-read` | warning | remaining bytes shifted back to the front after consuming a prefix |
| zp-per-packet-alloc | `per-packet-alloc` | off | heap allocation on a per-packet / per-frame hot path |
| zp-invariant-float-div | `invariant-float-div` | hint | floating-point division by a loop-invariant value inside a loop |
| zp-map-put-without-ensure | `map-put-without-ensure` | off | HashMap put/getOrPut in a loop without prior ensureTotalCapacity/ensureUnusedCapacity |
| zp-catch-unreachable-io | `catch-unreachable-io` | off | `catch unreachable` on fallible I/O (read/write/accept/connect/send/recv/…) |
| zp-arena-reset-free-all | `arena-reset-free-all` | warning | ArenaAllocator.reset(.free_all) or deinit+recreate inside a loop |
| zp-create-destroy-in-loop | `create-destroy-in-loop` | info | allocator.create(T) paired with destroy in the same loop |
| zp-fixed-size-alloc-in-loop | `fixed-size-alloc-in-loop` | info | alloc(u8, comptime_int) of fixed size inside a loop |
| zp-open-file-in-loop | `open-file-in-loop` | hint | openFile / openFileAbsolute inside a loop |
| zp-clock-in-loop | `clock-in-loop` | hint | Io.Clock now inside a loop |
| zp-json-in-loop | `json-in-loop` | hint | json.parseFromSlice of an unchanged payload inside a loop |
| zp-alloc-print-in-loop | `alloc-print-in-loop` | hint | allocPrint / Allocator.print of a loop-invariant value |

Example output from the rule fixtures. The message line has the Chinese message, then the English one; the `建议:` line (suggested fix) and the summary line are Chinese:

```text
$ zperf-lint fixtures/bad/zp-shift-on-read.zig
fixtures/bad/zp-shift-on-read.zig:8:29: warning[zp-shift-on-read shift-on-read] 读走前缀后把剩余数据整体搬回开头 / remaining bytes shifted back to the front after consuming a prefix: std.mem.copyForwards(self.ready.items[0..], self.ready.items[k..])
    建议: 若每次读取后立即搬移，小块读取时总成本可达 O(n²)；改用读游标，缓冲区耗尽时清零，或仅在已消费至少一半/追加空间不足时压缩，以保证搬移被后续读取摊销；持续流量下也可用环形缓冲/std.fifo

共检查 1 个文件，发现 1 处（warning 1, info 0, hint 0）
$ echo $?
1
```

Use `// zperf-lint: ignore zp-alloc-in-loop` to suppress a rule on the current and next line, or `// zperf-lint: ignore-file zp-packable-bools` to suppress a rule for the whole file. Some examples use these directives because they intentionally demonstrate an anti-pattern. The linter itself should report no findings in `examples/`.

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

## 10. Quick reference

**Use less memory**

| Goal | Use |
|---|---|
| Temporary allocations with the same lifetime | `ArenaAllocator` + `reset(.retain_capacity)` |
| Bound retained arena RSS (keepalive) | `reset(.{ .retain_with_limit = N })` (§2.2) |
| No heap allocation | `FixedBufferAllocator` / `ArrayList.initBuffer` |
| Usually small, occasionally large | `BufferFirstAllocator` (0.17) |
| Many objects of one type | `MemoryPool(T)` |
| Equal-size byte buffers | Size-class pool + `tryAlloc` (§2.4) |
| No unpredictable allocation latency | Static allocation + phase wrapper + sized pools (§2.5) |
| Remove padding and traverse by field | `MultiArrayList(T)` |
| Multiple flags | `packed struct(u8)` / `EnumSet` / `bit_set` |
| References | `enum(u32) { none = maxInt(u32), _ }` handles; offsets into relocatable slabs (§2.17) |
| Idle physical reclaim (keep VA) | Compress cold pages + `madvise(DONTNEED)` (§2.17, upstream) |
| Strings | Interning (bytes + `u32` offsets), SSO |
| Map lookup without `dupe` | `getOrPutAdapted` / `StringIndexAdapter` (§2.11) |
| Iterate all map entries | Prefer `ArrayHashMap` when that dominates |
| Optional scalar | Sentinel instead of `?u32` |
| Compile-time-known maps | `EnumArray` / `StaticStringMap.initComptime` |
| Read a large file | `File.createMemoryMap` + zero-copy slices |
| Growable ring | `Deque` (uses `Allocator.remap` when possible) |

**Compute faster**

| Goal | Use |
|---|---|
| Tables or specialization with no runtime cost | `comptime` blocks, `comptime` parameters, `inline for` |
| Data parallelism | `@Vector` + `@reduce`/`@select`/`@shuffle` (LLVM auto-vectorization is disabled in 0.16/0.17) |
| Byte search / compare | `std.mem.findScalar` / `std.mem.eql` (prefer over hand loops) |
| Sort | `std.sort.pdq` (default); see §5.10 |
| Unpredictable branches | `@intFromBool`, `@min`/`@max`, `@select`, `@branchHint(.unpredictable)` |
| State machine or interpreter | Labeled switch with `continue :label` |
| ISA-specific crypto/SIMD in one binary | `builtin.cpu.has` comptime `@import` (§5.2) |
| Cold path | `@branchHint(.cold)` |
| Disable checks locally | `@setRuntimeSafety(false)` in the smallest verified scope |
| Fast floating point | `@setFloatMode(.optimized)`, `@mulAdd` |
| Avoid division | Power-of-two capacity + `&`, compile-time divisor, `@divCeil` |
| Multithreading | `Io.Group.async`, per-task slots, `align(std.atomic.cache_line)` |
| Fewer system calls | Buffered `Io.Writer` + `flush`, `writeSplat` / drain, `Io.Batch`, io_uring |
| Format into memory | `Io.Writer.Allocating` (flush no-op until take) |
| Build options | `-O fast`, `-mcpu`, `-flto`, `-fstrip`, `-fsingle-threaded` |

---

## References

### Official sources

- [Zig downloads and release dates](https://ziglang.org/download/)
- Release notes: [0.17.0](https://ziglang.org/download/0.17.0/release-notes.html) · [0.16.0](https://ziglang.org/download/0.16.0/release-notes.html) · [0.15.1](https://ziglang.org/download/0.15.1/release-notes.html) · [0.14.0](https://ziglang.org/download/0.14.0/release-notes.html)
- [Zig 0.17.0 language reference](https://ziglang.org/documentation/0.17.0/)
- Zig 0.17.0 standard library sources: `lib/std/heap.zig`, `heap/SmpAllocator.zig`, `heap/SafeAllocator.zig`, `heap/ArenaAllocator.zig`, `heap/BufferFirstAllocator.zig`, `heap/memory_pool.zig`, `multi_array_list.zig`, `mem.zig`, `hash_map.zig`, `deque.zig`, `sort.zig`, `bit_set.zig`, `enums.zig`, `static_string_map.zig`, `simd.zig`, `crypto/aes.zig`, `Io.zig`, `Io/Writer.zig`, `Io/File/MemoryMap.zig`, `os/linux/IoUring.zig`, `start.zig`, `debug.zig`, `zig/Ast.zig`, `zig/Zir.zig`, `zig/tokenizer.zig`
- [PR #7920: AST memory layout redesign](https://github.com/ziglang/zig/pull/7920) · [PR #15569: InternPool](https://github.com/ziglang/zig/pull/15569)
- [Issue #15137: PGO (not planned)](https://github.com/ziglang/zig/issues/15137) · [Issue #237](https://github.com/ziglang/zig/issues/237) · [Issue #1018: function multiversioning](https://github.com/ziglang/zig/issues/1018)

### Community sources

- Andrew Kelley: [A Practical Guide to Applying Data-Oriented Design (Handmade Seattle 2021)](https://handmade-seattle.com/media-sub/practical-data-oriented-design) · [transcript](https://josherich.me/podcast/andrew-kelley-practical-data-oriented-design-dod)
- TigerBeetle: [TIGER_STYLE.md](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md)
- matklad: [Reserve First](https://matklad.github.io/2025/08/16/reserve-first.html) · [Zig defer Patterns](https://matklad.github.io/2024/03/21/defer-patterns.html) · [Push Ifs Up And Fors Down](https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html)
- Mitchell Hashimoto: [Zig Parser](https://mitchellh.com/zig/parser) · [Ghostty's runtime SIMD dispatch with Highway](https://whnex.com/items/49012420)
- Bun: [PR #19134: Use Highway SIMD](https://github.com/oven-sh/bun/pull/19134)
- [oma: runtime SIMD dispatch for Zig](https://github.com/ATTron/oma) · [ziggit discussion](https://ziggit.dev/t/oma-runtime-simd-dispatch-for-zig/14438)
- [poop](https://github.com/andrewrk/poop)
- Video inspiration: Liu Yanpeng, “Write Code to Save Memory”: <https://v.douyin.com/KoVqTHbb9L0/>

### Corpus / upstream performance case studies

- TigerBeetle: [`static_allocator.zig`](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/static_allocator.zig) · [`message_pool.zig`](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/message_pool.zig) · [performance concepts](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/concepts/performance.md)
- http.zig: [issue #176 RSS / retain](https://github.com/karlseguin/http.zig/issues/176) · [issue #199 buffer pool](https://github.com/karlseguin/http.zig/issues/199)
- Ghostty: terminal `Offset` / page mmap · [PR #13264 scrollback compression](https://github.com/ghostty-org/ghostty/pull/13264) · [PR #13537 resize/reflow](https://github.com/ghostty-org/ghostty/pull/13537)
- Zig language corpus (sparse clone): `zig-corpus/zig` @ `8f0c6ce4` (Codeberg `ziglang/zig`); compiler `src/InternPool.zig` cited for sharding
