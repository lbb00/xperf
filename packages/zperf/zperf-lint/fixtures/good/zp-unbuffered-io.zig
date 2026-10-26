const std = @import("std");

pub fn writeBuffered(io: std.Io, file: std.Io.File, lines: []const []const u8) !void {
    var buf: [4096]u8 = undefined;
    var fw = file.writer(io, &buf);
    for (lines) |l| try fw.interface.writeAll(l);
    try fw.interface.flush();
}

/// Empty buffer + allocRemaining is the documented one-shot bulk-read pattern.
pub fn readAll(io: std.Io, file: std.Io.File, gpa: std.mem.Allocator) ![]u8 {
    var r = file.reader(io, &.{});
    return try r.interface.allocRemaining(gpa, .unlimited);
}

/// Empty writer + single non-loop writeAll is OK (handshake / small reply).
pub fn writeOnce(io: std.Io, file: std.Io.File, reply: []const u8) !void {
    var w = file.writer(io, &.{});
    try w.interface.writeAll(reply);
    try w.interface.flush();
}

pub fn readWithCallerBuf(io: std.Io, stream: anytype, dest: []u8) !usize {
    var reader = stream.reader(io, &.{});
    var vecs: [1][]u8 = .{dest};
    return try reader.interface.readVec(&vecs);
}

pub fn readOwnBuffered(io: std.Io, stream: anytype, state: anytype) !bool {
    var reader = stream.reader(io, &.{}); // Request.State does its own buffering
    return try state.parse(&reader.interface);
}
