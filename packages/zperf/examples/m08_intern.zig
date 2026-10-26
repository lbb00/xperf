const std = @import("std");

/// See the English guide for context.
/// See the English guide for context.
const StringPool = struct {
    bytes: std.ArrayList(u8) = .empty,
    table: std.HashMapUnmanaged(u32, void, std.hash_map.StringIndexContext, 80) = .empty,

    fn deinit(p: *StringPool, gpa: std.mem.Allocator) void {
        p.bytes.deinit(gpa);
        p.table.deinit(gpa);
        p.* = undefined;
    }

    fn intern(p: *StringPool, gpa: std.mem.Allocator, s: []const u8) !u32 {
        const gop = try p.table.getOrPutContextAdapted(
            gpa,
            s,
            std.hash_map.StringIndexAdapter{ .bytes = &p.bytes },
            std.hash_map.StringIndexContext{ .bytes = &p.bytes },
        );
        if (gop.found_existing) return gop.key_ptr.*;
        const off: u32 = @intCast(p.bytes.items.len);
        try p.bytes.ensureUnusedCapacity(gpa, s.len + 1);
        p.bytes.appendSliceAssumeCapacity(s);
        p.bytes.appendAssumeCapacity(0);
        gop.key_ptr.* = off;
        return off;
    }

    fn get(p: *const StringPool, off: u32) []const u8 {
        const rest = p.bytes.items[off..];
        return rest[0..std.mem.findScalar(u8, rest, 0).?]; // 0.16: indexOfScalar -> findScalar
    }
};

test "string interning" {
    const gpa = std.testing.allocator;
    var pool: StringPool = .{};
    defer pool.deinit(gpa);
    const a = try pool.intern(gpa, "hello");
    const b = try pool.intern(gpa, "world");
    const c = try pool.intern(gpa, "hello");
    try std.testing.expectEqual(a, c);
    try std.testing.expect(a != b);
    try std.testing.expectEqualStrings("world", pool.get(b));
}
