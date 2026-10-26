const std = @import("std");

/// See the English guide for context.
fn SlotMap(comptime T: type, comptime capacity: u32) type {
    return struct {
        const Self = @This();
        pub const Handle = packed struct(u64) { index: u32, generation: u32 };

        items: [capacity]T = undefined,
        generations: [capacity]u32 = @splat(0),
        free: [capacity]u32 = undefined,
        free_len: u32 = 0,
        len: u32 = 0,

        pub fn insert(s: *Self, v: T) ?Handle {
            const i: u32 = if (s.free_len > 0) blk: {
                s.free_len -= 1;
                break :blk s.free[s.free_len];
            } else if (s.len < capacity) blk: {
                s.len += 1;
                break :blk s.len - 1;
            } else return null;
            s.items[i] = v;
            return .{ .index = i, .generation = s.generations[i] };
        }
        pub fn remove(s: *Self, h: Handle) void {
            std.debug.assert(s.generations[h.index] == h.generation);
            s.generations[h.index] +%= 1;
            s.free[s.free_len] = h.index;
            s.free_len += 1;
        }
        pub fn get(s: *Self, h: Handle) ?*T {
            if (s.generations[h.index] != h.generation) return null;
            return &s.items[h.index];
        }
    };
}

test "generational handles" {
    var map: SlotMap(f32, 4) = .{};
    const a = map.insert(1.5).?;
    map.remove(a);
    const b = map.insert(2.5).?;
    try std.testing.expectEqual(a.index, b.index);
    try std.testing.expect(map.get(a) == null);
    try std.testing.expectEqual(@as(f32, 2.5), map.get(b).?.*);
}
