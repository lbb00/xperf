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

