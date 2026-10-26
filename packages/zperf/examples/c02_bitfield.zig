const std = @import("std");

// C:
// struct Hdr { unsigned version:4; unsigned ihl:4; unsigned dscp:6; unsigned ecn:2; };
// See the English guide for context.
// See the English guide for context.
const Hdr = packed struct(u16) {
    ihl: u4,
    version: u4,
    ecn: u2,
    dscp: u6,
};

const Signedness = struct { delta: i7, count: u7 };

test "packed struct 等价 C 位域" {
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(Hdr));
    try std.testing.expectEqual(@as(usize, 16), @bitSizeOf(Hdr));
    try std.testing.expectEqual(@as(u16, 8), @bitOffsetOf(Hdr, "ecn"));
    const h: Hdr = .{ .version = 4, .ihl = 5, .dscp = 0, .ecn = 0 };
    const raw: u16 = @bitCast(h);
    try std.testing.expectEqual(@as(u16, 0x45), raw);
// See the English guide for context.
    try std.testing.expectEqual(raw, @backingInt(h));
// See the English guide for context.
    try std.testing.expectEqual(@as(i7, -64), std.math.minInt(i7));
    try std.testing.expectEqual(@as(u7, 127), std.math.maxInt(u7));
    _ = Signedness;
}
