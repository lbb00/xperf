pub fn bucketize(xs: []u32, nbuckets: u32) void {
    for (xs) |*x| {
        x.* = x.* % nbuckets;
    }
}
