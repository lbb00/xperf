const std = @import("std");
pub fn upperAll(gpa: std.mem.Allocator, words: []const []const u8) !usize {
    var total: usize = 0;
    for (words) |w| {
        const tmp = try gpa.alloc(u8, w.len);
        defer gpa.free(tmp);
        total += tmp.len;
    }
    return total;
}
