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
