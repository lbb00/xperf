const std = @import("std");

/// See the English guide for context.
fn countLess(xs: []const u32, pivot: u32) usize {
    var n: usize = 0;
    for (xs) |x| n += @intFromBool(x < pivot);
    return n;
}

fn clampAll(xs: []i32, lo: i32, hi: i32) void {
    for (xs) |*x| x.* = @min(@max(x.*, lo), hi);
}

fn absBranchless(x: i32) u32 {
    const m = x >> 31;
    return @bitCast((x ^ m) -% m);
}

test "branchless" {
    try std.testing.expectEqual(@as(usize, 2), countLess(&.{ 5, 1, 9, 3 }, 4));
    var a = [_]i32{ -5, 3, 99 };
    clampAll(&a, 0, 10);
    try std.testing.expectEqualSlices(i32, &.{ 0, 3, 10 }, &a);
    try std.testing.expectEqual(@as(u32, 7), absBranchless(-7));
    try std.testing.expectEqual(@as(u32, 7), @abs(@as(i32, -7)));
}
