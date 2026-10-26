const std = @import("std");

/// Equal-size buffer pool with tryAlloc (no fallback).
/// API shape inspired by http.zig Buffer.Pool (MIT); original teaching code.
const BufferPool = struct {
    buffers: [][]u8,
    available: usize,
    buf_len: usize,

    fn init(gpa: std.mem.Allocator, count: usize, buf_len: usize) !BufferPool {
        const buffers = try gpa.alloc([]u8, count);
        errdefer gpa.free(buffers);
        for (buffers) |*slot| {
            // zperf-lint: ignore zp-alloc-in-loop -- one-time pool warm-up, not a hot-path pattern
            slot.* = try gpa.alloc(u8, buf_len);
        }
        return .{ .buffers = buffers, .available = count, .buf_len = buf_len };
    }

    fn deinit(self: *BufferPool, gpa: std.mem.Allocator) void {
        for (self.buffers) |b| gpa.free(b);
        gpa.free(self.buffers);
        self.* = undefined;
    }

    /// Hot path: never allocates. Null means the pool is empty.
    fn tryAlloc(self: *BufferPool) ?[]u8 {
        if (self.available == 0) return null;
        self.available -= 1;
        return self.buffers[self.available];
    }

    fn release(self: *BufferPool, buf: []u8) void {
        std.debug.assert(buf.len == self.buf_len);
        std.debug.assert(self.available < self.buffers.len);
        self.buffers[self.available] = buf;
        self.available += 1;
    }
};

test "buffer pool tryAlloc / release" {
    var pool = try BufferPool.init(std.testing.allocator, 2, 64);
    defer pool.deinit(std.testing.allocator);

    const a = pool.tryAlloc().?;
    const b = pool.tryAlloc().?;
    try std.testing.expect(pool.tryAlloc() == null);
    pool.release(a);
    pool.release(b);
    try std.testing.expect(pool.tryAlloc() != null);
}
