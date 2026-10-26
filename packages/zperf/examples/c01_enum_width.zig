const std = @import("std");

// See the English guide for context.
const Color = enum { red, green, blue };
const Opcode = enum(u8) { nop, add, sub, _ };

test "enum 大小" {
    try std.testing.expectEqual(u2, @typeInfo(Color).@"enum".tag_type);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Color));
    try std.testing.expectEqual(@as(usize, 2), @bitSizeOf(Color));
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Opcode));
    const op: Opcode = @fromBackingInt(@as(u8, 200));
    try std.testing.expect(op != .add);
}
