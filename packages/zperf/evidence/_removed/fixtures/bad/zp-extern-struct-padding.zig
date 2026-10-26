pub const Header = extern struct {
    flag: u8,
    offset: u64,
    kind: u8,
};
