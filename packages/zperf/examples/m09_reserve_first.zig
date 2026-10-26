const std = @import("std");

/// See the English guide for context.
fn appendPair(gpa: std.mem.Allocator, keys: *std.ArrayList(u32), vals: *std.ArrayList(u64), k: u32, v: u64) !void {
    try keys.ensureUnusedCapacity(gpa, 1);
    try vals.ensureUnusedCapacity(gpa, 1);
    errdefer comptime unreachable;
    keys.appendAssumeCapacity(k);
    vals.appendAssumeCapacity(v);
}

test "reserve first" {
    const gpa = std.testing.allocator;
    var keys: std.ArrayList(u32) = .empty;
    defer keys.deinit(gpa);
    var vals: std.ArrayList(u64) = .empty;
    defer vals.deinit(gpa);

    try keys.ensureTotalCapacity(gpa, 1000);
    try vals.ensureTotalCapacity(gpa, 1000);
    for (0..1000) |i| try appendPair(gpa, &keys, &vals, @intCast(i), i * 2);
    try std.testing.expectEqual(@as(u64, 1998), vals.items[999]);
}
