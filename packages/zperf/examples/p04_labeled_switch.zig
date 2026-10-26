const std = @import("std");

const Op = enum(u8) { push, add, mul, halt };

/// See the English guide for context.
/// See the English guide for context.
/// See the English guide for context.
fn run(code: []const u8) i64 {
    var stack: [16]i64 = undefined;
    var sp: usize = 0;
    var pc: usize = 0;
    loop: switch (@as(Op, @fromBackingInt(code[pc]))) {
        .push => {
            std.debug.assert(sp < stack.len);
            stack[sp] = code[pc + 1];
            sp += 1;
            pc += 2;
            continue :loop @fromBackingInt(code[pc]);
        },
        .add => {
            std.debug.assert(sp >= 2);
            sp -= 1;
            stack[sp - 1] += stack[sp]; // zbc-disable-line: index-minus-one-without-zero-guard
            pc += 1;
            continue :loop @fromBackingInt(code[pc]);
        },
        .mul => {
            std.debug.assert(sp >= 2);
            sp -= 1;
            stack[sp - 1] *= stack[sp]; // zbc-disable-line: index-minus-one-without-zero-guard
            pc += 1;
            continue :loop @fromBackingInt(code[pc]);
        },
        .halt => {
            std.debug.assert(sp >= 1);
            return stack[sp - 1]; // zbc-disable-line: index-minus-one-without-zero-guard
        },
    }
}

test "labeled switch interpreter" {
    const P = @backingInt(Op.push);
    const code = [_]u8{ P, 2, P, 3, @backingInt(Op.add), P, 4, @backingInt(Op.mul), @backingInt(Op.halt) };
    try std.testing.expectEqual(@as(i64, 20), run(&code));
}
