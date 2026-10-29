// See the English guide for context.
//!
// See the English guide for context.
// See the English guide for context.
// See the English guide for context.
// See the English guide for context.
const std = @import("std");
const Ast = std.zig.Ast;
const Node = Ast.Node;
const Allocator = std.mem.Allocator;
const rules = @import("rules.zig");
const Id = rules.Id;

pub const Finding = struct {
    rule: Id,
    line: u32, // 1-based
    column: u32, // 1-based
    detail: []const u8,
};

pub const Config = struct { // zperf-lint: ignore zp-packable-bools -- config flag bools, not a dense element type
    enabled: std.EnumSet(Id) = .full,
    /// When true, still emit findings for rules whose default severity is `.off` (fixture tests).
    include_off_rules: bool = false,
    large_struct_bytes: u64 = 64,
/// See the English guide for context.
    hot_fns: []const []const u8 = &.{},
/// See the English guide for context.
    propagate: bool = true,
    /// When true, zp-print-hot also flags std.log.* / log.debug|info|warn|err in loops.
    /// Default is false: only std.debug.print / debug.print (unbuffered stderr).
    strict_log_in_loop: bool = false,
    /// When true (default), *-hot rules match outside loops too. --scope loop restores loop-only.
    scope_all: bool = true,
    /// Optional source path (set by CLI). Used to demote path-local noise (crypto, compiler_rt).
    path: ?[]const u8 = null,
};

pub const Result = struct {
    findings: []Finding,
/// See the English guide for context.
    parse_error: ?[]const u8 = null,
/// See the English guide for context.
    compat: bool = false,
};

const Range = struct { start: Ast.TokenIndex, end: Ast.TokenIndex };
const FnInfo = struct {
    range: Range,
    body: Node.Index,
    name: []const u8 = "",
    c_callconv: bool = false,
    /// True when this entry came from a `test` declaration (not a normal fn).
    is_test: bool = false,
/// See the English guide for context.
    hot: ?[]const u8 = null,
    depth: u8 = 0,
};
const Layout = struct { size: u64, alignment: u64 };
const CallParts = struct { receiver: []const u8, method: []const u8 };

const PutCall = struct { fn_index: u32, receiver: []const u8, literal: bool };
const MapDecl = struct { fn_index: u32, name: []const u8, tok: Ast.TokenIndex };

/// See the English guide for context.
/// See the English guide for context.
pub const Prof = struct {
    io: std.Io,
    parse_ns: i96 = 0,
    lint_ns: i96 = 0,
};

// See the English guide for context.
pub fn lintSource(arena: Allocator, source: [:0]const u8, cfg: *const Config) !Result {
    return lintSourceProf(arena, source, cfg, null);
}

pub fn lintSourceProf(arena: Allocator, source: [:0]const u8, cfg: *const Config, prof: ?*Prof) !Result {
    const t0: std.Io.Timestamp = if (prof) |p| .now(p.io, .awake) else .{ .nanoseconds = 0 };
    var tree = try Ast.parse(arena, source, .{ .mode = .zig });
    var compat = false;
    if (tree.errors.len > 0) {
        // Zig 0.16 `**` and tip-Zig `errdefer |err|` are rewritten so 0.17 Ast can parse.
        var candidate: [:0]const u8 = source;
        var rewritten = false;
        if (try normalize016(arena, candidate)) |norm| {
            candidate = norm;
            rewritten = true;
        }
        if (try normalizeErrdefer(arena, candidate)) |norm| {
            candidate = norm;
            rewritten = true;
        }
        if (rewritten) {
            const t2 = try Ast.parse(arena, candidate, .{ .mode = .zig });
            if (t2.errors.len == 0) {
                tree = t2;
                compat = true;
            }
        }
    }
    if (tree.errors.len > 0) {
        var aw: std.Io.Writer.Allocating = .init(arena);
        const e = tree.errors[0];
        const loc = tree.tokenLocation(0, e.token);
        try aw.writer.print("{d}:{d}: ", .{ loc.line + 1, loc.column + 1 });
        try tree.renderError(e, &aw.writer);
        return .{ .findings = &.{}, .parse_error = aw.written() };
    }
    const t1: std.Io.Timestamp = if (prof) |p| .now(p.io, .awake) else .{ .nanoseconds = 0 };
    var l: Linter = .{ .arena = arena, .tree = &tree, .source = source, .cfg = cfg };
    try l.run();
    if (prof) |p| {
        p.parse_ns += t0.durationTo(t1).nanoseconds;
        p.lint_ns += t1.untilNow(p.io, .awake).nanoseconds;
    }
    return .{ .findings = l.findings.items, .compat = compat };
}

/// See the English guide for context.
fn normalize016(arena: Allocator, source: [:0]const u8) !?[:0]const u8 {
    const out = try arena.dupeSentinel(u8, source, 0);
    var changed = false;
    var i: usize = 0;
    var in_str = false;
    var in_char = false;
    while (i < out.len) : (i += 1) {
        const c = out[i];
        if (in_str or in_char) {
            if (c == '\\') {
                i += 1;
            } else if ((in_str and c == '"') or (in_char and c == '\'') or c == '\n') {
                in_str = false;
                in_char = false;
            }
            continue;
        }
        switch (c) {
            '"' => in_str = true,
            '\'' => in_char = true,
            '/', '\\' => if (i + 1 < out.len and out[i + 1] == c) {
// See the English guide for context.
                while (i < out.len and out[i] != '\n') i += 1;
            },
            '*' => if (i + 2 < out.len and out[i + 1] == '*' and (out[i + 2] == ' ' or out[i + 2] == '\t')) {
                out[i + 1] = ' ';
                changed = true;
                i += 1;
            },
            else => {},
        }
    }
    return if (changed) out else null;
}

fn isIdentChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

/// Tip Zig allows `errdefer |err| expr`. Zig 0.17.0 Ast rejects the payload capture.
/// Rewrite to a 0.17-parseable block that still binds `err` as `anyerror` so the file can be linted.
/// Columns after the rewrite may shift in that file; prefer this over skipping the whole file.
fn normalizeErrdefer(arena: Allocator, source: [:0]const u8) !?[:0]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.ensureTotalCapacity(arena, source.len + 128);
    var changed = false;
    var i: usize = 0;
    var in_str = false;
    var in_char = false;
    var in_line_comment = false;
    var in_block_comment = false;

    while (i < source.len) {
        const c = source[i];
        if (in_line_comment) {
            try out.append(arena, c);
            if (c == '\n') in_line_comment = false;
            i += 1;
            continue;
        }
        if (in_block_comment) {
            try out.append(arena, c);
            if (c == '*' and i + 1 < source.len and source[i + 1] == '/') {
                try out.append(arena, '/');
                i += 2;
                in_block_comment = false;
                continue;
            }
            i += 1;
            continue;
        }
        if (in_str or in_char) {
            try out.append(arena, c);
            if (c == '\\' and i + 1 < source.len) {
                try out.append(arena, source[i + 1]);
                i += 2;
                continue;
            }
            if ((in_str and c == '"') or (in_char and c == '\'')) {
                in_str = false;
                in_char = false;
            }
            i += 1;
            continue;
        }
        if (c == '/' and i + 1 < source.len) {
            if (source[i + 1] == '/') {
                try out.appendSlice(arena, "//");
                i += 2;
                in_line_comment = true;
                continue;
            }
            if (source[i + 1] == '*') {
                try out.appendSlice(arena, "/*");
                i += 2;
                in_block_comment = true;
                continue;
            }
        }
        if (c == '"') {
            in_str = true;
            try out.append(arena, c);
            i += 1;
            continue;
        }
        if (c == '\'') {
            in_char = true;
            try out.append(arena, c);
            i += 1;
            continue;
        }

        // Whole-word `errdefer`
        if (c == 'e' and i + 8 <= source.len and std.mem.eql(u8, source[i .. i + 8], "errdefer") and
            (i == 0 or !isIdentChar(source[i - 1])) and
            (i + 8 == source.len or !isIdentChar(source[i + 8])))
        {
            try out.appendSlice(arena, "errdefer");
            i += 8;
            while (i < source.len and (source[i] == ' ' or source[i] == '\t' or source[i] == '\n' or source[i] == '\r')) {
                try out.append(arena, source[i]);
                i += 1;
            }
            if (i < source.len and source[i] == '|') {
                i += 1;
                const id_start = i;
                while (i < source.len and isIdentChar(source[i])) i += 1;
                const id = source[id_start..i];
                if (id.len > 0 and i < source.len and source[i] == '|') {
                    i += 1;
                    try out.appendSlice(arena, "{ const ");
                    try out.appendSlice(arena, id);
                    try out.appendSlice(arena, ": anyerror = undefined; _ = ");
                    changed = true;

                    var depth: i32 = 0;
                    var started = false;
                    var es = false;
                    var ec = false;
                    var elc = false;
                    var ebc = false;
                    while (i < source.len) {
                        const d = source[i];
                        if (elc) {
                            try out.append(arena, d);
                            if (d == '\n') elc = false;
                            i += 1;
                            continue;
                        }
                        if (ebc) {
                            try out.append(arena, d);
                            if (d == '*' and i + 1 < source.len and source[i + 1] == '/') {
                                try out.append(arena, '/');
                                i += 2;
                                ebc = false;
                                continue;
                            }
                            i += 1;
                            continue;
                        }
                        if (es or ec) {
                            try out.append(arena, d);
                            if (d == '\\' and i + 1 < source.len) {
                                try out.append(arena, source[i + 1]);
                                i += 2;
                                continue;
                            }
                            if ((es and d == '"') or (ec and d == '\'')) {
                                es = false;
                                ec = false;
                            }
                            i += 1;
                            continue;
                        }
                        if (d == '/' and i + 1 < source.len) {
                            if (source[i + 1] == '/') {
                                try out.appendSlice(arena, "//");
                                i += 2;
                                elc = true;
                                continue;
                            }
                            if (source[i + 1] == '*') {
                                try out.appendSlice(arena, "/*");
                                i += 2;
                                ebc = true;
                                continue;
                            }
                        }
                        if (d == '"') {
                            es = true;
                            try out.append(arena, d);
                            i += 1;
                            started = true;
                            continue;
                        }
                        if (d == '\'') {
                            ec = true;
                            try out.append(arena, d);
                            i += 1;
                            started = true;
                            continue;
                        }
                        if (d == '{' or d == '(' or d == '[') {
                            depth += 1;
                            started = true;
                            try out.append(arena, d);
                            i += 1;
                            continue;
                        }
                        if (d == '}' or d == ')' or d == ']') {
                            try out.append(arena, d);
                            i += 1;
                            depth -= 1;
                            if (depth == 0 and started and d == '}') {
                                var j = i;
                                while (j < source.len and (source[j] == ' ' or source[j] == '\t')) j += 1;
                                if (j < source.len and source[j] == ';') i = j + 1;
                                try out.appendSlice(arena, "; }");
                                break;
                            }
                            continue;
                        }
                        if (d == ';' and depth == 0) {
                            try out.appendSlice(arena, "; }");
                            i += 1;
                            break;
                        }
                        if (d != ' ' and d != '\t' and d != '\n' and d != '\r') started = true;
                        try out.append(arena, d);
                        i += 1;
                    }
                    continue;
                }
                // Not a payload capture — emit the bytes we skipped.
                try out.append(arena, '|');
                try out.appendSlice(arena, source[id_start..i]);
                continue;
            }
            continue;
        }

        try out.append(arena, c);
        i += 1;
    }

    if (!changed) return null;
    return try out.toOwnedSliceSentinel(arena, 0);
}

