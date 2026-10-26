const std = @import("std");
pub fn grab(gpa: std.mem.Allocator, n: usize) !usize {
    var total: usize = 0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const buf = try gpa.alloc(u8, 256);
        defer gpa.free(buf);
        total += buf.len;
    }
    return total;
}
