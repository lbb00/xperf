pub const Index = enum(u32) { none = 0xffff_ffff, _ };
pub const Node = struct {
    parent: Index,
    first_child_index: u32,
    value: f32,
    len: usize,
};
