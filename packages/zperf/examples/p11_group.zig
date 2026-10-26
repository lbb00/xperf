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
