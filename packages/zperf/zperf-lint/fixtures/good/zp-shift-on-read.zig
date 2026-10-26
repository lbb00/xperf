const std = @import("std");
pub const Rx = struct {
    ready: std.ArrayList(u8) = .empty,
    head: usize = 0,
/// See the English guide for context.
    pub fn read(self: *Rx, out: []u8) usize {
        const avail = self.ready.items[self.head..];
        const n = @min(out.len, avail.len);
        @memcpy(out[0..n], avail[0..n]);
        self.head += n;
        if (self.head == self.ready.items.len) {
            self.ready.clearRetainingCapacity();
            self.head = 0;
        }
        return n;
    }
};
