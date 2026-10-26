const std = @import("std");

/// Typed byte offset into a relocatable base slab (no raw pointers stored).
/// API shape inspired by Ghostty terminal Offset(T) (MIT); original teaching code.
fn Offset(comptime T: type) type {
    return struct {
        byte: u32 = 0,

        const Self = @This();

        fn ptr(self: Self, base: []u8) [*]T {
            const addr = @intFromPtr(base.ptr) + self.byte;
            std.debug.assert(addr % @alignOf(T) == 0);
            return @ptrFromInt(addr);
        }

        fn slice(self: Self, base: []u8, len: usize) []T {
            return self.ptr(base)[0..len];
        }
    };
}

const Cell = struct { ch: u32, style: u16 };

test "offset into relocatable slab" {
    var slab: [256]u8 align(@alignOf(Cell)) = undefined;
    const off: Offset(Cell) = .{ .byte = 0 };
    const cells = off.slice(slab[0..], 4);
    cells[0] = .{ .ch = 'A', .style = 1 };
    cells[1] = .{ .ch = 'B', .style = 2 };

    // Relocate: copy slab bytes; offsets stay valid relative to the new base.
    var moved: [256]u8 align(@alignOf(Cell)) = undefined;
    @memcpy(moved[0..], slab[0..]);
    const again = off.slice(moved[0..], 4);
    try std.testing.expectEqual(@as(u32, 'A'), again[0].ch);
    try std.testing.expectEqual(@as(u32, 'B'), again[1].ch);
}
