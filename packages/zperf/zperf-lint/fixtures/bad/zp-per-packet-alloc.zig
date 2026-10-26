const std = @import("std");
pub const Session = struct {
    gpa: std.mem.Allocator,
    queue: std.ArrayList([]u8) = .empty,
    pub fn onDatagram(self: *Session, payload: []const u8) !void {
        const copy = try self.gpa.dupe(u8, payload);
        errdefer self.gpa.free(copy);
        try self.queue.append(self.gpa, copy);
    }
};
