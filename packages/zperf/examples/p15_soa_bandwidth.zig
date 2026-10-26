const std = @import("std");
const builtin = @import("builtin");
const bench = @import("bench_jsonl.zig");

/// AoS vs MultiArrayList (SoA) vs parallel arrays: sum one hot field.
/// Fat Element so AoS pays padding + cold-field cache traffic.

const n: usize = if (builtin.mode == .debug) 50_000 else 4_000_000;
const trials: usize = if (builtin.mode == .debug) 2 else 7;
const passes: u64 = if (builtin.mode == .debug) 1 else 4;

const Element = struct {
    hp: u32,
    kind: u8,
    _pad: [3]u8 = .{ 0, 0, 0 },
    pos_x: f32,
    pos_y: f32,
    cold_a: u64,
    cold_b: u64,
};

const AosCtx = struct {
    items: []const Element,
    sink: u64 = 0,
};

fn runAos(ptr: *anyopaque) void {
    const ctx: *AosCtx = @ptrCast(@alignCast(ptr));
    var p: u64 = 0;
    while (p < passes) : (p += 1) {
        var sum: u64 = 0;
        // zperf-lint: ignore zp-aos-single-field -- AoS baseline for SoA bandwidth comparison
        for (ctx.items) |e| sum +%= e.hp;
        ctx.sink +%= sum;
    }
}

const SoaCtx = struct {
    hps: []const u32,
    sink: u64 = 0,
};

fn runSoa(ptr: *anyopaque) void {
    const ctx: *SoaCtx = @ptrCast(@alignCast(ptr));
    var p: u64 = 0;
    while (p < passes) : (p += 1) {
        var sum: u64 = 0;
        for (ctx.hps) |hp| sum +%= hp;
        ctx.sink +%= sum;
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    const aos = try gpa.alloc(Element, n);
    defer gpa.free(aos);
    var mal: std.MultiArrayList(Element) = .empty;
    defer mal.deinit(gpa);
    try mal.ensureTotalCapacity(gpa, n);

    var i: usize = 0;
    while (i < n) : (i += 1) {
        const e: Element = .{
            .hp = @truncate(i *% 17 +% 1),
            .kind = @truncate(i),
            .pos_x = @floatFromInt(i),
            .pos_y = @floatFromInt(i *% 3),
            .cold_a = i,
            .cold_b = ~i,
        };
        aos[i] = e;
        mal.appendAssumeCapacity(e);
    }

    const slice = mal.slice();
    const hps = slice.items(.hp);

    // Parallel arrays (explicit SoA without MultiArrayList)
    const parallel_hp = try gpa.alloc(u32, n);
    defer gpa.free(parallel_hp);
    @memcpy(parallel_hp, hps);

    const bytes_aos_hot = n * @sizeOf(Element) * passes;
    const bytes_soa_hot = n * @sizeOf(u32) * passes;

    // --- AoS ---
    {
        var ctx: AosCtx = .{ .items = aos };
        runAos(@ptrCast(&ctx));
        const best = bench.bestNs(io, trials, runAos, @ptrCast(&ctx));
        var note_buf: [192]u8 = undefined;
        const note = try std.fmt.bufPrint(&note_buf, "best of {d}; N={d} passes={d}; Element={d}B; bytes_touched≈{d}; sum hp only", .{ trials, n, passes, @sizeOf(Element), bytes_aos_hot });
        try bench.writeLine(io, .{
            .name = "soa_aos_sum_hp",
            .ns_per_op = bench.nsPerOp(best, passes),
            .iters = passes,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // --- MultiArrayList SoA ---
    {
        var ctx: SoaCtx = .{ .hps = hps };
        runSoa(@ptrCast(&ctx));
        const best = bench.bestNs(io, trials, runSoa, @ptrCast(&ctx));
        var note_buf: [192]u8 = undefined;
        const note = try std.fmt.bufPrint(&note_buf, "best of {d}; N={d} passes={d}; MultiArrayList.items(.hp); bytes_touched≈{d}", .{ trials, n, passes, bytes_soa_hot });
        try bench.writeLine(io, .{
            .name = "soa_mal_sum_hp",
            .ns_per_op = bench.nsPerOp(best, passes),
            .iters = passes,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // --- Parallel arrays ---
    {
        var ctx: SoaCtx = .{ .hps = parallel_hp };
        runSoa(@ptrCast(&ctx));
        const best = bench.bestNs(io, trials, runSoa, @ptrCast(&ctx));
        var note_buf: [192]u8 = undefined;
        const note = try std.fmt.bufPrint(&note_buf, "best of {d}; N={d} passes={d}; parallel []u32; bytes_touched≈{d}", .{ trials, n, passes, bytes_soa_hot });
        try bench.writeLine(io, .{
            .name = "soa_parallel_sum_hp",
            .ns_per_op = bench.nsPerOp(best, passes),
            .iters = passes,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }
}
