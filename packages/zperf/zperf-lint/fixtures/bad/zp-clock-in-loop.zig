const std = @import("std");
pub fn bad(io: std.Io, n: u32) i64 {
    var s: i64 = 0;
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        s ^= std.Io.Clock.awake.now(io).nanoseconds;
    }
    return s;
}