const Linter = struct {
    arena: Allocator,
    tree: *const Ast,
    source: [:0]const u8,
    cfg: *const Config,

    findings: std.ArrayList(Finding) = .empty,
    loops: std.ArrayList(Range) = .empty,
    loop_starts: std.ArrayList(Ast.TokenIndex) = .empty,
    fns: std.ArrayList(FnInfo) = .empty,
    structs: std.StringHashMapUnmanaged(Node.Index) = .empty,
    top_consts: std.StringHashMapUnmanaged(void) = .empty,
    line_ignores: std.AutoHashMapUnmanaged(u32, std.EnumSet(Id)) = .empty,
    file_ignores: std.EnumSet(Id) = .empty,
    puts: std.ArrayList(PutCall) = .empty,
/// See the English guide for context.
    full_loops: std.ArrayList(Range) = .empty,
    hot_marks: std.AutoHashMapUnmanaged(u32, void) = .empty,
    map_decls: std.ArrayList(MapDecl) = .empty,
/// See the English guide for context.
    line_starts: []const u32 = &.{},
/// See the English guide for context.
    tok_loop: []const u32 = &.{},
    tok_fn: []const u32 = &.{},

// See the English guide for context.

    fn run(l: *Linter) !void {
        try l.buildLineTable();
        try l.collectIgnores();
        try l.collect();
        l.tok_loop = try l.innermostTable(Range, l.loops.items, struct {
            fn r(x: Range) Range {
                return x;
            }
        }.r);
        l.tok_fn = try l.innermostTable(FnInfo, l.fns.items, struct {
            fn r(x: FnInfo) Range {
                return x.range;
            }
        }.r);
        try l.computeHot();
        const tree = l.tree;
        for (1..tree.nodes.len) |i| {
            const n: Node.Index = @fromBackingInt(@intCast(i));
            switch (tree.nodeTag(n)) {
                .call_one, .call_one_comma, .call, .call_comma => try l.onCall(n),
                .for_simple, .@"for" => try l.onFor(n),
                .fn_decl => try l.onFnDecl(n),
                .simple_var_decl, .local_var_decl, .aligned_var_decl => try l.onVarDecl(n),
                .container_decl,
                .container_decl_trailing,
                .container_decl_two,
                .container_decl_two_trailing,
                .container_decl_arg,
                .container_decl_arg_trailing,
                => try l.onContainer(n),
                .builtin_call_two, .builtin_call_two_comma, .builtin_call, .builtin_call_comma => try l.onBuiltin(n),
                .@"catch" => try l.onCatch(n),
                .div, .mod, .assign_div, .assign_mod => try l.onDiv(n),
                .array_type, .array_type_sentinel => try l.onArrayType(n),
                .ptr_type_aligned, .ptr_type_sentinel, .ptr_type, .ptr_type_bit_range => try l.onPtrType(n),
                else => {},
            }
        }
        try l.checkDebugAllocator();
        try l.checkStaticStringMaps();
    }

// See the English guide for context.

    fn collectIgnores(l: *Linter) !void {
        var line_no: u32 = 1;
        var it = std.mem.splitScalar(u8, l.source, '\n');
        while (it.next()) |text| : (line_no += 1) {
            const c = std.mem.find(u8, text, "//") orelse continue;
            const m = std.mem.find(u8, text[c..], "zperf-lint:") orelse continue;
            var rest = std.mem.trim(u8, text[c + m + "zperf-lint:".len ..], " \t\r");
            if (std.mem.startsWith(u8, rest, "hot") and (rest.len == 3 or !std.ascii.isAlphanumeric(rest[3]))) {
                try l.hot_marks.put(l.arena, line_no, {});
                continue;
            }
            var file_scope = false;
            if (std.mem.startsWith(u8, rest, "ignore-file")) {
                file_scope = true;
                rest = rest["ignore-file".len..];
            } else if (std.mem.startsWith(u8, rest, "ignore")) {
                rest = rest["ignore".len..];
            } else continue;
            var set: std.EnumSet(Id) = .empty;
            var toks = std.mem.tokenizeAny(u8, rest, " ,\t\r");
            while (toks.next()) |t| {
                if (rules.parse(t)) |id| set.insert(id) else if (std.mem.startsWith(u8, t, "--")) break;
            }
            if (set.count() == 0) set = .full;
            if (file_scope) {
                l.file_ignores.setUnion(set);
            } else {
// See the English guide for context.
                for ([_]u32{ line_no, line_no + 1 }) |ln| {
                    const gop = try l.line_ignores.getOrPut(l.arena, ln);
                    if (!gop.found_existing) gop.value_ptr.* = .empty;
                    gop.value_ptr.setUnion(set);
                }
            }
        }
    }

    fn collect(l: *Linter) !void {
        const tree = l.tree;
        for (tree.rootDecls()) |d| {
            if (tree.fullVarDecl(d)) |vd| {
                if (tree.tokenTag(vd.ast.mut_token) == .keyword_const)
                    try l.top_consts.put(l.arena, tree.tokenSlice(vd.ast.mut_token + 1), {});
            }
        }
        var loop_count: usize = 0;
        var fn_count: usize = 0;
        for (1..tree.nodes.len) |i| {
            const n: Node.Index = @fromBackingInt(@intCast(i));
            switch (tree.nodeTag(n)) {
                .for_simple, .@"for", .while_simple, .while_cont, .@"while" => loop_count += 1,
                .fn_decl, .test_decl => fn_count += 1,
                else => {},
            }
        }
        try l.loops.ensureTotalCapacity(l.arena, loop_count);
        try l.loop_starts.ensureTotalCapacity(l.arena, loop_count);
        try l.full_loops.ensureTotalCapacity(l.arena, loop_count);
        try l.fns.ensureTotalCapacity(l.arena, fn_count);
        for (1..tree.nodes.len) |i| {
            const n: Node.Index = @fromBackingInt(@intCast(i));
            switch (tree.nodeTag(n)) {
                .for_simple, .@"for" => {
                    const f = tree.fullFor(n) orelse continue;
                    l.loops.appendAssumeCapacity(l.nodeRange(f.ast.then_expr));
                    l.loop_starts.appendAssumeCapacity(f.ast.for_token);
                    l.full_loops.appendAssumeCapacity(l.nodeRange(n));
                },
                .while_simple, .while_cont, .@"while" => {
                    const w = tree.fullWhile(n) orelse continue;
                    var r = l.nodeRange(w.ast.then_expr);
                    if (w.ast.cont_expr.unwrap()) |ce| r.start = tree.firstToken(ce);
                    l.loops.appendAssumeCapacity(r);
                    l.loop_starts.appendAssumeCapacity(w.ast.while_token);
                    l.full_loops.appendAssumeCapacity(l.nodeRange(n));
                },
                .fn_decl => {
                    const proto, const body = tree.nodeData(n).node_and_node;
                    var pbuf: [1]Node.Index = undefined;
                    const fp = tree.fullFnProto(&pbuf, proto);
                    const name: []const u8 = if (fp) |f|
                        (if (f.name_token) |nt| tree.tokenSlice(nt) else "")
                    else
                        "";
                    const c_callconv = if (fp) |f| isCCallconv(tree, f.ast.callconv_expr.unwrap()) else false;
                    l.fns.appendAssumeCapacity(.{ .range = l.nodeRange(n), .body = body, .name = name, .c_callconv = c_callconv });
                },
                .test_decl => {
                    // Treat `test` blocks like functions so zp-unbuffered-io empty-buffer exemptions apply inside them.
                    const name_tok, const body = tree.nodeData(n).opt_token_and_node;
                    const name: []const u8 = if (name_tok.unwrap()) |nt| tree.tokenSlice(nt) else "test";
                    l.fns.appendAssumeCapacity(.{ .range = l.nodeRange(n), .body = body, .name = name, .is_test = true });
                },
                .simple_var_decl, .local_var_decl, .aligned_var_decl, .global_var_decl => {
                    const vd = tree.fullVarDecl(n) orelse continue;
                    const init_node = vd.ast.init_node.unwrap() orelse continue;
                    if (isContainerTag(tree.nodeTag(init_node))) {
                        const gop = try l.structs.getOrPut(l.arena, tree.tokenSlice(vd.ast.mut_token + 1));
                        if (!gop.found_existing) gop.value_ptr.* = init_node;
                    }
                },
                else => {},
            }
        }
    }

// See the English guide for context.

// See the English guide for context.

    fn isHotName(l: *Linter, name: []const u8) bool {
        for (l.cfg.hot_fns) |h| {
            if (h.len > 0 and h[h.len - 1] == '*') {
                if (std.mem.startsWith(u8, name, h[0 .. h.len - 1])) return true;
            } else if (std.mem.eql(u8, name, h)) return true;
        }
        return defaultHotName(name);
    }

    fn isCCallconv(tree: *const Ast, expr: ?Node.Index) bool {
        const n = expr orelse return false;
        if (tree.nodeTag(n) != .enum_literal) return false;
        return std.mem.eql(u8, tree.tokenSlice(tree.nodeMainToken(n)), "c");
    }

    fn computeHot(l: *Linter) !void {
        const tree = l.tree;
        for (l.fns.items) |*f| {
            if (f.name.len == 0) continue;
            const line = l.lineOf(f.range.start);
            if (l.hot_marks.contains(line) or (line > 1 and l.hot_marks.contains(line - 1))) {
                f.hot = try l.arena.print("{s}(标注 hot)", .{f.name});
            } else if (f.c_callconv) {
                f.hot = try l.arena.print("{s}(callconv(.c))", .{f.name});
            } else if (l.isHotName(f.name)) {
                f.hot = f.name;
            }
        }
        if (!l.cfg.propagate) return;
// See the English guide for context.
        var by_name: std.StringHashMapUnmanaged(u32) = .empty;
        const next_same = try l.arena.alloc(u32, l.fns.items.len);
        try by_name.ensureTotalCapacity(l.arena, @intCast(l.fns.items.len));
        var fi_rev: usize = l.fns.items.len;
        while (fi_rev > 0) {
            fi_rev -= 1;
            const gop = by_name.getOrPutAssumeCapacity(l.fns.items[fi_rev].name);
            next_same[fi_rev] = if (gop.found_existing) gop.value_ptr.* else none;
            gop.value_ptr.* = @intCast(fi_rev);
        }
// See the English guide for context.
        var depth: u8 = 0;
        while (depth < 2) : (depth += 1) {
            for (l.fns.items, 0..) |f, fi| {
                const why = f.hot orelse continue;
                if (f.depth != depth) continue;
                var t = tree.firstToken(f.body);
                const end = tree.lastToken(f.body);
                while (t + 1 <= end) : (t += 1) {
                    if (tree.tokenTag(t) != .identifier or tree.tokenTag(t + 1) != .l_paren) continue;
                    if (tree.tokenTag(t - 1) == .period) {
                        const recv = tree.tokenSlice(t - 2);
                        if (!std.mem.eql(u8, recv, "self") and !std.mem.eql(u8, recv, "Self")) continue;
                    } else if (tree.tokenTag(t - 1) == .keyword_fn) continue;
                    const callee = tree.tokenSlice(t);
                    if (oneOf(callee, &.{ "init", "deinit" })) continue;
                    var gi: u32 = by_name.get(callee) orelse continue;
                    while (gi != none) : (gi = next_same[gi]) {
                        const g = &l.fns.items[gi];
                        if (gi == fi) continue;
                        if (g.hot != null and g.depth <= depth + 1) continue;
                        g.hot = try l.arena.print("{s} → {s}", .{ why, g.name });
                        g.depth = depth + 1;
                    }
                }
            }
        }
    }

    const none: u32 = std.math.maxInt(u32);

    fn buildLineTable(l: *Linter) !void {
        const text = l.tree.source;
        var starts: std.ArrayList(u32) = try .initCapacity(l.arena, text.len / 32 + 2);
        try starts.append(l.arena, 0);
        var pos: usize = 0;
        while (std.mem.findScalarPos(u8, text, pos, '\n')) |i| : (pos = i + 1) try starts.append(l.arena, @intCast(i + 1));
        l.line_starts = starts.items;
    }

/// See the English guide for context.
    fn lineCol(l: *Linter, tok: Ast.TokenIndex) struct { line: u32, column: u32 } {
        const off: u32 = @intCast(l.tree.tokenStart(tok));
// See the English guide for context.
        var lo: usize = 0;
        var hi: usize = l.line_starts.len;
        while (hi - lo > 1) {
            const mid = lo + (hi - lo) / 2;
            if (l.line_starts[mid] <= off) lo = mid else hi = mid;
        }
        return .{ .line = @intCast(lo), .column = off - l.line_starts[lo] };
    }

/// See the English guide for context.
/// See the English guide for context.
// See the English guide for context.
    fn innermostTable(l: *Linter, comptime T: type, items: []const T, comptime rangeOf: fn (T) Range) ![]const u32 {
        const table = try l.arena.alloc(u32, l.tree.tokens.len);
        @memset(table, none);
        const order = try l.arena.alloc(u32, items.len);
        for (order, 0..) |*o, i| o.* = @intCast(i);
        const Ctx = struct {
            items: []const T,
// See the English guide for context.
            fn lt(c: @This(), a: u32, b: u32) bool {
                const ra = rangeOf(c.items[a]).start;
                const rb = rangeOf(c.items[b]).start;
                return ra < rb or (ra == rb and a < b);
            }
        };
        std.mem.sort(u32, order, Ctx{ .items = items }, Ctx.lt);
        for (order) |i| {
            const r = rangeOf(items[i]);
            const end = @min(r.end, @as(Ast.TokenIndex, @intCast(table.len - 1)));
            if (r.start > end) continue;
            @memset(table[r.start .. end + 1], i);
        }
        return table;
    }

/// See the English guide for context.
    fn innermostLoop(l: *Linter, tok: Ast.TokenIndex) ?usize {
        const i = l.tok_loop[tok];
        return if (i == none) null else i;
    }

    fn nodeRange(l: *Linter, n: Node.Index) Range {
        return .{ .start = l.tree.firstToken(n), .end = l.tree.lastToken(n) };
    }

    fn src(l: *Linter, n: Node.Index) []const u8 {
        return l.tree.getNodeSource(n);
    }

    fn inLoop(l: *Linter, tok: Ast.TokenIndex) bool {
        return l.tok_loop[tok] != none;
    }

    fn matchHot(l: *Linter, tok: Ast.TokenIndex) bool {
        return l.cfg.scope_all or l.inLoop(tok);
    }

/// See the English guide for context.
    fn enclosingFn(l: *Linter, tok: Ast.TokenIndex) ?u32 {
        const i = l.tok_fn[tok];
        return if (i == none) null else i;
    }

    fn lineOf(l: *Linter, tok: Ast.TokenIndex) u32 {
        return l.lineCol(tok).line + 1;
    }

    fn report(l: *Linter, id: Id, tok: Ast.TokenIndex, comptime fmt: []const u8, args: anytype) !void {
        if (!l.cfg.enabled.contains(id) or l.file_ignores.contains(id)) return;
        if (rules.get(id).severity == .off and !l.cfg.include_off_rules) return;
        const loc = l.lineCol(tok);
        const ln: u32 = @intCast(loc.line + 1);
        if (l.line_ignores.get(ln)) |set| if (set.contains(id)) return;
        for (l.findings.items) |f| if (f.rule == id and f.line == ln) return;
        try l.findings.append(l.arena, .{
            .rule = id,
            .line = ln,
            .column = @intCast(loc.column + 1),
            .detail = try l.arena.print(fmt, args),
        });
    }

    fn stripTry(l: *Linter, n: Node.Index) Node.Index {
        var x = n;
        while (true) switch (l.tree.nodeTag(x)) {
            .@"try" => x = l.tree.nodeData(x).node,
            .grouped_expression => x = l.tree.nodeData(x).node_and_token[0],
            else => return x,
        };
    }

    fn callParts(l: *Linter, fn_expr: Node.Index) CallParts {
        const tree = l.tree;
        return switch (tree.nodeTag(fn_expr)) {
            .field_access => blk: {
                const lhs, const name_tok = tree.nodeData(fn_expr).node_and_token;
                break :blk .{ .receiver = l.src(lhs), .method = tree.tokenSlice(name_tok) };
            },
            .identifier, .enum_literal => .{ .receiver = "", .method = tree.tokenSlice(tree.nodeMainToken(fn_expr)) },
            else => .{ .receiver = "", .method = "" },
        };
    }

// See the English guide for context.

    const alloc_methods = [_][]const u8{ "alloc", "alignedAlloc", "allocSentinel", "create", "dupe", "dupeZ", "dupeSentinel", "allocPrint", "allocPrintSentinel", "realloc" };
    const growth_methods = [_][]const u8{ "append", "appendSlice", "appendNTimes", "put", "putNoClobber", "getOrPut", "ensureTotalCapacity", "ensureUnusedCapacity", "ensureTotalCapacityPrecise", "insert", "insertSlice", "resize", "initCapacity", "toOwnedSlice", "addOne", "addManyAsSlice" };

    fn isAllocLike(name: []const u8) bool {
        return std.mem.eql(u8, name, "gpa") or containsIgnoreCase(name, "alloc");
    }

    fn isArenaLike(name: []const u8) bool {
        if (std.mem.eql(u8, name, "aa")) return true; // common arena-allocator alias
        for ([_][]const u8{ "arena", "pool", "fba", "stack", "buf", "scratch", "temp", "tmp" }) |k| {
            if (containsIgnoreCase(name, k)) return true;
        }
        return false;
    }

    /// Build/`b.allocator` and bare `allocator`/`alloc` when the fn owns an ArenaAllocator.
    fn isSoftArenaArg(l: *Linter, arg_src: []const u8, fi: usize) bool {
        if (isArenaLike(arg_src)) return true;
        if (std.mem.eql(u8, arg_src, "testing.allocator") or std.mem.endsWith(u8, arg_src, ".testing.allocator")) return true;
        if (std.mem.endsWith(u8, arg_src, ".allocator") or std.mem.eql(u8, arg_src, "allocator") or std.mem.eql(u8, arg_src, "alloc")) {
            if (l.fnHasArenaAllocator(fi)) return true;
            // std.Build allocator is an arena for the build graph.
            if (std.mem.startsWith(u8, arg_src, "b.") or std.mem.find(u8, arg_src, "b.allocator") != null) return true;
            if (std.mem.eql(u8, arg_src, "alloc") or std.mem.eql(u8, arg_src, "allocator")) {
                // Common alias even when ArenaAllocator type name is imported as Allocator only.
                const f = l.fns.items[fi];
                const body = l.source[l.tree.tokenStart(f.range.start)..l.tree.tokenStart(f.range.end)];
                if (std.mem.find(u8, body, "ArenaAllocator") != null or std.mem.find(u8, body, "arena.allocator") != null or
                    std.mem.find(u8, body, "b.allocator") != null)
                    return true;
            }
        }
        return false;
    }

    /// `test { }` blocks (including nested fns inside them), or helpers named test*/expect*.
    fn inTestContext(l: *Linter, tok: Ast.TokenIndex) bool {
        // Any surrounding `test` decl counts — nested `fn` inside a test is still test code.
        for (l.fns.items) |f| {
            if (f.is_test and tok >= f.range.start and tok <= f.range.end) return true;
        }
        const fi = l.enclosingFn(tok) orelse return false;
        const f = l.fns.items[fi];
        if (f.name.len >= 4 and std.mem.startsWith(u8, f.name, "test")) return true;
        if (f.name.len >= 6 and std.mem.startsWith(u8, f.name, "expect")) return true;
        return false;
    }

    /// Rules that are mostly noise inside tests / test helpers.
    fn skipInTest(l: *Linter, id: Id, tok: Ast.TokenIndex) bool {
        if (!l.inTestContext(tok)) return false;
        return switch (id) {
            .append_without_reserve, .unbuffered_io, .missing_free, .catch_unreachable_alloc, .catch_unreachable_io, .map_put_without_ensure, .alloc_in_loop, .per_packet_alloc, .print_in_loop, .arena_reset_free_all, .create_destroy_in_loop, .fixed_size_alloc_in_loop => true,
            else => false,
        };
    }

    /// TigerBeetle-style diagnostic prints gated by `if (log)` / `if (logging)` — not hot I/O.
    fn inDebugLogGate(l: *Linter, tok: Ast.TokenIndex) bool {
        const start = l.tree.tokenStart(tok);
        // Walk the print's line and up to 12 lines above looking for `if (log)` / `if (logging)`.
        var line_start = start;
        while (line_start > 0 and l.source[line_start - 1] != '\n') : (line_start -= 1) {}
        var seen: usize = 0;
        while (seen < 13) {
            var line_end = line_start;
            while (line_end < l.source.len and l.source[line_end] != '\n') : (line_end += 1) {}
            const trimmed = std.mem.trim(u8, l.source[line_start..line_end], " \t");
            if (std.mem.startsWith(u8, trimmed, "if (log)") or std.mem.startsWith(u8, trimmed, "if (logging)") or
                std.mem.startsWith(u8, trimmed, "if(log)") or std.mem.startsWith(u8, trimmed, "if(logging)"))
                return true;
            if (line_start == 0) break;
            // Move to previous line.
            const prev_end = line_start - 1; // points at '\n' before this line
            line_start = prev_end;
            while (line_start > 0 and l.source[line_start - 1] != '\n') : (line_start -= 1) {}
            seen += 1;
        }
        return false;
    }

    fn isAllocMethod(parts: CallParts) bool {
        if (oneOf(parts.method, &alloc_methods)) return true;
// See the English guide for context.
        return std.mem.eql(u8, parts.method, "print") and isAllocLike(lastSegment(parts.receiver));
    }

    fn onCall(l: *Linter, n: Node.Index) !void {
        const tree = l.tree;
        var buf: [1]Node.Index = undefined;
        const call = tree.fullCall(&buf, n) orelse return;
        const parts = l.callParts(call.ast.fn_expr);
        const tok = tree.nodeMainToken(n);
        const fn_src = l.src(call.ast.fn_expr);
        const in_loop = l.inLoop(tok);

        // zp-append-without-reserve append-without-reserve: include for/while loops and nested branches.
        if (in_loop and oneOf(parts.method, &.{ "append", "appendSlice", "appendNTimes" }) and parts.receiver.len != 0 and
            !l.skipInTest(.append_without_reserve, tok))
        {
            const loop_index = l.tok_loop[tok];
            if (loop_index != none) {
                const loop_tok = l.loop_starts.items[loop_index];
                if (l.enclosingFn(loop_tok)) |fi| {
                    var arena_arg = false;
                    for (call.ast.params) |p| {
                        if (l.isSoftArenaArg(l.src(p), fi)) {
                            arena_arg = true;
                            break;
                        }
                    }
                    if (!arena_arg) {
                        const before = l.source[tree.tokenStart(l.fns.items[fi].range.start)..tree.tokenStart(loop_tok)];
                        if (!hasReserve(l.arena, before, parts.receiver))
                            try l.report(.append_without_reserve, tok, "{s}.{s}(...)", .{ parts.receiver, parts.method });
                    }
                }
            }
        }

        // zp-map-put-without-ensure map-put-without-ensure
        if (in_loop and oneOf(parts.method, &.{ "put", "putNoClobber", "getOrPut", "fetchPut" }) and parts.receiver.len != 0 and
            !l.skipInTest(.map_put_without_ensure, tok))
        {
            const loop_index = l.tok_loop[tok];
            if (loop_index != none) {
                const loop_tok = l.loop_starts.items[loop_index];
                if (l.enclosingFn(loop_tok)) |fi| {
                    var arena_arg = false;
                    for (call.ast.params) |p| {
                        if (l.isSoftArenaArg(l.src(p), fi)) {
                            arena_arg = true;
                            break;
                        }
                    }
                    // Unmanaged maps pass allocator as first arg; managed maps may not.
                    if (!arena_arg and !isArenaLike(parts.receiver)) {
                        const before = l.source[tree.tokenStart(l.fns.items[fi].range.start)..tree.tokenStart(loop_tok)];
                        if (!hasReserve(l.arena, before, parts.receiver))
                            try l.report(.map_put_without_ensure, tok, "{s}.{s}(...)", .{ parts.receiver, parts.method });
                    }
                }
            }
        }

        // zp-alloc-hot alloc-in-loop — align arena skip with zp-append-without-reserve (receiver + soft-arena args).
        if (l.matchHot(tok) and isAllocMethod(parts) and !l.skipInTest(.alloc_in_loop, tok)) {
            var arena_like = isArenaLike(parts.receiver) or isArenaLike(lastSegment(parts.receiver));
            if (!arena_like) {
                if (l.enclosingFn(tok)) |fi| {
                    for (call.ast.params) |param_n| {
                        if (l.isSoftArenaArg(l.src(param_n), fi)) {
                            arena_like = true;
                            break;
                        }
                    }
                } else {
                    for (call.ast.params) |param_n| {
                        const ps = l.src(param_n);
                        if (isArenaLike(ps) or isArenaLike(lastSegment(ps))) {
                            arena_like = true;
                            break;
                        }
                    }
                }
            }
            if (!arena_like) try l.report(.alloc_in_loop, tok, "{s}(...)", .{fn_src});
        }

        // zp-arena-reset-free-all arena-reset-free-all / deinit+recreate in loop
        if (in_loop and !l.skipInTest(.arena_reset_free_all, tok)) {
            try l.checkArenaResetFreeAll(n, parts, call.ast.params, tok, fn_src);
        }

        // zp-create-destroy-hot create+destroy same loop
        if (in_loop and !l.skipInTest(.create_destroy_in_loop, tok)) {
            try l.checkCreateDestroyInLoop(parts, call.ast.params, tok, fn_src);
        }

        // zp-fixed-size-alloc-hot fixed-size alloc(u8, N) in loop
        if (in_loop and !l.skipInTest(.fixed_size_alloc_in_loop, tok)) {
            try l.checkFixedSizeAllocInLoop(parts, call.ast.params, tok, fn_src);
        }

// See the English guide for context.
        if (!in_loop and isAllocMethod(parts) and !isArenaLike(parts.receiver) and
            !(call.ast.params.len > 0 and std.mem.eql(u8, parts.receiver, "std.fmt") and isArenaLike(l.src(call.ast.params[0]))) and
            !l.skipInTest(.per_packet_alloc, tok))
        {
            if (l.enclosingFn(tok)) |fi| if (l.fns.items[fi].hot) |why|
                try l.report(.per_packet_alloc, tok, "{s}(...) [热: {s}]", .{ fn_src, why });
        }

        // zp-queue-ordered-remove queue-ordered-remove
        if (std.mem.eql(u8, parts.method, "orderedRemove") and call.ast.params.len >= 1) {
            const idx_src = l.src(call.ast.params[call.ast.params.len - 1]);
            if (std.mem.eql(u8, idx_src, "0")) {
                try l.report(.queue_ordered_remove, tok, "{s}(0)：每次搬移全部剩余元素{s}", .{ fn_src, if (in_loop) "（且在循环里：O(n²)）" else "" });
            } else if (in_loop and !l.followedByExit(tree.lastToken(n))) {
                try l.report(.queue_ordered_remove, tok, "循环内 {s}({s})：逐个删除是 O(n²)", .{ fn_src, idx_src });
            }
        }

        // zp-shift-on-read shift-on-read
        if (oneOf(fn_src, &.{ "std.mem.copyForwards", "mem.copyForwards", "std.mem.copyBackwards", "mem.copyBackwards" }) and call.ast.params.len == 3) {
            if (shiftToFront(l.src(call.ast.params[1]), l.src(call.ast.params[2]))) |base|
                try l.report(.shift_on_read, tok, "{s}({s}[0..], {s}[k..])", .{ fn_src, base, base });
        } else if (oneOf(parts.method, &.{ "replaceRange", "replaceRangeAssumeCapacity" }) and call.ast.params.len >= 3) {
            const ps = call.ast.params;
            const start_src = l.src(ps[ps.len - 3]);
            const with_src = l.src(ps[ps.len - 1]);
            if (std.mem.eql(u8, start_src, "0") and (std.mem.eql(u8, with_src, "&.{}") or std.mem.eql(u8, with_src, "&[_]u8{}")))
                try l.report(.shift_on_read, tok, "{s}(…, 0, n, &.{{}})：删除前缀并搬移剩余元素", .{fn_src});
        }

        // zp-page-allocator-small page-allocator-small — exact `page_allocator` / `*.page_allocator` (not huge_page_allocator)
        if (isPageAllocatorRef(parts.receiver) and
            (oneOf(parts.method, &alloc_methods) or std.mem.eql(u8, parts.method, "print")))
        {
            try l.report(.page_allocator_small, tok, "{s}(...)", .{fn_src});
        } else if (oneOf(parts.method, &growth_methods) or std.mem.eql(u8, parts.method, "allocPrint")) {
            for (call.ast.params) |p| {
                if (isPageAllocatorRef(l.src(p))) {
                    try l.report(.page_allocator_small, tree.firstToken(p), "{s}(page_allocator, ...)", .{fn_src});
                    break;
                }
            }
        }

        // zp-open-file-hot / zp-clock-hot — same-path open and Clock.now
        if (l.matchHot(tok) and oneOf(parts.method, &.{ "openFile", "openFileAbsolute" }))
            try l.report(.open_file_in_loop, tok, "{s}", .{fn_src});
        if (l.matchHot(tok) and std.mem.eql(u8, parts.method, "now") and std.mem.indexOf(u8, fn_src, "Clock") != null)
            try l.report(.clock_in_loop, tok, "{s}", .{fn_src});
        if (l.matchHot(tok) and oneOf(parts.method, &.{ "parseFromSlice", "parseFromSliceLeaky" }) and std.mem.indexOf(u8, fn_src, "json") != null)
            try l.report(.json_in_loop, tok, "{s}", .{fn_src});
        if (in_loop) try l.checkAllocPrintInLoop(parts, call.ast.params, tok, fn_src);

        // zp-print-hot print-in-loop — default: unbuffered debug.print only; log.* needs --strict-log-in-loop
        if (l.matchHot(tok) and !l.skipInTest(.print_in_loop, tok) and !l.inDebugLogGate(tok)) {
            const debug_prints = [_][]const u8{ "std.debug.print", "debug.print" };
            const log_prints = [_][]const u8{ "std.log.info", "std.log.debug", "std.log.warn", "std.log.err", "log.info", "log.debug", "log.warn", "log.err" };
            if (oneOf(fn_src, &debug_prints) or (l.cfg.strict_log_in_loop and oneOf(fn_src, &log_prints)))
                try l.report(.print_in_loop, tok, "{s}", .{fn_src});
        }

        // zp-unbuffered-io unbuffered-io — suppress empty buffer when used with bulk read helpers or one-shot write
        if (oneOf(parts.method, &.{ "writer", "reader", "writerStreaming", "readerStreaming" }) and call.ast.params.len > 0 and
            !l.skipInTest(.unbuffered_io, tok))
        {
            const last = call.ast.params[call.ast.params.len - 1];
            if (isEmptyBufferLiteral(l.src(last)) and !l.emptyIoExempt(tok, parts.method))
                try l.report(.unbuffered_io, tok, "{s}(..., &.{{}})", .{fn_src});
        }

        // zp-bool-array bool-array: ArrayList(bool) / alloc(bool, n)
        if (oneOf(parts.method, &.{ "ArrayList", "ArrayListUnmanaged", "alloc", "Managed" }) and call.ast.params.len > 0 and
            std.mem.eql(u8, l.src(call.ast.params[0]), "bool"))
        {
            try l.report(.bool_array, tok, "{s}(bool, ...)", .{fn_src});
        }

// See the English guide for context.
        if (oneOf(parts.method, &.{ "put", "putNoClobber", "putAssumeCapacity", "putAssumeCapacityNoClobber" }) and
            call.ast.params.len >= 2 and parts.receiver.len > 0)
        {
            if (l.enclosingFn(tok)) |fi| {
                const key = call.ast.params[call.ast.params.len - 2];
                try l.puts.append(l.arena, .{
                    .fn_index = fi,
                    .receiver = parts.receiver,
                    .literal = tree.nodeTag(key) == .string_literal,
                });
            }
        }
    }

// See the English guide for context.

    fn onFor(l: *Linter, n: Node.Index) !void {
        const tree = l.tree;
        const f = tree.fullFor(n) orelse return;
        try l.checkAosSingleField(f);
    }

    fn hasReserve(arena: Allocator, before: []const u8, receiver: []const u8) bool {
        const name = lastSegment(receiver);
        const needle = arena.print("{s}.ensure", .{receiver}) catch return true;
        if (std.mem.find(u8, before, needle) != null) return true;
        // `var list = try ...initCapacity(...)` / `= .initCapacity(...)`
        var it = std.mem.splitScalar(u8, before, '\n');
        while (it.next()) |ln| {
            if (std.mem.find(u8, ln, name) != null and
                (std.mem.find(u8, ln, "initCapacity") != null or std.mem.find(u8, ln, "initBuffer") != null)) return true;
        }
        return false;
    }

/// See the English guide for context.
    fn checkAosSingleField(l: *Linter, f: Ast.full.For) !void {
        const tree = l.tree;
        if (f.ast.inputs.len != 1) return;
        const input = l.src(f.ast.inputs[0]);
        if (!std.mem.endsWith(u8, input, ".items")) return;
        var cap_tok = f.payload_token;
        if (tree.tokenTag(cap_tok) == .asterisk) cap_tok += 1;
        const cap = tree.tokenSlice(cap_tok);
        if (std.mem.eql(u8, cap, "_")) return;
        const r = l.nodeRange(f.ast.then_expr);
        var field: ?[]const u8 = null;
        var only_freed = true;
        var t = r.start;
        while (t <= r.end) : (t += 1) {
            if (tree.tokenTag(t) != .identifier or !std.mem.eql(u8, tree.tokenSlice(t), cap)) continue;
            if (tree.tokenTag(t + 1) != .period or tree.tokenTag(t + 2) != .identifier) return;
            if (tree.tokenTag(t + 3) == .l_paren) return;
            const fname = tree.tokenSlice(t + 2);
            if (field) |old| {
                if (!std.mem.eql(u8, old, fname)) return;
            } else field = fname;
            const freed = t >= 2 and tree.tokenTag(t - 1) == .l_paren and tree.tokenTag(t - 2) == .identifier and
                oneOf(tree.tokenSlice(t - 2), &.{ "free", "destroy" }) and tree.tokenTag(t + 3) == .r_paren;
            if (!freed) only_freed = false;
        }
        if (only_freed) return;
        if (field) |fname| try l.report(.aos_single_field, f.ast.for_token, "for ({s}) |{s}| 只用到 .{s}", .{ input, cap, fname });
    }

// See the English guide for context.

// See the English guide for context.
    fn onFnDecl(l: *Linter, n: Node.Index) !void {
        const tree = l.tree;
        const proto, _ = tree.nodeData(n).node_and_node;
        var buf: [1]Node.Index = undefined;
        const fp = tree.fullFnProto(&buf, proto) orelse return;
        var it = fp.iterate(tree);
        while (it.next()) |p| {
            if (p.comptime_noalias) |ct| if (tree.tokenTag(ct) == .keyword_comptime) continue;
            const te = p.type_expr orelse continue;
            if (tree.nodeTag(te) != .identifier) continue;
            const decl = l.structs.get(tree.tokenSlice(tree.nodeMainToken(te))) orelse continue;
            const lay = l.containerLayout(decl, 0) orelse continue;
            if (lay.size > l.cfg.large_struct_bytes) {
                const tok = p.name_token orelse tree.firstToken(te);
                try l.report(.large_struct_by_value, tok, "参数类型 {s} 约 {d} 字节 (阈值 {d})", .{ l.src(te), lay.size, l.cfg.large_struct_bytes });
            }
        }
    }

// See the English guide for context.

    const owning_types = [_][]const u8{ "ArenaAllocator", "ArrayList", "HashMap", "MultiArrayList", "Allocating", "SafeAllocator", "DebugAllocator", "MemoryPool", "PriorityQueue", "Deque", "bit_set.Dynamic", "DynamicBitSet", "array_hash_map" };

    fn onVarDecl(l: *Linter, n: Node.Index) !void {
        const tree = l.tree;
        const vd = tree.fullVarDecl(n) orelse return;
        const name_tok = vd.ast.mut_token + 1;
        const fi = l.enclosingFn(name_tok) orelse return;
        const name = tree.tokenSlice(name_tok);
        const init_raw = vd.ast.init_node.unwrap() orelse return;
        const init_node = l.stripTry(init_raw);
        const type_src: []const u8 = if (vd.ast.type_node.unwrap()) |tn| l.src(tn) else "";

// See the English guide for context.
        const decl_src = l.src(n);
        if (std.mem.find(u8, decl_src, "StringHashMap") != null or std.mem.find(u8, decl_src, "StringArrayHashMap") != null or
            std.mem.find(u8, decl_src, "array_hash_map.String") != null)
        {
            try l.map_decls.append(l.arena, .{ .fn_index = fi, .name = name, .tok = name_tok });
        }

        // zp-missing-free missing-free
        var owned = false;
        var what: []const u8 = "";
        var cbuf: [1]Node.Index = undefined;
        if (tree.fullCall(&cbuf, init_node)) |call| {
            const parts = l.callParts(call.ast.fn_expr);
            var arena_like = isArenaLike(parts.receiver);
            for (call.ast.params) |p| {
                if (isArenaLike(l.src(p))) arena_like = true;
            }
            if (arena_like) return;
            if (isAllocMethod(parts) or oneOf(parts.method, &.{ "initCapacity", "toOwnedSlice", "readFileAlloc", "readFileAllocOptions" })) {
                owned = true;
                what = parts.method;
            } else if (std.mem.eql(u8, parts.method, "init")) {
                const tsrc = if (parts.receiver.len > 0) parts.receiver else type_src;
                for (owning_types) |t| if (std.mem.find(u8, tsrc, t) != null) {
                    owned = call.ast.params.len > 0 or std.mem.find(u8, tsrc, "ArenaAllocator") != null;
                    what = "init";
                };
            }
        } else if (tree.nodeTag(init_node) == .enum_literal and std.mem.eql(u8, tree.tokenSlice(tree.nodeMainToken(init_node)), "empty")) {
            for (owning_types) |t| if (std.mem.find(u8, type_src, t) != null) {
                owned = true;
                what = ".empty";
            };
        }
        if (!owned) return;
        if (l.skipInTest(.missing_free, name_tok)) return;
        const from = tree.lastToken(n) + 1;
        const to = l.fns.items[fi].range.end;
        if (std.mem.eql(u8, what, ".empty") and (l.usesArenaAllocator(name, from, to) or l.emptyUsesArenaAlloc(name, from, to, fi))) return;
        if (l.isHandled(name, from, to)) return;
        try l.report(.missing_free, name_tok, "`{s}` ({s}) 在函数内未见 deinit/free/返回", .{ name, what });
    }

/// See the English guide for context.
    fn usesArenaAllocator(l: *Linter, name: []const u8, from: Ast.TokenIndex, to: Ast.TokenIndex) bool {
        const tree = l.tree;
        var any = false;
        var t = from;
        while (t + 4 <= to) : (t += 1) {
            if (tree.tokenTag(t) != .identifier or !std.mem.eql(u8, tree.tokenSlice(t), name)) continue;
            if (tree.tokenTag(t - 1) == .ampersand) {
// See the English guide for context.
                const st = tree.tokenStart(t);
                const ls = if (std.mem.findScalarLast(u8, l.source[0..st], '\n')) |i| i + 1 else 0;
                const le = if (std.mem.findScalarPos(u8, l.source, st, '\n')) |i| i else l.source.len;
                const line = l.source[ls..le];
                if (std.mem.find(u8, line, "(") == null) return false;
                if (!lineHasArenaArg(line)) return false;
                any = true;
                continue;
            }
            if (tree.tokenTag(t + 1) != .period or tree.tokenTag(t + 2) != .identifier or tree.tokenTag(t + 3) != .l_paren) continue;
            if (tree.tokenTag(t + 4) != .identifier) continue;
            if (!isArenaLike(tree.tokenSlice(t + 4))) return false;
            any = true;
        }
        return any;
    }

    fn lineHasArenaArg(line: []const u8) bool {
        var it = std.mem.tokenizeAny(u8, line, " \t(),&;.=");
        while (it.next()) |w| {
            if (std.mem.eql(u8, w, "arena") or std.mem.endsWith(u8, w, "_arena") or std.mem.startsWith(u8, w, "arena_")) return true;
        }
        return false;
    }

    /// `.empty` container filled via arena-like / build `*.allocator` args.
    fn emptyUsesArenaAlloc(l: *Linter, name: []const u8, from: Ast.TokenIndex, to: Ast.TokenIndex, fi: usize) bool {
        const tree = l.tree;
        var t = from;
        while (t + 4 <= to) : (t += 1) {
            if (tree.tokenTag(t) != .identifier or !std.mem.eql(u8, tree.tokenSlice(t), name)) continue;
            if (tree.tokenTag(t + 1) != .period or tree.tokenTag(t + 2) != .identifier or tree.tokenTag(t + 3) != .l_paren) continue;
            // First arg may be `b.allocator` (field access) — scan a short window.
            var u = t + 4;
            var depth: u32 = 0;
            const arg_start = u;
            while (u <= to and u < t + 20) : (u += 1) {
                const tag = tree.tokenTag(u);
                if (tag == .l_paren) depth += 1;
                if (tag == .r_paren or tag == .comma) {
                    if (depth == 0) {
                        const arg_src = l.source[tree.tokenStart(arg_start)..tree.tokenStart(u)];
                        const trimmed = std.mem.trim(u8, arg_src, " \t\r\n");
                        if (l.isSoftArenaArg(trimmed, fi) or isArenaLike(trimmed) or
                            std.mem.endsWith(u8, trimmed, ".allocator"))
                            return true;
                        break;
                    }
                    if (tag == .r_paren and depth > 0) depth -= 1;
                }
            }
        }
        return false;
    }

    fn fnHasArenaAllocator(l: *Linter, fi: usize) bool {
        const tree = l.tree;
        const range = l.fns.items[fi].range;
        var t = range.start;
        while (t <= range.end) : (t += 1) {
            if (tree.tokenTag(t) != .identifier) continue;
            if (std.mem.eql(u8, tree.tokenSlice(t), "ArenaAllocator")) return true;
        }
        return false;
    }

    fn isHandled(l: *Linter, name: []const u8, from: Ast.TokenIndex, to: Ast.TokenIndex) bool {
        const tree = l.tree;
        var t = from;
        while (t <= to) : (t += 1) {
            if (tree.tokenTag(t) != .identifier or !std.mem.eql(u8, tree.tokenSlice(t), name)) continue;
            const prev = tree.tokenTag(t - 1);
            const next = tree.tokenTag(t + 1);
            if (next == .period and tree.tokenTag(t + 2) == .identifier and
                oneOf(tree.tokenSlice(t + 2), &.{ "deinit", "deinitLog", "release", "unref", "destroy", "toOwnedSlice", "toOwnedSliceSentinel", "moveToUnmanaged", "toArrayList" })) return true;
// See the English guide for context.
            if (next == .period and tree.tokenTag(t + 2) == .identifier and tree.tokenTag(t + 3) == .l_paren and
                tree.tokenTag(t + 4) == .identifier and isArenaLike(tree.tokenSlice(t + 4))) return true;
            if ((prev == .l_paren or prev == .comma) and (next == .r_paren or next == .comma)) {
// See the English guide for context.
// See the English guide for context.
                if (l.openParenOwner(t)) |owner| switch (tree.tokenTag(owner)) {
                    .builtin, .keyword_for, .keyword_while, .keyword_if, .keyword_switch => {},
                    else => return true,
                };
            }
            if ((prev == .l_brace or prev == .comma) and next == .r_brace) return true; // .{ ..., x }
            if (prev == .keyword_return or prev == .equal) {
// See the English guide for context.
                const borrows_items = next == .period and tree.tokenTag(t + 2) == .identifier and
                    std.mem.eql(u8, tree.tokenSlice(t + 2), "items");
                if (!borrows_items) return true; // return x / .field = x
            }
            if (t >= 3 and (tree.tokenTag(t - 3) == .keyword_break or tree.tokenTag(t - 1) == .keyword_break)) return true;
            // Build Step handoff: dependOn(&run.step) / addArtifactArg(artifact)
            if (prev == .ampersand or next == .period) {
                const st = tree.tokenStart(t);
                const ls = if (std.mem.findScalarLast(u8, l.source[0..st], '\n')) |i| i + 1 else 0;
                const le = if (std.mem.findScalarPos(u8, l.source, st, '\n')) |i| i else l.source.len;
                const line = l.source[ls..le];
                if (std.mem.find(u8, line, "dependOn") != null or std.mem.find(u8, line, "addArtifactArg") != null or
                    std.mem.find(u8, line, "addArgs") != null)
                    return true;
            }
        }
        return false;
    }

/// See the English guide for context.
    fn followedByExit(l: *Linter, last: Ast.TokenIndex) bool {
        const tree = l.tree;
        var t = last + 1;
        while (t < tree.tokens.len and (tree.tokenTag(t) == .semicolon or tree.tokenTag(t) == .r_paren)) t += 1;
        if (t >= tree.tokens.len) return false;
        return switch (tree.tokenTag(t)) {
            .keyword_break, .keyword_return => true,
            else => false,
        };
    }

/// See the English guide for context.
    fn openParenOwner(l: *Linter, arg_tok: Ast.TokenIndex) ?Ast.TokenIndex {
        const tree = l.tree;
        var depth: u32 = 0;
        var t = arg_tok;
        while (t > 0) {
            t -= 1;
            switch (tree.tokenTag(t)) {
                .r_paren, .r_bracket, .r_brace => depth += 1,
                .l_bracket, .l_brace => if (depth == 0) return null else {
                    depth -= 1;
                },
                .l_paren => if (depth == 0) return if (t > 0) t - 1 else null else {
                    depth -= 1;
                },
                .semicolon => return null,
                else => {},
            }
        }
        return null;
    }

// See the English guide for context.

    fn onContainer(l: *Linter, n: Node.Index) !void {
        const tree = l.tree;
        var buf: [2]Node.Index = undefined;
        const cd = tree.fullContainerDecl(&buf, n) orelse return;
        const kw = tree.tokenSlice(cd.ast.main_token);
        const layout: []const u8 = if (cd.layout_token) |lt| tree.tokenSlice(lt) else "auto";
        const is_packed = std.mem.eql(u8, layout, "packed");
        const is_extern = std.mem.eql(u8, layout, "extern");

        if (std.mem.eql(u8, kw, "enum")) return l.checkEnumTag(cd);
        if (!std.mem.eql(u8, kw, "struct") or is_packed) return;

        var bools: u32 = 0;
        var typed_fields: u32 = 0;
        var opt_scalar_fields: u32 = 0;
        const cname = l.nameOfContainer(n);
        const config_like_name = if (cname) |cn| isConfigLikeName(cn) else false;
        const dense_name = if (cname) |cn| isDenseElementName(cn) else false;

        // First pass: count optional scalars (for config-shaped demotion).
        if (!is_extern) {
            for (cd.ast.members) |m| {
                const field = tree.fullContainerField(m) orelse continue;
                const te = field.ast.type_expr.unwrap() orelse continue;
                typed_fields += 1;
                if (tree.nodeTag(te) == .optional_type) {
                    const child = tree.nodeData(te).node;
                    if (tree.nodeTag(child) == .identifier and isScalarName(tree.tokenSlice(tree.nodeMainToken(child)))) {
                        if (l.typeLayout(child, 0)) |in| {
                            if (in.size >= 4) opt_scalar_fields += 1;
                        }
                    }
                }
            }
        }
        // Skip Options/Config/Cli-named structs, or mostly-optional config shapes,
        // unless the type name looks like a dense array element (Node/Item/…).
        const skip_optional_scalars = !dense_name and (config_like_name or
            (typed_fields >= 2 and opt_scalar_fields * 2 >= typed_fields));

        for (cd.ast.members) |m| {
            const field = tree.fullContainerField(m) orelse continue;
            const te = field.ast.type_expr.unwrap() orelse continue;
            const tsrc = l.src(te);
            const fname = tree.tokenSlice(field.ast.main_token);
            if (std.mem.eql(u8, tsrc, "bool")) bools += 1;
            if (!is_extern) {
                // zp-usize-index-field
                if (std.mem.eql(u8, tsrc, "usize") and isIndexName(fname))
                    try l.report(.usize_index_field, field.ast.main_token, "{s}: usize", .{fname});
                // zp-optional-scalar-field
                if (!skip_optional_scalars and tree.nodeTag(te) == .optional_type) {
                    const child = tree.nodeData(te).node;
                    if (tree.nodeTag(child) == .identifier and isScalarName(tree.tokenSlice(tree.nodeMainToken(child)))) {
                        const inner = l.typeLayout(child, 0);
                        const lay = l.typeLayout(te, 0);
                        if (inner) |in| if (lay) |opt| if (in.size >= 4)
                            try l.report(.optional_scalar_field, field.ast.main_token, "{s}: {s} ({d} 字节，去掉 ? 只需 {d} 字节)", .{ fname, tsrc, opt.size, in.size });
                    }
                }
            }
        }
        // zp-packable-bools
        if (bools >= 3) try l.report(.packable_bools, cd.ast.main_token, "{d} 个 bool 字段", .{bools});

    }

    fn nameOfContainer(l: *Linter, n: Node.Index) ?[]const u8 {
        var it = l.structs.iterator();
        while (it.next()) |e| {
            if (e.value_ptr.* == n) return e.key_ptr.*;
        }
        return null;
    }

    /// zp-oversized-enum-tag
    fn checkEnumTag(l: *Linter, cd: Ast.full.ContainerDecl) !void {
        const tree = l.tree;
        const arg = cd.ast.arg.unwrap() orelse return;
        const tag_src = l.src(arg);
        const wide = [_][]const u8{ "u16", "u32", "u64", "u128", "usize", "i16", "i32", "i64", "isize", "c_int", "c_uint", "c_long", "c_ulong", "c_short", "c_ushort" };
        if (!oneOf(tag_src, &wide)) return;
        var count: usize = 0;
        for (cd.ast.members) |m| {
            const field = tree.fullContainerField(m) orelse continue;
            if (std.mem.eql(u8, tree.tokenSlice(field.ast.main_token), "_")) return;
            if (field.ast.value_expr != .none) return;
            count += 1;
        }
        if (count == 0 or count > 256) return;
        try l.report(.oversized_enum_tag, cd.ast.main_token, "enum({s}) 只有 {d} 个值，u8 即可（不写 tag 时编译器自动选最小宽度）", .{ tag_src, count });
    }

// See the English guide for context.

    fn containerLayout(l: *Linter, n: Node.Index, depth: u8) ?Layout {
        var buf: [2]Node.Index = undefined;
        const cd = l.tree.fullContainerDecl(&buf, n) orelse return null;
        if (!std.mem.eql(u8, l.tree.tokenSlice(cd.ast.main_token), "struct")) return null;
        const layout: []const u8 = if (cd.layout_token) |lt| l.tree.tokenSlice(lt) else "auto";
        if (std.mem.eql(u8, layout, "packed")) return null;
        return l.layoutFields(cd, depth, !std.mem.eql(u8, layout, "extern"));
    }

    fn layoutFields(l: *Linter, cd: Ast.full.ContainerDecl, depth: u8, reorder: bool) ?Layout {
        if (depth > 8) return null;
        var lays: [256]Layout = undefined;
        var count: usize = 0;
        for (cd.ast.members) |m| {
            const field = l.tree.fullContainerField(m) orelse continue;
            if (field.comptime_token != null) continue;
            const te = field.ast.type_expr.unwrap() orelse return null;
            if (count == lays.len) return null;
            lays[count] = l.typeLayout(te, depth + 1) orelse return null;
            count += 1;
        }
        const fields = lays[0..count];
        if (reorder) std.mem.sort(Layout, fields, {}, struct {
            fn lt(_: void, a: Layout, b: Layout) bool {
                return a.alignment > b.alignment;
            }
        }.lt);
        var off: u64 = 0;
        var max_align: u64 = 1;
        for (fields) |f| {
            off = std.mem.alignForward(u64, off, f.alignment) + f.size;
            max_align = @max(max_align, f.alignment);
        }
        return .{ .size = std.mem.alignForward(u64, off, max_align), .alignment = max_align };
    }

    fn typeLayout(l: *Linter, n: Node.Index, depth: u8) ?Layout {
        if (depth > 8) return null;
        const tree = l.tree;
        switch (tree.nodeTag(n)) {
            .identifier => {
                const name = tree.tokenSlice(tree.nodeMainToken(n));
                if (primitiveLayout(name)) |p| return p;
                const decl = l.structs.get(name) orelse return null;
                return l.containerLayout(decl, depth + 1);
            },
            .field_access => {
                const s = l.src(n);
                if (std.mem.endsWith(u8, s, "Allocator") or std.mem.eql(u8, s, "std.Io")) return .{ .size = 16, .alignment = 8 };
                return null;
            },
            .optional_type => {
                const child = tree.nodeData(n).node;
                if (tree.fullPtrType(child)) |pt| {
                    if (pt.size == .c) return null;
                    return if (pt.size == .slice) .{ .size = 16, .alignment = 8 } else .{ .size = 8, .alignment = 8 };
                }
                const inner = l.typeLayout(child, depth + 1) orelse return null;
                return .{ .size = std.mem.alignForward(u64, inner.size + 1, inner.alignment), .alignment = inner.alignment };
            },
            .ptr_type_aligned, .ptr_type_sentinel, .ptr_type, .ptr_type_bit_range => {
                const pt = tree.fullPtrType(n) orelse return null;
                return if (pt.size == .slice) .{ .size = 16, .alignment = 8 } else .{ .size = 8, .alignment = 8 };
            },
            .array_type, .array_type_sentinel => {
                const at = tree.fullArrayType(n) orelse return null;
                if (tree.nodeTag(at.ast.elem_count) != .number_literal) return null;
                const len = std.fmt.parseInt(u64, l.src(at.ast.elem_count), 0) catch return null;
                const elem = l.typeLayout(at.ast.elem_type, depth + 1) orelse return null;
                const extra: u64 = if (at.ast.sentinel != .none) 1 else 0;
                return .{ .size = (len + extra) * std.mem.alignForward(u64, elem.size, elem.alignment), .alignment = elem.alignment };
            },
            else => {
                if (isContainerTag(tree.nodeTag(n))) return l.containerLayout(n, depth + 1);
                return null;
            },
        }
    }

// See the English guide for context.

    /// zp-broad-runtime-safety
    fn onBuiltin(l: *Linter, n: Node.Index) !void {
        const tree = l.tree;
        const name = tree.tokenSlice(tree.nodeMainToken(n));
        var buf: [2]Node.Index = undefined;
        const params = tree.builtinCallParams(&buf, n) orelse return;

        if (std.mem.eql(u8, name, "@setRuntimeSafety") and params.len == 1 and std.mem.eql(u8, l.src(params[0]), "false")) {
            const tok = tree.nodeMainToken(n);
            const fi = l.enclosingFn(tok) orelse {
                return l.report(.broad_runtime_safety, tok, "位于顶层/容器作用域", .{});
            };
            const f = l.fns.items[fi];
            var sbuf: [2]Node.Index = undefined;
            const stmts = tree.blockStatements(&sbuf, f.body) orelse return;
            if (std.mem.findScalar(Node.Index, stmts, n) == null) return;
            const lines = l.lineOf(tree.lastToken(f.body)) - l.lineOf(tree.firstToken(f.body));
            if (lines > 25) try l.report(.broad_runtime_safety, tok, "覆盖整个函数体（{d} 行）", .{lines});
        }

// See the English guide for context.
        if (params.len == 2 and std.mem.eql(u8, name, "@memmove")) {
            if (shiftToFront(l.src(params[0]), l.src(params[1]))) |base|
                try l.report(.shift_on_read, tree.nodeMainToken(n), "@memmove({s}[0..], {s}[k..])", .{ base, base });
        }

// See the English guide for context.
        if (params.len == 2 and oneOf(name, &.{ "@divTrunc", "@divFloor", "@divExact", "@divCeil", "@mod", "@rem" })) {
            const tok = tree.nodeMainToken(n);
            if (l.inLoop(tok) and !l.skipRuntimeDivContext(tok) and l.isRuntimeDivisor(params[1]))
                try l.report(.runtime_div_in_loop, tok, "{s}(_, {s})", .{ name, l.src(params[1]) });
        }
    }

    /// zp-catch-unreachable-alloc + zp-catch-unreachable-io
    fn onCatch(l: *Linter, n: Node.Index) !void {
        const tree = l.tree;
        const lhs, const rhs = tree.nodeData(n).node_and_node;
        if (tree.nodeTag(rhs) != .unreachable_literal) return;
        var buf: [1]Node.Index = undefined;
        const call = tree.fullCall(&buf, lhs) orelse return;
        const parts = l.callParts(call.ast.fn_expr);
        const tok = tree.nodeMainToken(n);
        if (isAllocMethod(parts) or oneOf(parts.method, &growth_methods)) {
            if (!l.skipInTest(.catch_unreachable_alloc, tok))
                try l.report(.catch_unreachable_alloc, tok, "{s}(...) catch unreachable", .{l.src(call.ast.fn_expr)});
            return;
        }
        // zp-catch-unreachable-io: fallible I/O — exclude intentional cleanup/notify unreachable patterns.
        // Carefully: skip writeAll/readAll/setsockopt (very common intentional unreachable in helpers).
        const io_methods = [_][]const u8{
            "read", "write", "pread", "pwrite", "readv", "writev",
            "accept", "connect", "send", "recv", "sendto", "recvfrom",
            "bind", "listen", "open", "createFile", "openFile", "openDir",
        };
        const skip_methods = [_][]const u8{
            "close", "closesocket", "WSACleanup", "kevent", "eventfd", "eventfd_write", "eventfd_read",
        };
        if (oneOf(parts.method, &skip_methods)) return;
        if (oneOf(parts.method, &io_methods) and !l.skipInTest(.catch_unreachable_io, tok))
            try l.report(.catch_unreachable_io, tok, "{s}(...) catch unreachable", .{l.src(call.ast.fn_expr)});
    }

    /// zp-runtime-div-hot
    fn onDiv(l: *Linter, n: Node.Index) !void {
        const tree = l.tree;
        const tok = tree.nodeMainToken(n);
        if (!l.inLoop(tok)) return;
        if (l.skipRuntimeDivContext(tok)) return;
        const lhs, const rhs = tree.nodeData(n).node_and_node;
        const is_float = looksFloat(l.src(lhs)) or looksFloat(l.src(rhs)) or l.declaredFloat(rhs, tok) or l.declaredFloat(lhs, tok);
        if (is_float) {
            const tag = tree.nodeTag(n);
            if (tag == .div or tag == .assign_div) try l.checkInvariantFloatDiv(n, lhs, rhs, tok);
            return;
        }
        if (l.isRuntimeDivisor(rhs)) try l.report(.runtime_div_in_loop, tok, "{s} {s} {s}", .{ l.src(lhs), tree.tokenSlice(tok), l.src(rhs) });
    }

    /// Crypto / soft-div / compiler_rt: division *is* the work (GCD, OID digits, udiv*).
    fn skipRuntimeDivContext(l: *Linter, tok: Ast.TokenIndex) bool {
        if (l.cfg.path) |path| {
            if (isCryptoOrCompilerRtPath(path)) return true;
        }
        if (l.enclosingFn(tok)) |fi| {
            if (isSoftDivFnName(l.fns.items[fi].name)) return true;
        }
        return false;
    }

/// See the English guide for context.
    fn declaredFloat(l: *Linter, n: Node.Index, tok: Ast.TokenIndex) bool {
        const tree = l.tree;
        const fi = l.enclosingFn(tok) orelse return false;
        const f = l.fns.items[fi];
        const r = l.nodeRange(n);
        var t = r.start;
        while (t <= r.end) : (t += 1) {
            if (tree.tokenTag(t) != .identifier) continue;
            if (l.identIsFloat(tree.tokenSlice(t), f.range)) return true;
        }
        return false;
    }

    fn identIsFloat(l: *Linter, name: []const u8, range: Range) bool {
        const tree = l.tree;
        var t = range.start;
        while (t + 3 <= range.end) : (t += 1) {
            if (tree.tokenTag(t) != .identifier or !std.mem.eql(u8, tree.tokenSlice(t), name)) continue;
            const kw = tree.tokenTag(t - 1);
            if (kw != .keyword_const and kw != .keyword_var) continue;
            if (tree.tokenTag(t + 1) == .colon) {
                const ty = tree.tokenSlice(t + 2);
                if (oneOf(ty, &.{ "f16", "f32", "f64", "f80", "f128", "comptime_float" })) return true;
            } else if (tree.tokenTag(t + 1) == .equal) {
                const v = tree.tokenSlice(t + 2);
                if (std.mem.eql(u8, v, "@floatFromInt")) return true;
                if (std.mem.eql(u8, v, "@as") and t + 4 <= range.end and
                    oneOf(tree.tokenSlice(t + 4), &.{ "f16", "f32", "f64" })) return true;
                if (tree.tokenTag(t + 2) == .number_literal and looksFloat(v)) return true;
            }
            return false;
        }
        return false;
    }

/// See the English guide for context.
    fn storesToElement(l: *Linter, tok: Ast.TokenIndex) bool {
        const tree = l.tree;
        var t = tok;
        while (t > 1) {
            t -= 1;
            switch (tree.tokenTag(t)) {
                .semicolon, .l_brace, .r_brace => return false,
                .equal, .plus_equal, .minus_equal, .asterisk_equal, .slash_equal => {
                    const p = tree.tokenTag(t - 1);
                    return p == .r_bracket or p == .period_asterisk;
                },
                else => {},
            }
        }
        return false;
    }

/// See the English guide for context.
    fn checkInvariantFloatDiv(l: *Linter, n: Node.Index, lhs: Node.Index, rhs: Node.Index, tok: Ast.TokenIndex) !void {
        const tree = l.tree;
        if (tree.nodeTag(rhs) != .identifier) return;
        const name = tree.tokenSlice(tree.nodeMainToken(rhs));
        if (isConstStyle(name) or l.top_consts.contains(name)) return;
// See the English guide for context.
        const num = l.src(lhs);
        if (std.mem.startsWith(u8, num, "@floatFromInt") or std.mem.startsWith(u8, num, "@as(f64, @floatFromInt") or
            std.mem.startsWith(u8, num, "@as(f32, @floatFromInt")) return;
        if (l.enclosingFn(tok)) |fi| {
            const fname = l.fns.items[fi].name;
            for ([_][]const u8{ "print", "write", "format", "dump", "log", "report", "render", "describe" }) |p|
                if (std.mem.startsWith(u8, fname, p)) return;
        }
// See the English guide for context.
        if (!l.storesToElement(tok)) return;
        const li = l.innermostLoop(tok) orelse return;
        const full = l.full_loops.items[li];
        var t = full.start;
        while (t <= full.end) : (t += 1) {
            if (tree.tokenTag(t) != .identifier or !std.mem.eql(u8, tree.tokenSlice(t), name)) continue;
            const prev = tree.tokenTag(t - 1);
            const next = tree.tokenTag(t + 1);
            if (prev == .keyword_const or prev == .keyword_var or prev == .pipe or prev == .ampersand) return;
            if (next == .pipe or (prev == .comma and next == .pipe)) return;
            switch (next) {
                .equal, .plus_equal, .minus_equal, .asterisk_equal, .slash_equal, .plus_percent_equal, .minus_percent_equal => return,
                else => {},
            }
        }
        _ = n;
        try l.report(.invariant_float_div, tok, "{s} / {s}：{s} 在循环内不变，提出倒数改乘法", .{ l.src(lhs), name, name });
    }

    fn isRuntimeDivisor(l: *Linter, rhs: Node.Index) bool {
        const tree = l.tree;
        switch (tree.nodeTag(rhs)) {
            .identifier => {
                const name = tree.tokenSlice(tree.nodeMainToken(rhs));
                return !l.top_consts.contains(name) and !isObviousConstantDivisor(name);
            },
            .field_access => {
                const full = l.src(rhs);
                // std.time.ns_per_ms / ms_per_s etc. are comptime constants.
                if (std.mem.find(u8, full, "std.time.") != null or std.mem.find(u8, full, ".time.") != null) return false;
                const s = lastSegment(full);
                return !l.top_consts.contains(s) and !isObviousConstantDivisor(s) and !std.mem.eql(u8, s, "len");
            },
            .grouped_expression => return l.isRuntimeDivisor(tree.nodeData(rhs).node_and_token[0]),
            else => return false,
        }
    }

    /// zp-bool-array：[N]bool（N ≥ 64）
    fn onArrayType(l: *Linter, n: Node.Index) !void {
        const tree = l.tree;
        const at = tree.fullArrayType(n) orelse return;
        if (!std.mem.eql(u8, l.src(at.ast.elem_type), "bool")) return;
        if (tree.nodeTag(at.ast.elem_count) != .number_literal) return;
        const len = std.fmt.parseInt(u64, l.src(at.ast.elem_count), 0) catch return;
        if (len >= 64) try l.report(.bool_array, tree.firstToken(n), "[{d}]bool = {d} 字节，bit set 只需 {d} 字节", .{ len, len, (len + 7) / 8 });
    }

    /// zp-bool-array：[]bool / []const bool
    fn onPtrType(l: *Linter, n: Node.Index) !void {
        const tree = l.tree;
        const pt = tree.fullPtrType(n) orelse return;
        if (pt.size != .slice) return;
        if (!std.mem.eql(u8, l.src(pt.ast.child_type), "bool")) return;
        try l.report(.bool_array, tree.firstToken(n), "{s}", .{l.src(n)});
    }

    /// zp-debug-allocator — only flag instantiations `DebugAllocator(` / `GeneralPurposeAllocator(`,
    /// not re-exports (`pub const DebugAllocator = @import(...).DebugAllocator`).
    fn checkDebugAllocator(l: *Linter) !void {
        const tree = l.tree;
        if (std.mem.find(u8, l.source, "builtin.mode") != null or std.mem.find(u8, l.source, "optimize_mode") != null) return;
        for (0..tree.tokens.len) |i| {
            const t: Ast.TokenIndex = @intCast(i);
            if (tree.tokenTag(t) != .identifier) continue;
            const s = tree.tokenSlice(t);
            if (!(std.mem.eql(u8, s, "GeneralPurposeAllocator") or std.mem.eql(u8, s, "DebugAllocator"))) continue;
            // Require a following `(` (type instantiation), skipping whitespace-only trivia via next token.
            if (i + 1 >= tree.tokens.len or tree.tokenTag(@intCast(i + 1)) != .l_paren) continue;
            if (l.inTestContext(t)) continue;
            try l.report(.debug_allocator, t, "{s}", .{s});
        }
    }


    /// zp-arena-reset-free-all: ArenaAllocator.reset(.free_all) or outer-arena deinit+reinit in a loop.
    fn checkArenaResetFreeAll(l: *Linter, n: Node.Index, parts: CallParts, params: []const Node.Index, tok: Ast.TokenIndex, fn_src: []const u8) !void {
        _ = n;
        const recv = parts.receiver;
        const arena_recv = isArenaLike(recv) or isArenaLike(lastSegment(recv));
        if (std.mem.eql(u8, parts.method, "reset") and params.len >= 1 and arena_recv) {
            const mode = l.src(params[0]);
            // .free_all or .{ .free_all = ... } — not retain_*
            if (std.mem.find(u8, mode, "free_all") != null and std.mem.find(u8, mode, "retain") == null) {
                try l.report(.arena_reset_free_all, tok, "{s}(.free_all)：循环内释放全部容量", .{fn_src});
                return;
            }
        }
        // deinit+reinit of an *outer* arena (not `var arena = init; defer deinit` scoped per iteration).
        if (std.mem.eql(u8, parts.method, "deinit") and arena_recv) {
            const li = l.tok_loop[tok];
            if (li == none) return;
            const body = l.loopBodySrc(li);
            const name = lastSegment(recv);
            if (loopDeclaresVar(body, name)) return; // per-iteration scoped arena — OK
            if (std.mem.find(u8, body, "ArenaAllocator") == null and std.mem.find(u8, body, ".init(") == null) return;
            const has_reinit = std.mem.find(u8, body, ".init(") != null or std.mem.find(u8, body, "ArenaAllocator.init") != null;
            const has_create = std.mem.find(u8, body, "create(ArenaAllocator)") != null or std.mem.find(u8, body, "create(std.heap.ArenaAllocator)") != null;
            if (has_reinit or has_create)
                try l.report(.arena_reset_free_all, tok, "{s} + 同循环重建外层 ArenaAllocator", .{fn_src});
        }
    }

    /// zp-create-destroy-hot: create(Type) with success-path destroy in the same loop; skip pool/arena / errdefer-only.
    fn checkCreateDestroyInLoop(l: *Linter, parts: CallParts, params: []const Node.Index, tok: Ast.TokenIndex, fn_src: []const u8) !void {
        if (!std.mem.eql(u8, parts.method, "create") or params.len < 1) return;
        if (isArenaLike(parts.receiver) or isArenaLike(lastSegment(parts.receiver))) return;
        const recv_seg = lastSegment(parts.receiver);
        if (!(isAllocLike(parts.receiver) or isAllocLike(recv_seg) or parts.receiver.len == 0)) return;
        const type_src = std.mem.trim(u8, l.src(params[0]), " \t\n\r");
        if (!looksLikePooledType(type_src)) return;
        const li = l.tok_loop[tok];
        if (li == none) return;
        const body = l.loopBodySrc(li);
        if (!loopHasSuccessPathDestroy(body)) return;
        try l.report(.create_destroy_in_loop, tok, "{s}({s}) + 同循环 destroy → MemoryPool({s})", .{ fn_src, type_src, type_src });
    }

    /// zp-fixed-size-alloc-hot: alloc(u8, literal>=16) in loop on non-arena allocator.
    fn checkFixedSizeAllocInLoop(l: *Linter, parts: CallParts, params: []const Node.Index, tok: Ast.TokenIndex, fn_src: []const u8) !void {
        if (!std.mem.eql(u8, parts.method, "alloc") or params.len < 2) return;
        if (isArenaLike(parts.receiver) or isArenaLike(lastSegment(parts.receiver))) return;
        if (!std.mem.eql(u8, std.mem.trim(u8, l.src(params[0]), " \t\n\r"), "u8")) return;
        const size_node = params[1];
        if (l.tree.nodeTag(size_node) != .number_literal) return;
        const lit = l.src(size_node);
        const n = std.fmt.parseInt(u64, lit, 0) catch return;
        if (n < 16) return;
        try l.report(.fixed_size_alloc_in_loop, tok, "{s}(u8, {s})：固定 size-class → 缓冲池", .{ fn_src, lit });
    }

    /// zp-alloc-print-hot: format once when the format string and args do not change in this loop.
    fn checkAllocPrintInLoop(l: *Linter, parts: CallParts, params: []const Node.Index, tok: Ast.TokenIndex, fn_src: []const u8) !void {
        const is_fmt_alloc = oneOf(parts.method, &.{ "allocPrint", "allocPrintSentinel" });
        const seg = lastSegment(parts.receiver);
        const recv_alloc = isAllocLike(parts.receiver) or isAllocLike(seg) or
            std.mem.eql(u8, seg, "aa") or containsIgnoreCase(seg, "arena");
        const is_alloc_print = oneOf(parts.method, &.{ "print", "printSentinel" }) and recv_alloc;
        if (!is_fmt_alloc and !is_alloc_print) return;
        const fmt_index: usize = if (is_fmt_alloc) 1 else 0;
        if (params.len < fmt_index + 2) return;
        const li = l.tok_loop[tok];
        if (li == none) return;
        if (!l.exprIsLoopInvariant(params[fmt_index], li)) return;
        var args_node: ?Node.Index = null;
        for (params[fmt_index + 1 ..]) |p| {
            var sbuf: [2]Node.Index = undefined;
            // `.{id}` is an array init; `.{}` and `.{.field = id}` are struct inits.
            if (l.tree.fullStructInit(&sbuf, p) != null or l.tree.fullArrayInit(&sbuf, p) != null) {
                args_node = p;
                break;
            }
        }
        const args = args_node orelse return;
        if (!l.tupleIsLoopInvariant(args, li)) return;
        try l.report(.alloc_print_in_loop, tok, "{s}", .{fn_src});
    }

    fn tupleIsLoopInvariant(l: *Linter, n: Node.Index, loop_index: u32) bool {
        var sbuf: [2]Node.Index = undefined;
        if (l.tree.fullStructInit(&sbuf, n)) |init| {
            for (init.ast.fields) |field| {
                if (!l.exprIsLoopInvariant(field, loop_index)) return false;
            }
            return true;
        }
        if (l.tree.fullArrayInit(&sbuf, n)) |init| {
            for (init.ast.elements) |elem| {
                if (!l.exprIsLoopInvariant(elem, loop_index)) return false;
            }
            return true;
        }
        return false;
    }

    fn exprIsLoopInvariant(l: *Linter, n: Node.Index, loop_index: u32) bool {
        const tree = l.tree;
        switch (tree.nodeTag(n)) {
            .number_literal, .string_literal, .char_literal, .enum_literal => return true,
            .grouped_expression => return l.exprIsLoopInvariant(tree.nodeData(n).node_and_token[0], loop_index),
            .identifier => {
                const name = tree.tokenSlice(tree.nodeMainToken(n));
                if (l.loopBindsPayload(loop_index, name)) return false;
                if (l.identAssignedInLoop(loop_index, name)) return false;
                if (loopDeclaresVar(l.loopBodySrc(loop_index), name)) return false;
                return true;
            },
            else => return false,
        }
    }

    fn loopBindsPayload(l: *Linter, loop_index: u32, name: []const u8) bool {
        if (loop_index >= l.full_loops.items.len) return false;
        const r = l.full_loops.items[loop_index];
        const tree = l.tree;
        const end = @min(r.end, @as(Ast.TokenIndex, @intCast(tree.tokens.len - 1)));
        var t = r.start;
        while (t <= end) : (t += 1) {
            if (tree.tokenTag(t) != .pipe) continue;
            var u = t + 1;
            while (u <= end and tree.tokenTag(u) != .pipe) : (u += 1) {
                if (tree.tokenTag(u) == .identifier and std.mem.eql(u8, tree.tokenSlice(u), name)) return true;
            }
            return false;
        }
        return false;
    }

    fn identAssignedInLoop(l: *Linter, loop_index: u32, name: []const u8) bool {
        if (loop_index >= l.loops.items.len) return false;
        const r = l.loops.items[loop_index];
        const tree = l.tree;
        const last = @as(Ast.TokenIndex, @intCast(tree.tokens.len - 1));
        const end = @min(r.end, last);
        if (r.start >= end) return false;
        var t = r.start;
        while (t < end) : (t += 1) {
            if (tree.tokenTag(t) != .identifier) continue;
            if (!std.mem.eql(u8, tree.tokenSlice(t), name)) continue;
            if (isAssignOp(tree.tokenTag(t + 1))) return true;
        }
        return false;
    }

    fn loopBodySrc(l: *Linter, loop_index: u32) []const u8 {
        const r = l.loops.items[loop_index];
        const start = l.tree.tokenStart(r.start);
        const end_tok = @min(r.end, @as(Ast.TokenIndex, @intCast(l.tree.tokens.len - 1)));
        var end = l.tree.tokenStart(end_tok) + l.tree.tokenSlice(end_tok).len;
        if (end > l.source.len) end = l.source.len;
        if (start >= end) return "";
        return l.source[start..end];
    }

    /// Empty `&.{}` I/O is intentional with bulk-read helpers, caller-buffer readVec/writeVec,
    /// same-line "buffer" comments, or a non-loop writeAll/write after this call.
    fn emptyIoExempt(l: *Linter, tok: Ast.TokenIndex, method: []const u8) bool {
        // Trailing comment on the same line: `reader(io, &.{}); // … does its own buffering`
        const start = l.tree.tokenStart(tok);
        if (std.mem.findScalarPos(u8, l.source, start, '\n')) |nl| {
            const line = l.source[start..nl];
            if (std.mem.find(u8, line, "//") != null and containsIgnoreCase(line, "buffer")) return true;
        }
        const fi = l.enclosingFn(tok) orelse return false;
        const range = l.fns.items[fi].range;
        const tree = l.tree;
        var has_bulk = false;
        var has_caller_vec = false;
        var has_write = false;
        var write_in_loop = false;
        // Bulk helpers: whole function. Writes: only after this call, until the next reader/writer creation
        // (so a later unrelated looped writer cannot poison an earlier one-shot empty buffer).
        var t = range.start;
        while (t + 1 <= range.end) : (t += 1) {
            if (tree.tokenTag(t) != .identifier) continue;
            const s = tree.tokenSlice(t);
            if (oneOf(s, &.{ "allocRemaining", "readAlloc", "appendRemaining" })) has_bulk = true;
            if (t <= tok) continue;
            if (tree.tokenTag(t - 1) == .period and tree.tokenTag(t + 1) == .l_paren) {
                if (oneOf(s, &.{ "writer", "reader", "writerStreaming", "readerStreaming" })) break;
                if (oneOf(s, &.{ "readVec", "writeVec", "readVecAll", "writeVecAll" })) has_caller_vec = true;
                if (oneOf(s, &.{ "writeAll", "write" })) {
                    has_write = true;
                    if (l.innermostLoop(t)) |li| {
                        const loop_tok = l.loop_starts.items[li];
                        if (loop_tok >= range.start and loop_tok <= range.end) write_in_loop = true;
                    }
                }
            }
        }
        if (has_bulk or has_caller_vec) return true;
        const is_writer = oneOf(method, &.{ "writer", "writerStreaming" });
        return is_writer and has_write and !write_in_loop;
    }

    /// zp-static-string-map
    fn checkStaticStringMaps(l: *Linter) !void {
        for (l.map_decls.items) |d| {
            var lit: u32 = 0;
            var non: u32 = 0;
            for (l.puts.items) |p| {
                if (p.fn_index != d.fn_index or !std.mem.eql(u8, p.receiver, d.name)) continue;
                if (p.literal) lit += 1 else non += 1;
            }
            if (lit >= 3 and non == 0) try l.report(.static_string_map, d.tok, "`{s}` 共 {d} 次 put，全部为字面量键", .{ d.name, lit });
        }
    }
};

