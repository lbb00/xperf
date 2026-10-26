pub const Entity = struct {
    id: u32,
    flags: packed struct(u8) {
        visible: bool,
        dirty: bool,
        selected: bool,
        locked: bool,
        _pad: u4 = 0,
    },
};
