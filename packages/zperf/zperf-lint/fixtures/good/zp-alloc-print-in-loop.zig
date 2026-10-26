const std = @import("std");
pub fn good(gpa: std.mem.Allocator, n: usize, id: u32) !usize {
    const text = try std.fmt.allocPrint(gpa, "{d}", .{id});
    defer gpa.free(text);
    var s: usize = 0;
    var i: usize = 0;
    while (i < n) : (i += 1) s += text.len;
    return s;
}