// See the English guide for context.

/// See the English guide for context.
fn defaultHotName(name: []const u8) bool {
    if (oneOf(name, &.{ "init", "deinit", "onDeinit" })) return false;
    if (name.len > 2 and std.mem.startsWith(u8, name, "on") and std.ascii.isUpper(name[2])) return true;
    const prefixes = [_][]const u8{ "handle", "recv", "receive", "rx", "process", "enqueue", "push", "tick", "step", "frame" };
    for (prefixes) |p| {
        if (!std.mem.startsWith(u8, name, p)) continue;
        // Bare `handle` commonly names a dispatcher for heterogeneous,
        // infrequent requests. Require a concrete suffix to infer its heat;
        // explicit hot marks/config still support APIs that use this name.
        if (name.len == p.len) {
            if (std.mem.eql(u8, p, "handle")) continue;
            return true;
        }
        const c = name[p.len];
        if (std.ascii.isUpper(c) or c == '_') return true;
    }
    return false;
}

/// See the English guide for context.
fn shiftToFront(dest: []const u8, src: []const u8) ?[]const u8 {
    const db = std.mem.findScalar(u8, dest, '[') orelse return null;
    const sb = std.mem.findScalar(u8, src, '[') orelse return null;
    const base = dest[0..db];
    if (base.len == 0 or !std.mem.eql(u8, base, src[0..sb])) return null;
    if (!std.mem.startsWith(u8, dest[db..], "[0..")) return null;
    if (std.mem.startsWith(u8, src[sb..], "[0..")) return null;
    if (std.mem.findScalar(u8, src[sb..], '.') == null) return null;
    return base;
}

