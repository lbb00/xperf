const std = @import("std");
pub fn sum(gpa: std.mem.Allocator, n: usize) !u64 {
    const xs = try gpa.alloc(u64, n);
    @memset(xs, 1);
    var list: std.ArrayList(u8) = .empty;
    try list.append(gpa, 1);
    var s: u64 = 0;
    for (xs) |x| s += x;
    return s;
}
pub fn collect(gpa: std.mem.Allocator) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    try list.append(gpa, 1);
    return list.items;
}
