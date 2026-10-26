const std = @import("std");

/// See the English guide for context.
const crc_table: [256]u32 = blk: {
    @setEvalBranchQuota(256 * 8 * 4);
    var t: [256]u32 = undefined;
    for (&t, 0..) |*e, i| {
        var c: u32 = @intCast(i);
        for (0..8) |_| c = if (c & 1 != 0) 0xEDB88320 ^ (c >> 1) else c >> 1;
        e.* = c;
    }
    break :blk t;
};

fn crc32(data: []const u8) u32 {
    var c: u32 = 0xFFFFFFFF;
    for (data) |b| c = crc_table[(c ^ b) & 0xFF] ^ (c >> 8);
    return ~c;
}

/// See the English guide for context.
fn dot(comptime N: usize, a: [N]f32, b: [N]f32) f32 {
    var s: f32 = 0;
    inline for (0..N) |i| s += a[i] * b[i];
    return s;
}

test "comptime LUT" {
    try std.testing.expectEqual(std.hash.Crc32.hash("hello"), crc32("hello"));
    try std.testing.expectEqual(@as(f32, 11), dot(2, .{ 1, 2 }, .{ 3, 4 }));
}
