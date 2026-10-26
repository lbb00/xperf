const std = @import("std");
const builtin = @import("builtin");
const bench = @import("bench_jsonl.zig");

/// Adjacent Atomic(u64) vs cache-line-padded counters under multi-threaded increments.

const incs_per_thread: u64 = if (builtin.mode == .debug) 20_000 else 2_000_000;
const trials: usize = if (builtin.mode == .debug) 1 else 5;
const thread_counts = if (builtin.mode == .debug) [_]usize{ 2 } else [_]usize{ 2, 4, 8 };

const PackedCounter = struct {
    value: std.atomic.Value(u64) = .init(0),
};

const PaddedCounter = struct {
    value: std.atomic.Value(u64) align(std.atomic.cache_line) = .init(0),
    // ensure the struct itself occupies a full line even if Value is smaller
    _pad: [std.atomic.cache_line - @sizeOf(std.atomic.Value(u64))]u8 = undefined,
};

const StartGate = struct {
    ready: std.atomic.Value(usize) = .init(0),
    go: std.atomic.Value(bool) = .init(false),
};

fn waitGo(gate: *StartGate, n_threads: usize) void {
    _ = gate.ready.fetchAdd(1, .seq_cst);
    while (!gate.go.load(.seq_cst)) {
        std.atomic.spinLoopHint();
    }
    _ = n_threads;
}

fn packedWorker(gate: *StartGate, c: *PackedCounter, n_threads: usize) void {
    waitGo(gate, n_threads);
    var i: u64 = 0;
    while (i < incs_per_thread) : (i += 1) {
        _ = c.value.fetchAdd(1, .monotonic);
    }
}

fn paddedWorker(gate: *StartGate, c: *PaddedCounter, n_threads: usize) void {
    waitGo(gate, n_threads);
    var i: u64 = 0;
    while (i < incs_per_thread) : (i += 1) {
        _ = c.value.fetchAdd(1, .monotonic);
    }
}

fn runPacked(io: std.Io, thread_n: usize) !i96 {
    var counters: [8]PackedCounter = @splat(.{});
    var gate: StartGate = .{};
    var threads: [8]std.Thread = undefined;

    var t: usize = 0;
    while (t < thread_n) : (t += 1) {
        threads[t] = try std.Thread.spawn(.{}, packedWorker, .{ &gate, &counters[t], thread_n });
    }
    while (gate.ready.load(.seq_cst) < thread_n) {
        std.atomic.spinLoopHint();
    }

    const t0: std.Io.Clock.Timestamp = .now(io, .awake);
    gate.go.store(true, .seq_cst);
    t = 0;
    while (t < thread_n) : (t += 1) threads[t].join();
    const ns = t0.untilNow(io).raw.nanoseconds;

    var total: u64 = 0;
    t = 0;
    while (t < thread_n) : (t += 1) total += counters[t].value.load(.monotonic);
    std.mem.doNotOptimizeAway(total);
    return ns;
}

fn runPadded(io: std.Io, thread_n: usize) !i96 {
    var counters: [8]PaddedCounter = @splat(.{});
    var gate: StartGate = .{};
    var threads: [8]std.Thread = undefined;

    var t: usize = 0;
    while (t < thread_n) : (t += 1) {
        threads[t] = try std.Thread.spawn(.{}, paddedWorker, .{ &gate, &counters[t], thread_n });
    }
    while (gate.ready.load(.seq_cst) < thread_n) {
        std.atomic.spinLoopHint();
    }

    const t0: std.Io.Clock.Timestamp = .now(io, .awake);
    gate.go.store(true, .seq_cst);
    t = 0;
    while (t < thread_n) : (t += 1) threads[t].join();
    const ns = t0.untilNow(io).raw.nanoseconds;

    var total: u64 = 0;
    t = 0;
    while (t < thread_n) : (t += 1) total += counters[t].value.load(.monotonic);
    std.mem.doNotOptimizeAway(total);
    return ns;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    _ = init.gpa;

    // Size assertions for the notes
    std.debug.assert(@sizeOf(PackedCounter) == @sizeOf(std.atomic.Value(u64)));
    std.debug.assert(@sizeOf(PaddedCounter) >= std.atomic.cache_line);

    for (thread_counts) |tn| {
        // Warmup
        _ = try runPacked(io, tn);
        _ = try runPadded(io, tn);

        var best_packed: i96 = std.math.maxInt(i96);
        var best_padded: i96 = std.math.maxInt(i96);
        var trial: usize = 0;
        while (trial < trials) : (trial += 1) {
            best_packed = @min(best_packed, try runPacked(io, tn));
            best_padded = @min(best_padded, try runPadded(io, tn));
        }

        const ops: u64 = incs_per_thread * tn;
        var note_buf: [220]u8 = undefined;

        {
            var name_buf: [32]u8 = undefined;
            const name = try std.fmt.bufPrint(&name_buf, "false_share_packed_t{d}", .{tn});
            const note = try std.fmt.bufPrint(&note_buf, "best of {d}; threads={d}; incs/thread={d}; adjacent Atomic(u64) size={d}; cache_line={d}", .{ trials, tn, incs_per_thread, @sizeOf(PackedCounter), std.atomic.cache_line });
            try bench.writeLine(io, .{
                .name = name,
                .ns_per_op = bench.nsPerOp(best_packed, ops),
                .iters = ops,
                .note = note,
            });
        }
        {
            var name_buf: [32]u8 = undefined;
            const name = try std.fmt.bufPrint(&name_buf, "false_share_padded_t{d}", .{tn});
            const note = try std.fmt.bufPrint(&note_buf, "best of {d}; threads={d}; incs/thread={d}; padded align(cache_line) size={d}", .{ trials, tn, incs_per_thread, @sizeOf(PaddedCounter) });
            try bench.writeLine(io, .{
                .name = name,
                .ns_per_op = bench.nsPerOp(best_padded, ops),
                .iters = ops,
                .note = note,
            });
        }
    }
}