fn isContainerTag(tag: Node.Tag) bool {
    return switch (tag) {
        .container_decl, .container_decl_trailing, .container_decl_two, .container_decl_two_trailing, .container_decl_arg, .container_decl_arg_trailing => true,
        else => false,
    };
}



fn loopDeclaresVar(body: []const u8, name: []const u8) bool {
    if (name.len == 0) return false;
    var i: usize = 0;
    while (i + 4 + name.len < body.len) : (i += 1) {
        const is_var = std.mem.startsWith(u8, body[i..], "var ");
        const is_const = std.mem.startsWith(u8, body[i..], "const ");
        if (!is_var and !is_const) continue;
        const kw_len: usize = if (is_var) 4 else 6;
        if (i > 0 and (std.ascii.isAlphanumeric(body[i - 1]) or body[i - 1] == '_')) continue;
        var j = i + kw_len;
        while (j < body.len and std.ascii.isWhitespace(body[j])) j += 1;
        if (j + name.len <= body.len and std.mem.eql(u8, body[j .. j + name.len], name)) {
            const after: u8 = if (j + name.len < body.len) body[j + name.len] else ' ';
            if (!std.ascii.isAlphanumeric(after) and after != '_') return true;
        }
    }
    return false;
}

/// Success-path destroy: `defer x.destroy` or bare `.destroy(` — not `errdefer` alone.
fn loopHasSuccessPathDestroy(body: []const u8) bool {
    var start: usize = 0;
    while (start < body.len) {
        const rel_a = std.mem.find(u8, body[start..], ".destroy(");
        const rel_b = std.mem.find(u8, body[start..], ".destroy (");
        const rel = if (rel_a) |a| (if (rel_b) |b| @min(a, b) else a) else (rel_b orelse break);
        const pos = start + rel;
        var j = pos;
        while (j > 0) {
            const c = body[j - 1];
            if (std.ascii.isAlphanumeric(c) or c == '_' or c == '.') {
                j -= 1;
                continue;
            }
            break;
        }
        while (j > 0 and std.ascii.isWhitespace(body[j - 1])) j -= 1;
        const before = body[0..j];
        if (std.mem.endsWith(u8, before, "errdefer")) {
            start = pos + 1;
            continue;
        }
        return true;
    }
    return false;
}

