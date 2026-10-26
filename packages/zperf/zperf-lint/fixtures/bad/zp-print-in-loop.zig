const std = @import("std");
pub fn dump(xs: []const u32) void {
    for (xs, 0..) |x, i| {
        std.debug.print("{d}: {d}\n", .{ i, x });
    }
}
