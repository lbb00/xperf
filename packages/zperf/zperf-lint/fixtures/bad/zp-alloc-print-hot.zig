const std = @import("std");
pub fn bad(gpa: std.mem.Allocator, n: usize, id: u32) !usize {
    var s: usize = 0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const text = try std.fmt.allocPrint(gpa, "{d}", .{id});
        s += text.len;
        gpa.free(text);
    }
    return s;
}
