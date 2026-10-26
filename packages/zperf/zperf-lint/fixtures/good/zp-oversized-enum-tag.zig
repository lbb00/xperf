pub const Color = enum { red, green, blue };
pub const Opcode = enum(u32) { nop = 0x90, ret = 0xc3 };
pub const Handle = enum(u32) { none = 0, _ };