fn looksLikePooledType(name: []const u8) bool {
    if (name.len == 0) return false;
    if (primitiveLayout(name) != null) return false;
    if (std.mem.findScalar(u8, name, '(') != null) return false; // ArrayList(T) etc. — not MemoryPool element
    // Single identifier or dotted path ending in TypeName
    const base = lastSegment(name);
    if (base.len == 0 or !std.ascii.isAlphabetic(base[0])) return false;
    // Heuristic: type names are typically Capitalized (Node, Write, Completion).
    if (!std.ascii.isUpper(base[0])) return false;
    return true;
}

fn oneOf(s: []const u8, list: []const []const u8) bool {
    for (list) |x| if (std.mem.eql(u8, s, x)) return true;
    return false;
}

fn isAssignOp(tag: std.zig.Token.Tag) bool {
    return switch (tag) {
        .equal,
        .pipe_equal,
        .percent_equal,
        .caret_equal,
        .plus_equal,
        .plus_percent_equal,
        .plus_pipe_equal,
        .minus_equal,
        .minus_percent_equal,
        .minus_pipe_equal,
        .asterisk_equal,
        .asterisk_percent_equal,
        .asterisk_pipe_equal,
        .slash_equal,
        .ampersand_equal,
        .angle_bracket_angle_bracket_left_equal,
        .angle_bracket_angle_bracket_left_pipe_equal,
        .angle_bracket_angle_bracket_right_equal,
        => true,
        else => false,
    };
}


