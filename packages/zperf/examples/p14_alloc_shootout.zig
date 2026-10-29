const std = @import("std");
const builtin = @import("builtin");
const bench = @import("bench_jsonl.zig");

// zperf-lint: ignore-file zp-alloc-hot zp-catch-unreachable-alloc -- intentional GPA/arena/FBA alloc shootout baseline

/// Compare general-purpose alloc+free vs arena reset vs FixedBufferAllocator
/// for a fixed per-request allocation pattern (Zig 0.17).
///
/// Pattern per request: allocate `blocks` buffers of `block_size`, touch each,
/// then free (GPA) or reset (arena / FBA).

const blocks: usize = 8;
const block_size: usize = 64;
const requests: u64 = 50_000;
const trials: usize = 7;

const GpaCtx = struct {
    gpa: std.mem.Allocator,
    sink: u64 = 0,
};

fn runGpa(ptr: *anyopaque) void {
    const ctx: *GpaCtx = @ptrCast(@alignCast(ptr));
    var r: u64 = 0;
    while (r < requests) : (r += 1) {
        var i: usize = 0;
        var ptrs: [blocks][]u8 = undefined;
        while (i < blocks) : (i += 1) {
            ptrs[i] = ctx.gpa.alloc(u8, block_size) catch unreachable;
            ptrs[i][0] = @truncate(r);
            ptrs[i][block_size - 1] = @truncate(i);
        }
        i = 0;
        while (i < blocks) : (i += 1) {
            ctx.sink +%= ptrs[i][0];
            ctx.gpa.free(ptrs[i]);
        }
    }
}

const ArenaCtx = struct {
    arena: *std.heap.ArenaAllocator,
    sink: u64 = 0,
};

fn runArena(ptr: *anyopaque) void {
    const ctx: *ArenaCtx = @ptrCast(@alignCast(ptr));
    var r: u64 = 0;
    while (r < requests) : (r += 1) {
        defer _ = ctx.arena.reset(.retain_capacity);
        const a = ctx.arena.allocator();
        var i: usize = 0;
        while (i < blocks) : (i += 1) {
            const buf = a.alloc(u8, block_size) catch unreachable;
            buf[0] = @truncate(r);
            buf[block_size - 1] = @truncate(i);
            ctx.sink +%= buf[0];
        }
    }
}

const FbaCtx = struct {
    fba: *std.heap.FixedBufferAllocator,
    sink: u64 = 0,
};

fn runFba(ptr: *anyopaque) void {
    const ctx: *FbaCtx = @ptrCast(@alignCast(ptr));
    var r: u64 = 0;
    while (r < requests) : (r += 1) {
        ctx.fba.reset();
        const a = ctx.fba.allocator();
        var i: usize = 0;
        while (i < blocks) : (i += 1) {
            const buf = a.alloc(u8, block_size) catch unreachable;
            buf[0] = @truncate(r);
            buf[block_size - 1] = @truncate(i);
            ctx.sink +%= buf[0];
        }
    }
}

fn gpaLabel() []const u8 {
    return switch (builtin.mode) {
        .debug, .safe => "safe_or_debug_gpa",
        .fast, .small => if (builtin.link_libc)
            "c_allocator"
        else if (!builtin.single_threaded)
            "smp_allocator"
        else
            "page_allocator",
    };
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    // --- GPA / smp / c: alloc+free ---
    {
        var ctx: GpaCtx = .{ .gpa = gpa };
        runGpa(@ptrCast(&ctx)); // warmup
        const best = bench.bestNs(io, trials, runGpa, @ptrCast(&ctx));
        var note_buf: [128]u8 = undefined;
        const note = try std.fmt.bufPrint(&note_buf, "best of {d}; {d} req x {d}x{d}B alloc+free via {s}", .{ trials, requests, blocks, block_size, gpaLabel() });
        try bench.writeLine(io, .{
            .name = "alloc_gpa_free",
            .ns_per_op = bench.nsPerOp(best, requests),
            .iters = requests,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // --- Arena + retain_capacity ---
    {
        var arena_state: std.heap.ArenaAllocator = .init(gpa);
        defer arena_state.deinit();
        var ctx: ArenaCtx = .{ .arena = &arena_state };
        runArena(@ptrCast(&ctx));
        const best = bench.bestNs(io, trials, runArena, @ptrCast(&ctx));
        var note_buf: [128]u8 = undefined;
        const note = try std.fmt.bufPrint(&note_buf, "best of {d}; {d} req x {d}x{d}B; arena.reset(.retain_capacity)", .{ trials, requests, blocks, block_size });
        try bench.writeLine(io, .{
            .name = "alloc_arena_retain",
            .ns_per_op = bench.nsPerOp(best, requests),
            .iters = requests,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // --- FixedBufferAllocator ---
    {
        var storage: [blocks * block_size + 256]u8 = undefined;
        var fba_state: std.heap.FixedBufferAllocator = .init(&storage);
        var ctx: FbaCtx = .{ .fba = &fba_state };
        runFba(@ptrCast(&ctx));
        const best = bench.bestNs(io, trials, runFba, @ptrCast(&ctx));
        var note_buf: [128]u8 = undefined;
        const note = try std.fmt.bufPrint(&note_buf, "best of {d}; {d} req x {d}x{d}B; FBA.reset each req", .{ trials, requests, blocks, block_size });
        try bench.writeLine(io, .{
            .name = "alloc_fba_reset",
            .ns_per_op = bench.nsPerOp(best, requests),
            .iters = requests,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }
}
