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

**Anti-patterns:** `file.writer(io, &.{})` uses an empty buffer and can issue a system call for every write. Calling `std.debug.print` in a hot loop locks stderr and uses only a 64-byte buffer (see `lib/std/debug.zig`). zperf-lint rules zp-unbuffered-io and zp-print-hot report these patterns.

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

