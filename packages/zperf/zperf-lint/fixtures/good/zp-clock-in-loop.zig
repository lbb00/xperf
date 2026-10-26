const std = @import("std");
pub fn good(io: std.Io, n: u32) i64 {
    const t = std.Io.Clock.awake.now(io).nanoseconds;
    var s: i64 = 0;
    var i: u32 = 0;
    while (i < n) : (i += 1) s ^= t;
    return s;
}
