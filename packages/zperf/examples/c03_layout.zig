const std = @import("std");

// See the English guide for context.
// See the English guide for context.
const Bad = extern struct { a: u8, b: u64, c: u8 }; // 1 + 7pad + 8 + 1 + 7pad = 24
const Good = extern struct { b: u64, a: u8, c: u8 }; // 8 + 1 + 1 + 6pad = 16
const Auto = struct { a: u8, b: u64, c: u8 };

// See the English guide for context.
const Packed1 = extern struct { a: u8, b: u32 align(1) };

test "sizeof/alignof/offsetof 对应" {
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(Bad));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Good));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(Bad, "b"));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(Good));
    try std.testing.expect(@sizeOf(Auto) <= 16);
    try std.testing.expectEqual(@as(usize, 5), @sizeOf(Packed1));
    try std.testing.expectEqual(@as(usize, 1), @offsetOf(Packed1, "b"));
}
