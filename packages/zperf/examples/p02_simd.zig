const std = @import("std");

const lanes = std.simd.suggestVectorLength(f32) orelse 4;
const V = @Vector(lanes, f32);

/// See the English guide for context.
fn sum(xs: []const f32) f32 {
    var acc: V = @splat(0);
    var i: usize = 0;
    while (i + lanes <= xs.len) : (i += lanes) {
        const v: V = xs[i..][0..lanes].*;
        acc += v;
    }
    var s = @reduce(.Add, acc);
    while (i < xs.len) : (i += 1) s += xs[i];
    return s;
}

/// See the English guide for context.
fn findByte(hay: []const u8, needle: u8) ?usize {
    const n = 16;
    const B = @Vector(n, u8);
    const nv: B = @splat(needle);
    var i: usize = 0;
    while (i + n <= hay.len) : (i += n) {
        const chunk: B = hay[i..][0..n].*;
        const mask: u16 = @bitCast(chunk == nv);
        if (mask != 0) return i + @ctz(mask);
    }
    while (i < hay.len) : (i += 1) if (hay[i] == needle) return i;
    return null;
}

test "simd" {
    var xs: [37]f32 = undefined;
    for (&xs, 0..) |*x, i| x.* = @floatFromInt(i);
    try std.testing.expectEqual(@as(f32, 666), sum(&xs));
    try std.testing.expectEqual(@as(?usize, 20), findByte("aaaaaaaaaaaaaaaaaaaaXaaa", 'X'));
    try std.testing.expectEqual(@as(?usize, 20), std.mem.findScalar(u8, "aaaaaaaaaaaaaaaaaaaaXaaa", 'X'));
}

test "@shuffle / @select" {
    const a: @Vector(4, i32) = .{ 1, 2, 3, 4 };
    const b: @Vector(4, i32) = .{ 10, 20, 30, 40 };
    const rev = @shuffle(i32, a, undefined, @Vector(4, i32){ 3, 2, 1, 0 });
    try std.testing.expectEqual(@Vector(4, i32){ 4, 3, 2, 1 }, rev);
    const mx = @select(i32, a > @as(@Vector(4, i32), @splat(2)), a, b);
    try std.testing.expectEqual(@Vector(4, i32){ 10, 20, 3, 4 }, mx);
}
