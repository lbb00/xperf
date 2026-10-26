const std = @import("std");

const Monster = struct {
    hp: u32,
    pos: [2]f32,
    kind: enum(u8) { human, orc, elf },
};

test "MultiArrayList: SoA 去 padding、按字段遍历" {
    const gpa = std.testing.allocator;
    var list: std.MultiArrayList(Monster) = .empty;
    defer list.deinit(gpa);

    try list.ensureTotalCapacity(gpa, 3);
    list.appendAssumeCapacity(.{ .hp = 10, .pos = .{ 0, 0 }, .kind = .orc });
    list.appendAssumeCapacity(.{ .hp = 20, .pos = .{ 1, 1 }, .kind = .elf });
    list.appendAssumeCapacity(.{ .hp = 30, .pos = .{ 2, 2 }, .kind = .orc });

    const s = list.slice();
    var orc_hp: u32 = 0;
    for (s.items(.kind), s.items(.hp)) |k, hp| {
        if (k == .orc) orc_hp += hp;
    }
    try std.testing.expectEqual(@as(u32, 40), orc_hp);
// See the English guide for context.
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Monster));
}
