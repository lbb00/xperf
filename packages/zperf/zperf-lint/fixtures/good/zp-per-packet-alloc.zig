const std = @import("std");
const Slot = struct { len: usize = 0, bytes: [1500]u8 = undefined };
pub const Session = struct {
    slots: [64]Slot = @splat(.{}),
    cursor: u32 = 0,
/// See the English guide for context.
    pub fn onDatagram(self: *Session, payload: []const u8) !void {
        if (payload.len > 1500) return error.TooLarge;
        const s = &self.slots[self.cursor];
        @memcpy(s.bytes[0..payload.len], payload);
        s.len = payload.len;
        self.cursor = (self.cursor + 1) & 63;
    }
/// See the English guide for context.
    pub fn snapshot(self: *Session, gpa: std.mem.Allocator) ![]u8 {
        return gpa.dupe(u8, self.slots[0].bytes[0..self.slots[0].len]);
    }
};
