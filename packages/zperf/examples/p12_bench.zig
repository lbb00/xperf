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
