const std = @import("std");

/// See the English guide for context.
fn sumUnchecked(xs: []const u32) u32 {
    @setRuntimeSafety(false);
    var s: u32 = 0;
    for (xs) |x| s += x;
    return s;
}

fn dotFast(a: []const f32, b: []const f32) f32 {
    @setFloatMode(.optimized);
    std.debug.assert(a.len == b.len);
    var s: f32 = 0;
    for (a, b) |x, y| s += x * y;
    return s;
}

test "safety toggles" {
    try std.testing.expectEqual(@as(u32, 6), sumUnchecked(&.{ 1, 2, 3 }));
    try std.testing.expectApproxEqAbs(@as(f32, 11), dotFast(&.{ 1, 2 }, &.{ 3, 4 }), 1e-6);
    try std.testing.expectEqual(@as(f32, 7), @mulAdd(f32, 2, 3, 1));
}
