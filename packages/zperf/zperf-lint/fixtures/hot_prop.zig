const std = @import("std");
pub const Conn = struct {
    gpa: std.mem.Allocator,
    // zperf-lint: hot
    pub fn pump(self: *Conn, bytes: []const u8) !void {
        try self.stash(bytes);
    }
    fn stash(self: *Conn, bytes: []const u8) !void {
        const c = try self.gpa.dupe(u8, bytes);
        self.gpa.free(c);
    }
};
