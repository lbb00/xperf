const std = @import("std");
var seen: [4096]bool = undefined;
pub fn mark(gpa: std.mem.Allocator, n: usize) ![]bool {
    const flags = try gpa.alloc(bool, n);
    return flags;
}
pub fn count(flags: []const bool) usize {
    var c: usize = 0;
    for (flags) |f| c += @intFromBool(f);
    return c;
}
