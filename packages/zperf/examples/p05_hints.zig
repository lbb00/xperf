const std = @import("std");

fn parseDigit(c: u8) !u4 {
    if (c < '0' or c > '9') {
        @branchHint(.cold);
        return error.InvalidDigit;
    }
    return @intCast(c - '0');
}

fn reportError(msg: []const u8) void {
    @branchHint(.cold);
    std.log.err("{s}", .{msg});
}

fn sumWithPrefetch(xs: []const u64) u64 {
    var s: u64 = 0;
    for (xs, 0..) |x, i| {
        if (i + 64 < xs.len) {
// See the English guide for context.
            @prefetch(&xs[i + 64], .{ .rw = .read, .locality = 3, .cache = .data });
        }
        s +%= x;
    }
    return s;
}

test "hints" {
    try std.testing.expectEqual(@as(u4, 7), try parseDigit('7'));
    try std.testing.expectError(error.InvalidDigit, parseDigit('x'));
    var xs: [200]u64 = undefined;
    for (&xs, 0..) |*x, i| x.* = i;
    try std.testing.expectEqual(@as(u64, 19900), sumWithPrefetch(&xs));
    _ = &reportError;
}
