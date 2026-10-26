const std = @import("std");
pub fn keywords(gpa: std.mem.Allocator) !std.StringHashMapUnmanaged(u8) {
    var map: std.StringHashMapUnmanaged(u8) = .empty;
    errdefer map.deinit(gpa);
    try map.put(gpa, "if", 1);
    try map.put(gpa, "else", 2);
    try map.put(gpa, "while", 3);
    return map;
}
