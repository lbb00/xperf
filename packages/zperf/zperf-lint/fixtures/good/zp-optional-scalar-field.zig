pub const Edge = struct {
    from: u32,
    to: u32,
    next: ?*Edge,
    pub const none: u32 = 0xffff_ffff;
};
/// Config/Options naming: optional scalars are intentional — must not fire zp-optional-scalar-field
pub const Options = struct {
    commit_stall_lag_max: ?u32 = null,
    port: ?u16 = null,
};
pub const WorkerConfig = struct {
    count: ?u16 = null,
    backlog: ?u32 = null,
    buffer_size: ?usize = null,
};
