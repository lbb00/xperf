const std = @import("std");
const builtin = @import("builtin");
const bench = @import("bench_jsonl.zig");

/// Explicit @Vector sum vs scalar loop over f32 (auto-vec disabled in 0.16/0.17).

const n: usize = if (builtin.mode == .debug) 100_000 else 8_000_000;
const trials: usize = if (builtin.mode == .debug) 2 else 7;
const passes: u64 = if (builtin.mode == .debug) 1 else 4;

const lanes = std.simd.suggestVectorLength(f32) orelse 8;
const V = @Vector(lanes, f32);

const Ctx = struct {
    xs: []const f32,
    sink: f32 = 0,
};

fn sumScalar(xs: []const f32) f32 {
    var s: f32 = 0;
    for (xs) |x| s += x;
    return s;
}

fn sumSimd(xs: []const f32) f32 {
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

fn runScalar(ptr: *anyopaque) void {
    const ctx: *Ctx = @ptrCast(@alignCast(ptr));
    var p: u64 = 0;
    while (p < passes) : (p += 1) {
        const r = sumScalar(ctx.xs);
        std.mem.doNotOptimizeAway(r);
        ctx.sink += r;
    }
}

fn runSimd(ptr: *anyopaque) void {
    const ctx: *Ctx = @ptrCast(@alignCast(ptr));
    var p: u64 = 0;
    while (p < passes) : (p += 1) {
        const r = sumSimd(ctx.xs);
        std.mem.doNotOptimizeAway(r);
        ctx.sink += r;
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    const xs = try gpa.alloc(f32, n);
    defer gpa.free(xs);
    for (xs, 0..) |*x, i| x.* = @floatFromInt((i % 97) + 1);

    {
        var ctx: Ctx = .{ .xs = xs };
        runScalar(@ptrCast(&ctx));
        const best = bench.bestNs(io, trials, runScalar, @ptrCast(&ctx));
        var note_buf: [192]u8 = undefined;
        const note = try std.fmt.bufPrint(&note_buf, "best of {d}; N={d} passes={d}; scalar f32 sum; auto-vec OFF in 0.17", .{ trials, n, passes });
        try bench.writeLine(io, .{
            .name = "simd_scalar_sum_f32",
            .ns_per_op = bench.nsPerOp(best, passes),
            .iters = passes,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    {
        var ctx: Ctx = .{ .xs = xs };
        runSimd(@ptrCast(&ctx));
        const best = bench.bestNs(io, trials, runSimd, @ptrCast(&ctx));
        var note_buf: [192]u8 = undefined;
        const note = try std.fmt.bufPrint(&note_buf, "best of {d}; N={d} passes={d}; @Vector({d},f32) + @reduce.Add; suggestVectorLength", .{ trials, n, passes, lanes });
        try bench.writeLine(io, .{
            .name = "simd_vector_sum_f32",
            .ns_per_op = bench.nsPerOp(best, passes),
            .iters = passes,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }
}
