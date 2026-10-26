const std = @import("std");
pub const keywords = std.StaticStringMap(u8).initComptime(.{
    .{ "if", 1 }, .{ "else", 2 }, .{ "while", 3 },
});
pub fn index(gpa: std.mem.Allocator, names: []const []const u8) !std.StringHashMapUnmanaged(u32) {
    var map: std.StringHashMapUnmanaged(u32) = .empty;
    errdefer map.deinit(gpa);
    try map.ensureTotalCapacity(gpa, names.len);
    for (names, 0..) |n, i| try map.put(gpa, n, @intCast(i));
    return map;
}
