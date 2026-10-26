const std = @import("std");
const builtin = @import("builtin");
const bench = @import("bench_jsonl.zig");

/// Many small writes: empty Writer buffer vs 4 KiB buffer (Writergate §6.3).
/// Default: JSONL wall-time shootout. Arg `empty` or `4kib`: one-shot for strace -c.

const n_writes: usize = if (builtin.mode == .debug) 2_000 else 100_000;
const write_len: usize = 16;
const trials: usize = if (builtin.mode == .debug) 2 else 5;
const payload = "0123456789abcdef"; // 16 bytes

const Ctx = struct {
    io: std.Io,
    file: std.Io.File,
    buffer: []u8,
    sink: u64 = 0,
};

fn runWrites(ptr: *anyopaque) void {
    const ctx: *Ctx = @ptrCast(@alignCast(ptr));
    var w = ctx.file.writerStreaming(ctx.io, ctx.buffer);
    var i: usize = 0;
    while (i < n_writes) : (i += 1) {
        w.interface.writeAll(payload) catch {};
        ctx.sink +%= 1;
    }
    w.interface.flush() catch {};
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const argv = try init.minimal.args.toSlice(init.arena.allocator());
    // argv[0]=exe; optional argv[1]=empty|4kib for one-shot strace helper
    const mode_arg: ?[]const u8 = if (argv.len >= 2) argv[1] else null;

    const file = try std.Io.Dir.openFileAbsolute(io, "/dev/null", .{ .mode = .write_only });
    defer file.close(io);

    if (payload.len != write_len) return error.PayloadLenMismatch;

    var empty_buf: [0]u8 = .{};
    var kib4: [4096]u8 = undefined;

    if (mode_arg) |m| {
        const buf: []u8 = if (std.mem.eql(u8, m, "empty"))
            &empty_buf
        else if (std.mem.eql(u8, m, "4kib"))
            kib4[0..]
        else
            return error.UnknownMode;
        var ctx: Ctx = .{ .io = io, .file = file, .buffer = buf };
        runWrites(@ptrCast(&ctx));
        std.mem.doNotOptimizeAway(ctx.sink);
        return;
    }

    // warmup both paths
    {
        var ctx: Ctx = .{ .io = io, .file = file, .buffer = &empty_buf };
        runWrites(@ptrCast(&ctx));
    }
    {
        var ctx: Ctx = .{ .io = io, .file = file, .buffer = kib4[0..] };
        runWrites(@ptrCast(&ctx));
    }

    {
        var ctx: Ctx = .{ .io = io, .file = file, .buffer = &empty_buf };
        const best = bench.bestNs(io, trials, runWrites, @ptrCast(&ctx));
        var note_buf: [256]u8 = undefined;
        const note = try std.fmt.bufPrint(&note_buf, "best of {d}; N={d} x {d}B to /dev/null; empty Writer buffer (&{{}}); expect ~1 write syscall per writeAll", .{ trials, n_writes, write_len });
        try bench.writeLine(io, .{
            .name = "io_write_empty_buf",
            .ns_per_op = bench.nsPerOp(best, n_writes),
            .iters = n_writes,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }

    {
        var ctx: Ctx = .{ .io = io, .file = file, .buffer = kib4[0..] };
        const best = bench.bestNs(io, trials, runWrites, @ptrCast(&ctx));
        var note_buf: [256]u8 = undefined;
        const note = try std.fmt.bufPrint(&note_buf, "best of {d}; N={d} x {d}B to /dev/null; 4KiB Writer buffer; fewer write syscalls after coalesce+flush", .{ trials, n_writes, write_len });
        try bench.writeLine(io, .{
            .name = "io_write_4kib_buf",
            .ns_per_op = bench.nsPerOp(best, n_writes),
            .iters = n_writes,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }
}
