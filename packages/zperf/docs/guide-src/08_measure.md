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

