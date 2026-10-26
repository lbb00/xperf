const std = @import("std");

/// See the English guide for context.
const Value = packed struct(u64) {
    bits: u64,

    const qnan: u64 = 0x7ff8_0000_0000_0000;
    const tag_int: u64 = 0x0001_0000_0000_0000;
    const tag_ptr: u64 = 0x0002_0000_0000_0000;
    const payload_mask: u64 = 0x0000_ffff_ffff_ffff;

    fn fromFloat(f: f64) Value {
        return .{ .bits = @bitCast(f) };
    }
    fn fromInt(i: u32) Value {
        return .{ .bits = qnan | tag_int | i };
    }
    fn fromPtr(p: *const anyopaque) Value {
        return .{ .bits = qnan | tag_ptr | (@intFromPtr(p) & payload_mask) };
    }
    fn isFloat(v: Value) bool {
        return (v.bits & qnan) != qnan or (v.bits & (tag_int | tag_ptr)) == 0;
    }
    fn isInt(v: Value) bool {
        return (v.bits & (qnan | tag_int | tag_ptr)) == (qnan | tag_int);
    }
    fn asInt(v: Value) u32 {
        return @truncate(v.bits & payload_mask);
    }
    fn asFloat(v: Value) f64 {
        return @bitCast(v.bits);
    }
};

test "NaN-boxing" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Value));
    const a: Value = .fromFloat(3.5);
    const b: Value = .fromInt(42);
    try std.testing.expect(a.isFloat() and !a.isInt());
    try std.testing.expectEqual(@as(f64, 3.5), a.asFloat());
    try std.testing.expect(b.isInt() and !b.isFloat());
    try std.testing.expectEqual(@as(u32, 42), b.asInt());
    var x: u32 = 0;
    try std.testing.expect(!Value.fromPtr(&x).isFloat());
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(union(enum) { f: f64, i: u32, p: *anyopaque }));
}
