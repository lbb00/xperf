const std = @import("std");
pub fn push(gpa: std.mem.Allocator, list: *std.ArrayList(u8), b: u8) !void {
    try list.append(gpa, b);
}
pub fn parse(s: []const u8) u8 {
    return std.fmt.parseInt(u8, s, 10) catch unreachable;
}
