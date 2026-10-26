const std = @import("std");

/// See the English guide for context.
const Ring = struct {
    const cap = 1024;
    comptime {
        std.debug.assert(std.math.isPowerOfTwo(cap));
    }
    buf: [cap]u32 = undefined,
    head: u32 = 0,

    fn push(r: *Ring, v: u32) void {
        r.buf[r.head & (cap - 1)] = v;
        r.head +%= 1;
    }
};

test "整数技巧" {
    var r: Ring = .{};
    for (0..2000) |i| r.push(@intCast(i));
    try std.testing.expectEqual(@as(u32, 1999), r.buf[1999 & 1023]);

// See the English guide for context.
    const x: u32 = 1000;
    try std.testing.expectEqual(@as(u32, 142), x / 7);
    try std.testing.expectEqual(@as(u32, 3), @divCeil(@as(u32, 7), 3));
    try std.testing.expectEqual(@as(u32, 125), x >> 3);

    const r2 = @mulWithOverflow(@as(u8, 200), 2);
    try std.testing.expectEqual(@as(u1, 1), r2[1]);
    try std.testing.expectEqual(@as(u8, 255), @as(u8, 200) +| 100);
    try std.testing.expectEqual(@as(u32, 3), @popCount(@as(u32, 0b1011)));
    try std.testing.expectEqual(@as(u32, 28), @clz(@as(u32, 0b1011)));
    try std.testing.expectEqual(@as(u64, 0x0807060504030201), @byteSwap(@as(u64, 0x0102030405060708)));
    try std.testing.expectEqual(@as(u32, 16), try std.math.ceilPowerOfTwo(u32, 9));
}
