const std = @import("std");
const builtin = @import("builtin");
const bench = @import("bench_jsonl.zig");

/// Dispatch styles for a tiny stack bytecode VM:
/// 1) while + switch (shared branch site)
/// 2) labeled switch + continue (per-arm branch sites)
/// 3) function-pointer table
/// Order-of-magnitude local evidence for §5.4; upstream tokenizer +13% stays U.

const n_adds: usize = if (builtin.mode == .debug) 2_000 else 200_000;
const trials: usize = if (builtin.mode == .debug) 2 else 7;
const passes: u64 = if (builtin.mode == .debug) 1 else 4;

const Op = enum(u8) { push, add, mul, halt };

const Vm = struct {
    code: []const u8,
    stack: [32]i64 = undefined,
    sp: usize = 0,
    pc: usize = 0,
    halted: bool = false,
    result: i64 = 0,
};

fn reset(vm: *Vm) void {
    vm.sp = 0;
    vm.pc = 0;
    vm.halted = false;
    vm.result = 0;
}

fn runWhileSwitch(code: []const u8) i64 {
    var stack: [32]i64 = undefined;
    var sp: usize = 0;
    var pc: usize = 0;
    while (true) {
        switch (@as(Op, @fromBackingInt(code[pc]))) {
            .push => {
                stack[sp] = code[pc + 1];
                sp += 1;
                pc += 2;
            },
            .add => {
                sp -= 1;
                stack[sp - 1] += stack[sp];
                pc += 1;
            },
            .mul => {
                sp -= 1;
                stack[sp - 1] *= stack[sp];
                pc += 1;
            },
            .halt => return stack[sp - 1],
        }
    }
}

fn runLabeled(code: []const u8) i64 {
    var stack: [32]i64 = undefined;
    var sp: usize = 0;
    var pc: usize = 0;
    loop: switch (@as(Op, @fromBackingInt(code[pc]))) {
        .push => {
            stack[sp] = code[pc + 1];
            sp += 1;
            pc += 2;
            continue :loop @fromBackingInt(code[pc]);
        },
        .add => {
            sp -= 1;
            stack[sp - 1] += stack[sp];
            pc += 1;
            continue :loop @fromBackingInt(code[pc]);
        },
        .mul => {
            sp -= 1;
            stack[sp - 1] *= stack[sp];
            pc += 1;
            continue :loop @fromBackingInt(code[pc]);
        },
        .halt => return stack[sp - 1],
    }
}

fn hPush(vm: *Vm) void {
    vm.stack[vm.sp] = vm.code[vm.pc + 1];
    vm.sp += 1;
    vm.pc += 2;
}

fn hAdd(vm: *Vm) void {
    vm.sp -= 1;
    vm.stack[vm.sp - 1] += vm.stack[vm.sp];
    vm.pc += 1;
}

fn hMul(vm: *Vm) void {
    vm.sp -= 1;
    vm.stack[vm.sp - 1] *= vm.stack[vm.sp];
    vm.pc += 1;
}

fn hHalt(vm: *Vm) void {
    vm.result = vm.stack[vm.sp - 1];
    vm.halted = true;
}

const handlers = [_]*const fn (*Vm) void{ hPush, hAdd, hMul, hHalt };

fn runFnPtr(vm: *Vm) i64 {
    reset(vm);
    while (!vm.halted) {
        handlers[vm.code[vm.pc]](vm);
    }
    return vm.result;
}

fn buildProgram(buf: []u8) struct { len: usize, dispatches: u64 } {
    // push 1; then (push 1; add) * n_adds; halt  →  result = 1 + n_adds
    var i: usize = 0;
    buf[i] = @backingInt(Op.push);
    i += 1;
    buf[i] = 1;
    i += 1;
    var k: usize = 0;
    while (k < n_adds) : (k += 1) {
        buf[i] = @backingInt(Op.push);
        i += 1;
        buf[i] = 1;
        i += 1;
        buf[i] = @backingInt(Op.add);
        i += 1;
    }
    buf[i] = @backingInt(Op.halt);
    i += 1;
    // dispatches per pass: 1 push + 2*n_adds (push+add) + 1 halt
    const dispatches: u64 = @as(u64, @intCast(1 + 2 * n_adds + 1));
    return .{ .len = i, .dispatches = dispatches };
}

const Kind = enum { while_switch, labeled, fn_ptr };

const Ctx = struct {
    code: []const u8,
    sink: i64 = 0,
    kind: Kind,
    vm: Vm = undefined,
};

fn runWork(ptr: *anyopaque) void {
    const ctx: *Ctx = @ptrCast(@alignCast(ptr));
    var p: u64 = 0;
    while (p < passes) : (p += 1) {
        const r: i64 = switch (ctx.kind) {
            .while_switch => runWhileSwitch(ctx.code),
            .labeled => runLabeled(ctx.code),
            .fn_ptr => blk: {
                ctx.vm.code = ctx.code;
                break :blk runFnPtr(&ctx.vm);
            },
        };
        std.mem.doNotOptimizeAway(r);
        ctx.sink +%= r;
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    // worst-case size: 2 + 3*n_adds + 1
    const cap = 2 + 3 * n_adds + 1;
    const buf = try gpa.alloc(u8, cap);
    defer gpa.free(buf);
    const built = buildProgram(buf);
    const code = buf[0..built.len];

    const expected: i64 = @intCast(1 + n_adds);
    if (runWhileSwitch(code) != expected) return error.WhileSwitchMismatch;
    if (runLabeled(code) != expected) return error.LabeledMismatch;
    {
        var vm: Vm = .{ .code = code };
        if (runFnPtr(&vm) != expected) return error.FnPtrMismatch;
    }

    const styles = [_]struct { name: []const u8, kind: Kind, note_tag: []const u8 }{
        .{ .name = "dispatch_while_switch", .kind = .while_switch, .note_tag = "while+switch shared branch site" },
        .{ .name = "dispatch_labeled_switch", .kind = .labeled, .note_tag = "labeled switch continue :loop" },
        .{ .name = "dispatch_fn_ptr_table", .kind = .fn_ptr, .note_tag = "function-pointer opcode table" },
    };

    for (styles) |s| {
        var ctx: Ctx = .{ .code = code, .kind = s.kind, .vm = .{ .code = code } };
        runWork(@ptrCast(&ctx)); // warmup
        const best = bench.bestNs(io, trials, runWork, @ptrCast(&ctx));
        const total_dispatches = built.dispatches * passes;
        var note_buf: [256]u8 = undefined;
        const note = try std.fmt.bufPrint(&note_buf, "best of {d}; n_adds={d} passes={d} dispatches/pass={d}; {s}; local OOM only (upstream tokenizer 13% stays U)", .{ trials, n_adds, passes, built.dispatches, s.note_tag });
        try bench.writeLine(io, .{
            .name = s.name,
            .ns_per_op = bench.nsPerOp(best, total_dispatches),
            .iters = total_dispatches,
            .note = note,
        });
        std.mem.doNotOptimizeAway(ctx.sink);
    }
}
