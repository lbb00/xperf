const std = @import("std");

// zperf-lint: ignore zp-optional-scalar-field
const WithOpt = struct { parent: ?u32, depth: u32 };
const WithSentinel = struct {
    parent: u32,
    depth: u32,
    const none = std.math.maxInt(u32);
};

test "optional 的代价与哨兵值" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(?u32));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(*u8));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(?*u8));
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(WithOpt));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(WithSentinel));
// See the English guide for context.
}

test "error union 与切片的大小" {
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(anyerror));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(anyerror!u64));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf([]u8)); // ptr + usize len
    try std.testing.expectEqual(@as(usize, 8), @sizeOf([*:0]const u8));
// See the English guide for context.
    const Thin = extern struct { ptr: [*]const u8, len: u32 };
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Thin));
    const ThinSoA = struct { offset: u32, len: u32 };
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(ThinSoA));
}
