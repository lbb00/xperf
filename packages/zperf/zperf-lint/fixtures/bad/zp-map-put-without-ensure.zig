const std = @import("std");
pub fn fill(gpa: std.mem.Allocator, keys: []const []const u8) !void {
    var map: std.StringHashMapUnmanaged(u32) = .empty;
    defer map.deinit(gpa);
    for (keys) |k| {
        try map.put(gpa, k, 1);
    }
}
