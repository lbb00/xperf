const std = @import("std");

const Perm = enum { read, write, exec, admin };

test "flags：EnumSet / bit_set" {
    // C: #define READ 1, WRITE 2 ... ; unsigned flags;
    var p: std.EnumSet(Perm) = .empty; // 0.17: initEmpty -> .empty
    p.insert(.read);
    p.insert(.exec);
    try std.testing.expect(p.contains(.exec));
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(std.EnumSet(Perm)));

    var small: std.bit_set.Integer(64) = .empty;
    small.set(63);
    try std.testing.expectEqual(@as(usize, 1), small.count());

    var big: std.bit_set.Static(1000) = .empty;
    big.set(999);
    try std.testing.expectEqual(@as(?usize, 999), big.findFirstSet());

// See the English guide for context.
    const gpa = std.testing.allocator;
    var dyn: std.bit_set.Dynamic = try .initEmpty(gpa, 10_000);
    defer dyn.deinit(gpa);
    dyn.set(1234);
    try std.testing.expect(dyn.isSet(1234));
// See the English guide for context.
}
