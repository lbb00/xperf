const std = @import("std");

// See the English guide for context.
const CarC = enum(c_int) { electric = 1, benzine = 2, diesel = 3 };
const HybridC = extern struct { type1: CarC, type2: CarC };

// See the English guide for context.
const Car = enum(u2) { electric = 1, benzine = 2, diesel = 3 };
const Hybrid = struct { type1: Car, type2: Car };

// See the English guide for context.
const ELECTRIC: c_uint = 1;
const BENZINE: c_uint = 1 << 1;
const DIESEL: c_uint = 1 << 2;

// See the English guide for context.
const Fuel = packed struct(u8) {
    electric: bool,
    benzine: bool,
    diesel: bool,
    _pad: u5 = 0,
};

// See the English guide for context.
const FuelKind = enum { electric, benzine, diesel };

/// See the English guide for context.
fn PackedArray(comptime T: type, comptime n: usize) type {
    return struct {
        bytes: [(n * @bitSizeOf(T) + 7) / 8]u8 = @splat(0),
        fn set(self: *@This(), i: usize, v: T) void {
            std.mem.writePackedInt(T, &self.bytes, i * @bitSizeOf(T), v, .little);
        }
        fn get(self: *const @This(), i: usize) T {
            return std.mem.readPackedInt(T, &self.bytes, i * @bitSizeOf(T), .little);
        }
    };
}

test "car case study" {
// See the English guide for context.
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(HybridC));
// See the English guide for context.
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(Hybrid));
    try std.testing.expectEqual(@as(usize, 2), @bitSizeOf(Car));

// See the English guide for context.
    const types: c_uint = ELECTRIC | BENZINE;
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(@TypeOf(types)));
    try std.testing.expect(types & DIESEL == 0);

// See the English guide for context.
    const f: Fuel = .{ .electric = true, .benzine = true, .diesel = false };
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Fuel));
    try std.testing.expectEqual(@as(usize, 8), @bitSizeOf(Fuel));
    const wire: u8 = @bitCast(f);
    try std.testing.expectEqual(@as(u8, 0b011), wire);
    try std.testing.expectEqual(f, @as(Fuel, @bitCast(wire)));

    var set: std.EnumSet(FuelKind) = .empty;
    set.insert(.electric);
    set.insert(.benzine);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(std.EnumSet(FuelKind)));
    try std.testing.expect(!set.contains(.diesel));

// See the English guide for context.
    var cars: PackedArray(u3, 1000) = .{};
    try std.testing.expectEqual(@as(usize, 375), @sizeOf(@TypeOf(cars)));
    cars.set(999, @truncate(wire));
    try std.testing.expectEqual(@as(u3, 0b011), cars.get(999));
    try std.testing.expectEqual(@as(usize, 1000), @sizeOf([1000]Fuel));
    try std.testing.expectEqual(@as(usize, 8000), @sizeOf([1000]HybridC));
}
