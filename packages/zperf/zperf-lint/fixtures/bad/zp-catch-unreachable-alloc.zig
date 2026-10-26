const std = @import("std");
pub fn push(gpa: std.mem.Allocator, list: *std.ArrayList(u8), b: u8) void {
    list.append(gpa, b) catch unreachable;
}
