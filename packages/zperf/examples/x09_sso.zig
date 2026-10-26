const std = @import("std");

/// See the English guide for context.
const SmallString = extern union {
    inline_: extern struct { bytes: [15]u8, len: u8 },
    heap: extern struct { ptr: [*]u8, len: u32, _pad: [3]u8, tag: u8 },

    const heap_tag = 0x80;

    fn init(gpa: std.mem.Allocator, s: []const u8) !SmallString {
        if (s.len <= 15) {
            var r: SmallString = .{ .inline_ = .{ .bytes = undefined, .len = @intCast(s.len) } };
            @memcpy(r.inline_.bytes[0..s.len], s);
            return r;
        }
        const p = try gpa.dupe(u8, s);
        return .{ .heap = .{ .ptr = p.ptr, .len = @intCast(s.len), ._pad = undefined, .tag = heap_tag } };
    }
    fn isHeap(self: *const SmallString) bool {
        return self.inline_.len & heap_tag != 0;
    }
    fn slice(self: *const SmallString) []const u8 {
        return if (self.isHeap()) self.heap.ptr[0..self.heap.len] else self.inline_.bytes[0..self.inline_.len];
    }
    fn deinit(self: *SmallString, gpa: std.mem.Allocator) void {
        if (self.isHeap()) gpa.free(self.heap.ptr[0..self.heap.len]);
        self.* = undefined;
    }
};

test "SSO" {
    const gpa = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(SmallString));
    var a: SmallString = try .init(gpa, "hello");
    defer a.deinit(gpa);
    var b: SmallString = try .init(gpa, "this string is definitely longer than 15");
    defer b.deinit(gpa);
    try std.testing.expect(!a.isHeap());
    try std.testing.expect(b.isHeap());
    try std.testing.expectEqualStrings("hello", a.slice());
    try std.testing.expectEqualStrings("this string is definitely longer than 15", b.slice());
}
