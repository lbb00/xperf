const std = @import("std");

const Flags = packed struct(u8) {
    visible: bool,
    dirty: bool,
    selected: bool,
    layer: u3,
    _pad: u2 = 0,
};

// zperf-lint: ignore zp-packable-bools
const Loose = struct { visible: bool, dirty: bool, selected: bool, layer: u8 };

test "packed struct 把 4 个字段压进 1 字节" {
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Flags));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(Loose));

    var f: Flags = .{ .visible = true, .dirty = false, .selected = true, .layer = 5 };
    f.dirty = true;
    const raw: u8 = @bitCast(f);
    try std.testing.expectEqual(@as(u8, 0b00_101_111), raw);
    try std.testing.expect(f == @as(Flags, @bitCast(raw)));
}

test "u3 等窄整数在普通 struct/数组里仍按字节存储" {
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(u3));
    try std.testing.expectEqual(@as(usize, 3), @bitSizeOf(u3));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf([8]u3));

// See the English guide for context.
    var bytes: [3]u8 = @splat(0);
    for (0..8) |i| std.mem.writePackedInt(u3, &bytes, i * 3, @intCast(i), .little);
    try std.testing.expectEqual(@as(u3, 6), std.mem.readPackedInt(u3, &bytes, 6 * 3, .little));
}
