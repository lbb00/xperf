const std = @import("std");
var gpa_state: std.heap.DebugAllocator(.{}) = .init;
pub fn main() void {
    const gpa = gpa_state.allocator();
    _ = gpa;
}