fn isCryptoOrCompilerRtPath(path: []const u8) bool {
    if (std.mem.find(u8, path, "/crypto/") != null or std.mem.startsWith(u8, path, "crypto/")) return true;
    if (std.mem.find(u8, path, "/crypto.zig") != null or std.mem.eql(u8, std.fs.path.basename(path), "crypto.zig")) return true;
    if (std.mem.find(u8, path, "/compiler_rt/") != null or std.mem.startsWith(u8, path, "compiler_rt/")) return true;
    if (std.mem.find(u8, path, "/lib/compiler_rt/") != null or std.mem.startsWith(u8, path, "lib/compiler_rt/")) return true;
    if (std.mem.endsWith(u8, path, "/compiler_rt") or std.mem.eql(u8, std.fs.path.basename(path), "compiler_rt.zig")) return true;
    return false;
}

/// Soft-division / big-int helper names where `/` and `%` are the algorithm.
fn isSoftDivFnName(name: []const u8) bool {
    if (name.len == 0) return false;
    const keys = [_][]const u8{ "udiv", "sdiv", "divmod", "divti", "modti", "umod", "smod", "__div", "__mod", "__umod", "__udiv", "divMode", "div_mode" };
    for (keys) |k| {
        if (std.ascii.findIgnoreCase(name, k) != null) return true;
    }
    return false;
}

