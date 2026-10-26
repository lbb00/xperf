const std = @import("std");
pub fn grab(scratch: *[256]u8, n: usize) usize {
    var total: usize = 0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        @memset(scratch, 0);
        total += scratch.len;
    }
    return total;
}
