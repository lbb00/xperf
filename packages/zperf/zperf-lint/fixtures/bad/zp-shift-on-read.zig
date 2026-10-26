const std = @import("std");
pub const Rx = struct {
    ready: std.ArrayList(u8) = .empty,
    pub fn read(self: *Rx, out: []u8) usize {
        const n = @min(out.len, self.ready.items.len);
        @memcpy(out[0..n], self.ready.items[0..n]);
        const remaining = self.ready.items.len - n;
        std.mem.copyForwards(u8, self.ready.items[0..remaining], self.ready.items[n..]);
        self.ready.items.len = remaining;
        return n;
    }
};