fn containsIgnoreCase(hay: []const u8, needle: []const u8) bool {
    return std.ascii.findIgnoreCase(hay, needle) != null;
}

/// True for `page_allocator` or `foo.page_allocator` — not `huge_page_allocator`.
fn isPageAllocatorRef(s: []const u8) bool {
    return std.mem.eql(u8, s, "page_allocator") or std.mem.endsWith(u8, s, ".page_allocator");
}

fn lastSegment(s: []const u8) []const u8 {
    const i = std.mem.findScalarLast(u8, s, '.') orelse return s;
    return s[i + 1 ..];
}

fn isEmptyBufferLiteral(s: []const u8) bool {
    var buf: [16]u8 = undefined;
    var n: usize = 0;
    for (s) |c| {
        if (std.ascii.isWhitespace(c)) continue;
        if (n == buf.len) return false;
        buf[n] = c;
        n += 1;
    }
    return std.mem.eql(u8, buf[0..n], "&.{}");
}

fn isIndexName(name: []const u8) bool {
    const exact = [_][]const u8{ "index", "idx", "id", "offset", "parent", "next", "prev", "child", "first", "last" };
    if (oneOf(name, &exact)) return true;
    for ([_][]const u8{ "_index", "_idx", "_id", "_offset" }) |suf| if (std.mem.endsWith(u8, name, suf)) return true;
    return false;
}

