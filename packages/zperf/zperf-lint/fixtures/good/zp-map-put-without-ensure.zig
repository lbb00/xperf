const std = @import("std");
pub fn fill(gpa: std.mem.Allocator, keys: []const []const u8) !void {
    var map: std.StringHashMapUnmanaged(u32) = .empty;
    defer map.deinit(gpa);
    try map.ensureTotalCapacity(gpa, keys.len);
    for (keys) |k| {
        try map.put(gpa, k, 1);
    }
}
pub fn arenaFill(arena: std.mem.Allocator, keys: []const []const u8) !void {
    var map: std.StringHashMapUnmanaged(u32) = .empty;
    for (keys) |k| {
        try map.put(arena, k, 1);
    }
}
