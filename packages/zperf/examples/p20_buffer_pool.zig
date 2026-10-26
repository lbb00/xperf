const std = @import("std");
const builtin = @import("builtin");
const bench = @import("bench_jsonl.zig");

/// Compare equal-size buffer pool hit (tryAlloc/release) vs GPA alloc+free
/// for a fixed buffer size (Zig 0.17). Teaches m15 / http.zig size-class pools.
///
/// Hit path never calls the child allocator after warm-up. Miss path is not
/// timed here — see http.zig metrics for empty-pool fallbacks.

const buf_len: usize = 4096;
const pool_count: usize = 64;
const ops: u64 = 200_000;
const trials: usize = 7;

const BufferPool = struct {
    buffers: [][]u8,
    available: usize,
    buf_len: usize,

    fn init(gpa: std.mem.Allocator, count: usize, len: usize) !BufferPool {
        const buffers = try gpa.alloc([]u8, count);
        errdefer gpa.free(buffers);
        for (buffers) |*slot| {
            // zperf-lint: ignore zp-alloc-in-loop -- one-time pool warm-up, not a hot-path pattern
            slot.* = try gpa.alloc(u8, len);
        }
        return .{ .buffers = buffers, .available = count, .buf_len = len };
    }

    fn deinit(self: *BufferPool, gpa: std.mem.Allocator) void {
        for (self.buffers) |b| gpa.free(b);
        gpa.free(self.buffers);
        self.* = undefined;
    }

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

const PoolCtx = struct {
    pool: *BufferPool,
    sink: u64 = 0,
};

fn runPool(ptr: *anyopaque) void {
    const ctx: *PoolCtx = @ptrCast(@alignCast(ptr));
    var i: u64 = 0;
    while (i < ops) : (i += 1) {
        const buf = ctx.pool.tryAlloc() orelse unreachable;
        buf[0] = @truncate(i);
        buf[buf_len - 1] = @truncate(i >> 8);
        ctx.sink +%= buf[0];
        ctx.pool.release(buf);
    }
}

const GpaCtx = struct {
    gpa: std.mem.Allocator,
    sink: u64 = 0,
};

fn runGpa(ptr: *anyopaque) void {
    const ctx: *GpaCtx = @ptrCast(@alignCast(ptr));
    var i: u64 = 0;
    while (i < ops) : (i += 1) {
        // zperf-lint: ignore zp-alloc-in-loop zp-catch-unreachable-alloc -- deliberate pool-miss GPA baseline for the shootout
        const buf = ctx.gpa.alloc(u8, buf_len) catch unreachable;
        buf[0] = @truncate(i);
        buf[buf_len - 1] = @truncate(i >> 8);
        ctx.sink +%= buf[0];
        ctx.gpa.free(buf);
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

    // --- Pool hit (prewarmed; always tryAlloc succeeds) ---
    {
        var pool = try BufferPool.init(gpa, pool_count, buf_len);
        defer pool.deinit(gpa);
        var ctx: PoolCtx = .{ .pool = &pool };
        runPool(@ptrCast(&ctx)); // warmup
        const best = bench.bestNs(io, trials, runPool, @ptrCast(&ctx));
        var note_buf: [192]u8 = undefined;
        const note = try std.fmt.bufPrint(
            &note_buf,
            "best of {d}; {d} ops x {d}B; pool_count={d}; always-hit tryAlloc/release",
            .{ trials, ops, buf_len, pool_count },
        );
        try bench.writeLine(io, .{
            .name = "pool_hit_tryAlloc",
            .ns_per_op = bench.nsPerOp(best, ops),
            .iters = ops,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    // --- GPA alloc+free same size ---
    {
        var ctx: GpaCtx = .{ .gpa = gpa };
        runGpa(@ptrCast(&ctx));
        const best = bench.bestNs(io, trials, runGpa, @ptrCast(&ctx));
        var note_buf: [160]u8 = undefined;
        const note = try std.fmt.bufPrint(
            &note_buf,
            "best of {d}; {d} ops x {d}B alloc+free via {s}",
            .{ trials, ops, buf_len, gpaLabel() },
        );
        try bench.writeLine(io, .{
            .name = "pool_miss_gpa_alloc",
            .ns_per_op = bench.nsPerOp(best, ops),
            .iters = ops,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }
}
