pub const Edge = struct {
    from: u32,
    to: ?u32,
};
/// Dense element name should still fire even if many optionals
pub const Item = struct {
    id: ?u32 = null,
    weight: ?u32 = null,
};
