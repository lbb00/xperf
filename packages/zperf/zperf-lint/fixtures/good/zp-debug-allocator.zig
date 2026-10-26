const std = @import("std");
/// Re-export / type alias without instantiation must not trip zp-debug-allocator.
pub const DebugAllocator = std.heap.DebugAllocator;
pub const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
pub fn main() void {
    _ = std.heap.smp_allocator;
}
