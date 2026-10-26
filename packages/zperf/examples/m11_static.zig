const std = @import("std");

/// See the English guide for context.
const Server = struct {
    const connections_max = 128;
    const message_size_max = 4096;

    messages: []align(64) [message_size_max]u8,
    free: std.bit_set.Static(connections_max),

    fn init(gpa: std.mem.Allocator) !Server {
        const messages = try gpa.alignedAlloc([message_size_max]u8, .@"64", connections_max);
        return .{ .messages = messages, .free = .full };
    }
    fn deinit(s: *Server, gpa: std.mem.Allocator) void {
        gpa.free(s.messages);
        s.* = undefined;
    }
    fn acquire(s: *Server) ?u32 {
        const i = s.free.findFirstSet() orelse return null;
        s.free.unset(i);
        return @intCast(i);
    }
    fn release(s: *Server, i: u32) void {
        std.debug.assert(!s.free.isSet(i));
        s.free.set(i);
    }
};

test "static allocation" {
    comptime std.debug.assert(Server.message_size_max % 64 == 0);
    var s = try Server.init(std.testing.allocator);
    defer s.deinit(std.testing.allocator);
    const i = s.acquire().?;
    s.messages[i][0] = 42;
    s.release(i);
}
