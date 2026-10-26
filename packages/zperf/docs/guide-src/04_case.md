## 4. Case study: reducing the memory used by a hybrid car

This example is inspired by Liu Yanpeng's video “Write Code to Save Memory”: <https://v.douyin.com/KoVqTHbb9L0/>. It walks through the video's four C representations in Zig. Tests assert every size with `@sizeOf` or `@bitSizeOf`.

The C code evolves in four steps:

1. `enum Car { ELECTRIC = 1, BENZINE = 2, DIESEL = 3 };`
2. Store the two power sources of a hybrid car as two `int` values: `struct { int type1; int type2; }`, which is 8 bytes on a 64-bit system.
3. Use bit flags instead: `ELECTRIC = 1`, `BENZINE = 1 << 1`, `DIESEL = 1 << 2`, and `int types = ELECTRIC | BENZINE;`. This takes 4 bytes.
4. Use three 1-bit fields: `struct { uint8_t electric:1; uint8_t benzine:1; uint8_t diesel:1; }`. This takes 1 byte.

| Step | C | Zig equivalent | Size |
|---|---|---|---|
| Two ints | `struct { int type1, type2; }` | `extern struct { type1: CarC, type2: CarC }` (`enum(c_int)`) | 8 bytes |
| Small tag | — | `struct { type1: Car, type2: Car }`, where `Car = enum(u2)` | 2 bytes (`@bitSizeOf(Car) == 2`) |
| Bit flags | `unsigned int` | Bitwise OR of `c_uint` constants | 4 bytes |
| Bit fields | Three `uint8_t x:1` fields | `packed struct(u8) { electric: bool, benzine: bool, diesel: bool, _pad: u5 = 0 }` | 1 byte (8 bits, 3 used) |
| Bit set | — | `std.EnumSet(FuelKind)` | 1 byte |
| 1,000 cars | — | Pack 3 bits per car with `readPackedInt`/`writePackedInt` | 375 bytes (versus 1,000 bytes for `[1000]Fuel` and 8,000 bytes for two ints) |

> Example: `examples/c06_car_case.zig` (checked with Zig 0.17.0 using `zig test`).

```zig
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
```

Notes:

- **Percentages.** 64 bits → 8 bits is one-eighth the size (87.5% reduction), not “800% savings”. Packing 3 bits from 64 is about 95% reduction.
- **Zig layout is defined.** C leaves bit order, storage-unit crossing, and signedness of `int` bit fields to the implementation. Zig puts the first `packed struct(u8)` field in the LSB and allows `@bitCast` to `u8` for wire formats.
- **When it matters.** Irrelevant for a handful of UI objects. Relevant for kernels, drivers, embedded, protocol headers, and millions of instances where layout hits cache and peak RSS.
- **Cost.** Packed access needs shifts and masks; `readPackedInt` can be slower. Measure first.

---

