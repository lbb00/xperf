const std = @import("std");
pub fn squares(gpa: std.mem.Allocator, xs: []const u32) !std.ArrayList(u32) {
    var out: std.ArrayList(u32) = .empty;
    errdefer out.deinit(gpa);
    for (xs) |x| {
        try out.append(gpa, x * x);
    }
    return out;
}
