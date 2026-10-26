const std = @import("std");

const Mesh = struct {
    xs: []f32,
    scale: f32,

/// See the English guide for context.
    fn scaleSlow(self: *Mesh) void {
        for (self.xs) |*x| x.* *= self.scale;
    }
/// See the English guide for context.
    fn scaleFast(self: *Mesh) void {
        scaleKernel(self.xs, self.scale);
    }
};

fn scaleKernel(xs: []f32, scale: f32) void {
    for (xs) |*x| x.* *= scale;
}

/// See the English guide for context.
fn sum4(xs: []const u64) u64 {
    var acc: [4]u64 = @splat(0);
    var i: usize = 0;
    while (i + 4 <= xs.len) : (i += 4) {
        inline for (0..4) |k| acc[k] +%= xs[i + k];
    }
    var s = acc[0] +% acc[1] +% acc[2] +% acc[3];
    for (xs[i..]) |x| s +%= x;
    return s;
}

/// See the English guide for context.
const Big = struct { data: [256]u8 };
fn checksum(b: *const Big) u32 {
    var s: u32 = 0;
    for (b.data) |x| s +%= x;
    return s;
}

/// See the English guide for context.
inline fn sq(x: f32) f32 {
    return x * x;
}

test "hot loops" {
    var data = [_]f32{ 1, 2, 3 };
    var m: Mesh = .{ .xs = &data, .scale = 2 };
    m.scaleSlow();
    m.scaleFast();
    try std.testing.expectEqual(@as(f32, 12), data[2]);
    try std.testing.expectEqual(@as(u64, 15), sum4(&.{ 1, 2, 3, 4, 5 }));
    const big: Big = .{ .data = @splat(1) };
    try std.testing.expectEqual(@as(u32, 256), checksum(&big));
    try std.testing.expectEqual(@as(f32, 9), sq(3));
}