fn isConfigLikeName(name: []const u8) bool {
    // Exact short names (avoid prefix "Cli" matching "Client").
    if (std.ascii.eqlIgnoreCase(name, "Cli") or std.ascii.eqlIgnoreCase(name, "Args") or
        std.ascii.eqlIgnoreCase(name, "Flags") or std.ascii.eqlIgnoreCase(name, "Config") or
        std.ascii.eqlIgnoreCase(name, "Options") or std.ascii.eqlIgnoreCase(name, "Settings") or
        std.ascii.eqlIgnoreCase(name, "Params") or std.ascii.eqlIgnoreCase(name, "Preferences"))
        return true;
    for ([_][]const u8{ "Options", "Config", "Settings", "Preferences", "Params", "Args", "Flags" }) |k| {
        if (name.len > k.len and std.ascii.eqlIgnoreCase(name[name.len - k.len ..], k)) return true;
        if (name.len > k.len and std.ascii.eqlIgnoreCase(name[0..k.len], k)) return true;
    }
    // Suffix "Cli" only (CommandCli), not prefix.
    if (name.len > 3 and std.ascii.eqlIgnoreCase(name[name.len - 3 ..], "Cli")) return true;
    return false;
}

/// Types likely stored densely in arrays / MultiArrayList — keep zp-optional-scalar-field pressure.
fn isDenseElementName(name: []const u8) bool {
    for ([_][]const u8{ "Node", "Item", "Entry", "Cell", "Pixel", "Vertex", "Record", "Row", "Element", "Event", "Particle", "Entity" }) |k| {
        if (containsIgnoreCase(name, k)) return true;
    }
    return false;
}

fn isScalarName(name: []const u8) bool {
    if (primitiveLayout(name) == null) return false;
    return !std.mem.eql(u8, name, "void");
}

fn isConstStyle(name: []const u8) bool {
    var has_alpha = false;
    for (name) |c| {
        if (std.ascii.isLower(c)) return std.mem.endsWith(u8, name, "_max") or std.mem.endsWith(u8, name, "_min") or
            std.mem.eql(u8, name, "cap") or std.mem.endsWith(u8, name, "_size");
        if (std.ascii.isAlphabetic(c)) has_alpha = true;
    }
    return has_alpha;
}

/// Divisors that are comptime-known or conventionally power-of-two (ring `% capacity`).
fn isObviousConstantDivisor(name: []const u8) bool {
    if (isConstStyle(name)) return true;
    // std.time.* style names (also matches bare ns_per_ms locals).
    if (std.mem.startsWith(u8, name, "ns_per_") or std.mem.startsWith(u8, name, "ms_per_") or
        std.mem.startsWith(u8, name, "us_per_") or std.mem.startsWith(u8, name, "s_per_"))
        return true;
    // Ring-buffer / PoT capacity naming — `% capacity` is almost always a mask.
    if (oneOf(name, &.{ "capacity", "cap", "mask", "mod_mask" })) return true;
    if (std.mem.endsWith(u8, name, "_capacity") or std.mem.endsWith(u8, name, "_cap") or
        std.mem.endsWith(u8, name, "_mask"))
        return true;
    return false;
}

fn looksFloat(s: []const u8) bool {
    if (std.mem.find(u8, s, "@floatFromInt") != null or std.mem.find(u8, s, "f32") != null or std.mem.find(u8, s, "f64") != null) return true;
// See the English guide for context.
    for (s, 0..) |c, i| {
        if (c == '.' and i > 0 and i + 1 < s.len and std.ascii.isDigit(s[i - 1]) and std.ascii.isDigit(s[i + 1])) return true;
    }
    return false;
}

fn primitiveLayout(name: []const u8) ?Layout {
    const table = [_]struct { []const u8, u64, u64 }{
        .{ "bool", 1, 1 },     .{ "void", 0, 1 },   .{ "f16", 2, 2 },     .{ "f32", 4, 4 },
        .{ "f64", 8, 8 },      .{ "f80", 16, 16 },  .{ "f128", 16, 16 },  .{ "usize", 8, 8 },
        .{ "isize", 8, 8 },    .{ "c_int", 4, 4 },  .{ "c_uint", 4, 4 },  .{ "c_short", 2, 2 },
        .{ "c_ushort", 2, 2 }, .{ "c_long", 8, 8 }, .{ "c_ulong", 8, 8 }, .{ "c_char", 1, 1 },
        .{ "anyerror", 2, 2 },
    };
    for (table) |e| if (std.mem.eql(u8, name, e[0])) return .{ .size = e[1], .alignment = e[2] };
    if (name.len >= 2 and (name[0] == 'u' or name[0] == 'i')) {
        const bits = std.fmt.parseInt(u16, name[1..], 10) catch return null;
        if (bits == 0) return .{ .size = 0, .alignment = 1 };
        const bytes = std.math.ceilPowerOfTwo(u64, (bits + 7) / 8) catch return null;
        const a = @min(bytes, 16);
        return .{ .size = std.mem.alignForward(u64, (bits + 7) / 8, a), .alignment = a };
    }
    return null;
}

test primitiveLayout {
    try std.testing.expectEqual(Layout{ .size = 1, .alignment = 1 }, primitiveLayout("u3").?);
    try std.testing.expectEqual(Layout{ .size = 4, .alignment = 4 }, primitiveLayout("u24").?);
    try std.testing.expectEqual(Layout{ .size = 8, .alignment = 8 }, primitiveLayout("u64").?);
    try std.testing.expect(primitiveLayout("Foo") == null);
}
