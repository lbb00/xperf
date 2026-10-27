// See the English guide for context.
const std = @import("std");

pub const Severity = enum {
    off,
    hint,
    info,
    warning,

    pub fn label(s: Severity) []const u8 {
        return @tagName(s);
    }
};

pub const Id = enum(u8) {
    alloc_in_loop,
    append_without_reserve,
    page_allocator_small,
    debug_allocator,
    large_struct_by_value,
    print_in_loop,
    unbuffered_io,
    missing_free,
    broad_runtime_safety,
    packable_bools,
    usize_index_field,
    aos_single_field,
    catch_unreachable_alloc,
    oversized_enum_tag,
    optional_scalar_field,
    bool_array,
    static_string_map,
    runtime_div_in_loop,
    queue_ordered_remove,
    shift_on_read,
    per_packet_alloc,
    invariant_float_div,
    map_put_without_ensure,
    catch_unreachable_io,
    arena_reset_free_all,
    create_destroy_in_loop,
    fixed_size_alloc_in_loop,
    open_file_in_loop,
    clock_in_loop,
    json_in_loop,
    alloc_print_in_loop,
};

pub const Rule = struct {
    id: Id,
    code: []const u8,
    name: []const u8,
    severity: Severity,
    msg_zh: []const u8,
    msg_en: []const u8,
    fix: []const u8,
    fp_risk: []const u8,
};

pub const all = [_]Rule{
    .{ .id = .alloc_in_loop, .code = "zp-alloc-hot", .name = "alloc-hot", .severity = .off, .msg_zh = "循环体内进行堆分配", .msg_en = "heap allocation; reuse buffers when profiles show pressure — cost adds up even off a hot path", .fix = "把分配提到循环外并复用缓冲区；或改用 ArenaAllocator + reset(.retain_capacity) / MemoryPool", .fp_risk = "中：跳过 arena/pool/fba/scratch 接收者，以及 method.dupe(sema.arena) 等 soft-arena 参数（与 zp-append-without-reserve 对齐）；测试块跳过；G3/r4 成熟 Zig 上样本几乎全 OK-idiom（冷 builder/setup）→ 默认 off，--enable zp-alloc-hot 可开；少数热路径仍有诚实 TP" },
    .{ .id = .append_without_reserve, .code = "zp-append-without-reserve", .name = "append-without-reserve", .severity = .off, .msg_zh = "for/while 循环中 append，循环前没有预留容量", .msg_en = "append without prior ensureTotalCapacity/ensureUnusedCapacity — cost adds up even off a hot path", .fix = "循环前调用 list.ensureUnusedCapacity(gpa, n)，循环内用 appendAssumeCapacity", .fp_risk = "中：跳过 arena/`alloc`（同函数有 ArenaAllocator）参数、测试块、testing.allocator；追加数量无法预估时预留可能浪费空间；G3 成熟 Zig 上几乎全是 OK-idiom（N 未知的 builder）→ 默认 off，--enable zp-append-without-reserve 可开" },
    .{ .id = .page_allocator_small, .code = "zp-page-allocator-small", .name = "page-allocator-small", .severity = .warning, .msg_zh = "直接用 page_allocator 做小块/容器分配", .msg_en = "std.heap.page_allocator used directly for small or container allocations", .fix = "page_allocator 每次至少分配一页并发起系统调用；改用 smp_allocator / c_allocator / ArenaAllocator.init(page_allocator)", .fp_risk = "低：只匹配 page_allocator 作为 create/alloc/dupe 的接收者或作为容器方法参数" },
    .{ .id = .debug_allocator, .code = "zp-debug-allocator", .name = "debug-allocator", .severity = .off, .msg_zh = "使用 GeneralPurposeAllocator/DebugAllocator，且文件中看不到按 builtin.mode 切换", .msg_en = "GeneralPurposeAllocator/DebugAllocator used without switching on builtin.mode", .fix = "0.17: DebugAllocator 已弃用，Debug/Safe 用 SafeAllocator，Fast/Small 用 smp_allocator 或 c_allocator；或直接用 process.Init.gpa", .fp_risk = "高：CLI/工具常直接 DebugAllocator；G3 成熟库几乎全是 OK-idiom → 默认 off，--enable zp-debug-allocator 可开" },
    .{ .id = .large_struct_by_value, .code = "zp-large-struct-by-value", .name = "large-struct-by-value", .severity = .off, .msg_zh = "按值传递较大的结构体", .msg_en = "large struct passed by value", .fix = "改为 *const T 传参（TigerStyle：>16 字节且无意拷贝时）", .fp_risk = "中：大小是按字段类型估算的；只对本文件中声明、能估算大小的 struct 生效；Zig 也可能自行按引用传递；G3 样本全 OK-idiom（ABI 常按引用传）→ 默认 off，--enable zp-large-struct-by-value 可开" },
    .{ .id = .print_in_loop, .code = "zp-print-hot", .name = "print-hot", .severity = .off, .msg_zh = "循环内调用 std.debug.print（默认）；std.log 需 --strict-log-in-loop", .msg_en = "std.debug.print; gate or buffer (std.log only with --strict-log-in-loop) — cost adds up even off a hot path", .fix = "std.debug.print 每次调用都要锁 stderr、只有 64 字节缓冲；改用循环外创建的带缓冲 Io.Writer，结束时 flush。默认不把 std.log.* 当 debug.print；需要时加 --strict-log-in-loop", .fp_risk = "低：默认已排除结构化日志；严格模式下错误路径仍可能是有意的；G3 样本全 OK-idiom（诊断/非热 print）→ 默认 off，--enable zp-print-hot 可开" },
    .{ .id = .unbuffered_io, .code = "zp-unbuffered-io", .name = "unbuffered-io", .severity = .off, .msg_zh = "以空缓冲区 &.{} 创建 reader/writer", .msg_en = "reader/writer created with an empty buffer (&.{})", .fix = "提供缓冲区，例如 var buf: [4096]u8 = undefined; file.writer(io, &buf)，并在结束时 flush", .fp_risk = "低：跳过测试块/test* 助手、同行 // …buffer… 注释、readVec/writeVec 调用方缓冲、allocRemaining/一次性 write；G3 样本全 OK-idiom（一次性/已有缓冲边角）→ 默认 off，--enable zp-unbuffered-io 可开" },
    .{ .id = .missing_free, .code = "zp-missing-free", .name = "missing-free", .severity = .off, .msg_zh = "分配/初始化后在函数内找不到 deinit/free/destroy 或所有权转移", .msg_en = "allocated or initialized resource is never freed, deinit-ed, or handed off in this function", .fix = "紧跟分配写 defer x.deinit(gpa) / defer gpa.free(x)；所有权转出时用 errdefer", .fp_risk = "高：跨函数/所有权转移系统性误报；G3 样本几乎全 FP → 默认 off，--enable zp-missing-free 可开" },
    .{ .id = .broad_runtime_safety, .code = "zp-broad-runtime-safety", .name = "broad-runtime-safety", .severity = .warning, .msg_zh = "@setRuntimeSafety(false) 作用范围过大", .msg_en = "@setRuntimeSafety(false) covers too large a scope", .fix = "只在已验证的最内层热点块里关闭安全检查，例如 { @setRuntimeSafety(false); ... }", .fp_risk = "低：阈值为函数体 > 25 行或位于顶层 comptime 块" },
    .{ .id = .packable_bools, .code = "zp-packable-bools", .name = "packable-bools", .severity = .off, .msg_zh = "结构体含多个 bool 字段，每个占 1 字节", .msg_en = "struct has several bool fields (1 byte each)", .fix = "打包为 packed struct(u8) 标志位 / std.EnumSet，或按 DOD 把 bool 移出（out-of-band）", .fp_risk = "中：结构体只有少量实例时收益可以忽略；G3 样本全 OK-idiom（API/冷 struct 密度）→ 默认 off，--enable zp-packable-bools 可开" },
    .{ .id = .usize_index_field, .code = "zp-usize-index-field", .name = "usize-index-field", .severity = .off, .msg_zh = "索引类字段使用 usize（64 位上 8 字节）", .msg_en = "index-like field uses usize (8 bytes on 64-bit)", .fix = "元素数 < 2^32 时用 u32 或 enum(u32) { _ } 句柄，省一半空间", .fp_risk = "中：按字段名(index/idx/id/offset/parent/next/prev/child/first/last)猜测；G3 样本全 OK-idiom（API/冷索引字段）→ 默认 off，--enable zp-usize-index-field 可开" },
    .{ .id = .aos_single_field, .code = "zp-aos-single-field", .name = "aos-single-field", .severity = .off, .msg_zh = "遍历结构体数组时只访问一个字段", .msg_en = "loop over array-of-structs touches only one field", .fix = "若这是热点，考虑 std.MultiArrayList(T)（SoA），只加载需要的字段", .fp_risk = "中：仅凭一个循环判断；其他地方可能访问全部字段（只做 allocator.free(e.f) 的 deinit 释放循环已跳过）；G3 样本全 OK-idiom（单字段 AoS 启发式）→ 默认 off，--enable zp-aos-single-field 可开" },
    .{ .id = .catch_unreachable_alloc, .code = "zp-catch-unreachable-alloc", .name = "catch-unreachable-alloc", .severity = .off, .msg_zh = "对可能 OOM 的调用使用 catch unreachable", .msg_en = "`catch unreachable` on a fallible allocation", .fix = "ReleaseFast 下 OOM 会变成未定义行为；用 try 传播，或 catch @panic(\"OOM\")，或先预留容量", .fp_risk = "低；G3 样本全 OK-idiom（Zig 项目常见 abort-on-OOM）→ 默认 off，--enable zp-catch-unreachable-alloc 可开" },
    .{ .id = .oversized_enum_tag, .code = "zp-oversized-enum-tag", .name = "oversized-enum-tag", .severity = .off, .msg_zh = "enum 显式 tag 类型远大于所需", .msg_en = "enum explicit tag type is wider than needed", .fix = "去掉显式 tag 让编译器推断最小宽度，或用 enum(u8)；仅在 ABI/协议要求时保留宽 tag", .fp_risk = "中：与 C ABI 或线上格式对接时宽 tag 是必须的；G3 样本全 OK-idiom（ABI/协议宽 tag）→ 默认 off，--enable zp-oversized-enum-tag 可开" },
    .{ .id = .optional_scalar_field, .code = "zp-optional-scalar-field", .name = "optional-scalar-field", .severity = .off, .msg_zh = "结构体字段是可选标量（?u32 等），额外 flag 会被对齐放大", .msg_en = "optional scalar field (?u32 etc.) adds a flag byte padded by alignment", .fix = "用哨兵值（maxInt）或 enum(u32) { none = maxInt(u32), _ }；指针可选 ?*T 无此开销", .fp_risk = "中：Options/Config/Cli 等命名或多数字段为可选标量的配置型 struct 已跳过；Node/Item/Entry 等稠密元素名仍报告。权衡：可能漏报「名叫 Config 却大量分配」的类型；G3 样本全 OK-idiom（API/冷 optional 标量）→ 默认 off，--enable zp-optional-scalar-field 可开" },
    .{ .id = .bool_array, .code = "zp-bool-array", .name = "bool-array", .severity = .off, .msg_zh = "用 bool 数组/切片存位标志", .msg_en = "array/slice of bool used as a bit set", .fix = "改用 std.bit_set.Static(N) / std.bit_set.Dynamic，省 8 倍内存，且可按字批量运算", .fp_risk = "低-中：需要按元素取地址或并发写不同元素时 bool 数组更合适；G3 样本全 OK-idiom（小/非热 bool 数组）→ 默认 off，--enable zp-bool-array 可开" },
    .{ .id = .static_string_map, .code = "zp-static-string-map", .name = "static-string-map", .severity = .info, .msg_zh = "StringHashMap 只用字面量键填充", .msg_en = "StringHashMap populated only with literal keys", .fix = "键在编译期已知时用 std.StaticStringMap(V).initComptime(.{ ... })：零分配、零初始化", .fp_risk = "低：只在同一函数内 ≥3 次 put 且全部为字符串字面量键时报告" },
    .{ .id = .runtime_div_in_loop, .code = "zp-runtime-div-hot", .name = "runtime-div-hot", .severity = .off, .msg_zh = "循环内除以/取模运行时变量", .msg_en = "division/modulo by a runtime value — cost adds up even off a hot path", .fix = "整数除法很慢；容量取 2 的幂用 & (n-1)，或把除数提为 comptime 常量，或循环外预计算倒数", .fp_risk = "中：跳过顶层 const、SCREAMING_SNAKE、std.time.*、capacity/cap/mask；路径含 crypto/ 或 compiler_rt/ 时整文件跳过；函数名含 udiv/sdiv/divmod 等 soft-div 亦跳过。残余：非 crypto 的数论/编解码循环仍可能报；G3 样本全 OK-idiom（格式化/单位运算除法）→ 默认 off，--enable zp-runtime-div-hot 可开" },
    .{ .id = .queue_ordered_remove, .code = "zp-queue-ordered-remove", .name = "queue-ordered-remove", .severity = .warning, .msg_zh = "ArrayList 删除会搬移后续元素", .msg_en = "ArrayList removal shifts all following elements", .fix = "先核实队列长度上界和删除次数。FIFO 热队列可用环形缓冲；循环里多次删除可用一次稳定压缩（写指针），保留元素顺序；只有顺序无关时才用 swapRemove。长度很小且有硬上界时，搬移成本也有界", .fp_risk = "中：不识别容器类型、容量上界或顺序语义；固定小容量容器也会报告。删除后紧跟 break/return 的单次查找删除不报" },
    .{ .id = .shift_on_read, .code = "zp-shift-on-read", .name = "shift-on-read", .severity = .warning, .msg_zh = "读走前缀后把剩余数据整体搬回开头", .msg_en = "remaining bytes shifted back to the front after consuming a prefix", .fix = "若每次读取后立即搬移，小块读取时总成本可达 O(n²)；改用读游标，缓冲区耗尽时清零，或仅在已消费至少一半/追加空间不足时压缩，以保证搬移被后续读取摊销；持续流量下也可用环形缓冲/std.fifo", .fp_risk = "低：只匹配 copyForwards/@memmove(buf[0..], buf[k..]) 与 replaceRange(…, 0, n, &.{}) 这两种形态；启发式无法判断搬移是否按阈值摊销" },
    .{ .id = .per_packet_alloc, .code = "zp-per-packet-alloc", .name = "per-packet-alloc", .severity = .off, .msg_zh = "逐包/逐帧热路径中进行堆分配", .msg_en = "heap allocation on a per-packet / per-frame hot path", .fix = "每个包都 alloc/dupe/create 会把分配器放进数据面；用固定大小块的 MemoryPool / 预分配缓冲环 / 每会话 arena，或让调用方提供缓冲", .fp_risk = "中：热函数按名字推断、可 --hot-fn 追加或用 // zperf-lint: hot ； callconv(.c) （ C ABI ）； handle ；G3/r4 热名/callconv(.c) 启发式在成熟树上几乎全 OK-idiom → 默认 off，--enable zp-per-packet-alloc 可开；少数请求路径仍有诚实 TP" },
    .{ .id = .invariant_float_div, .code = "zp-invariant-float-div", .name = "invariant-float-div", .severity = .hint, .msg_zh = "循环内除以循环不变的浮点数", .msg_en = "floating-point division by a loop-invariant value inside a loop", .fix = "循环外先算 const inv = 1.0 / d（或把不变部分 a / d 提出），循环内改乘法；浮点除法吞吐约为乘法的 1/4~1/10，且没有 fast-math 时编译器不会替你改写（结果会有末位舍入差异）", .fp_risk = "中：浮点性靠声明（: f32/f64、@floatFromInt、浮点字面量）推断；只报除数是循环内未声明、未赋值的标识符、且结果直接写入数组元素/指针目标（x[i] = … / d）的内核形态；@floatFromInt 计数比例和 print/report 类函数跳过" },
    .{ .id = .map_put_without_ensure, .code = "zp-map-put-without-ensure", .name = "map-put-without-ensure", .severity = .off, .msg_zh = "循环内 HashMap put/getOrPut，循环前没有 ensure* 预留", .msg_en = "HashMap put/getOrPut without prior ensureTotalCapacity/ensureUnusedCapacity — cost adds up even off a hot path", .fix = "循环前 map.ensureTotalCapacity(gpa, n) 或 ensureUnusedCapacity；热路径上反复 rehash 很贵", .fp_risk = "中：跳过 arena/测试块；键数量无法预估时预留可能浪费；非 HashMap 的 put 也可能误报；G3 样本全 OK-idiom（N 未知的 map put）→ 默认 off，--enable zp-map-put-without-ensure 可开" },
    .{ .id = .catch_unreachable_io, .code = "zp-catch-unreachable-io", .name = "catch-unreachable-io", .severity = .off, .msg_zh = "对可能失败的 I/O 使用 catch unreachable", .msg_en = "`catch unreachable` on fallible I/O (read/write/accept/connect/send/recv/…)", .fix = "ReleaseFast 下 I/O 错误会变成未定义行为；用 try 传播或显式处理 error，不要用 unreachable 吞掉", .fp_risk = "中：聚焦 accept/connect/send/recv/read/write/open*；不含 writeAll/setsockopt/close/eventfd；测试块及其中嵌套 fn 跳过；G3 样本全 OK-idiom（可信路径 I/O unreachable）→ 默认 off，--enable zp-catch-unreachable-io 可开" },
    .{ .id = .arena_reset_free_all, .code = "zp-arena-reset-free-all", .name = "arena-reset-free-all", .severity = .warning, .msg_zh = "循环内 ArenaAllocator.reset(.free_all) 或 deinit+重建", .msg_en = "ArenaAllocator.reset(.free_all) or deinit+recreate inside a loop", .fix = "改用 reset(.retain_capacity) 或 reset(.{ .retain_with_limit = N })，避免 keepalive/请求循环里反复归还页；超大请求后再 free_all/收紧上限", .fp_risk = "中：只匹配接收者名含 arena/aa 等，且模式为 .free_all；其它 .reset()（params/kv）不报；deinit+init 需同循环内同时出现 ArenaAllocator" },
    .{ .id = .create_destroy_in_loop, .code = "zp-create-destroy-hot", .name = "create-destroy-hot", .severity = .info, .msg_zh = "循环内对同一类型 create 又 destroy", .msg_en = "allocator.create(T) paired with destroy; prefer a pool — cost adds up even off a hot path", .fix = "改用 std.heap.MemoryPool(T) 或对象池，避免热路径反复向通用分配器租还同尺寸对象", .fp_risk = "中：要求同循环体内同时出现 create(Type) 与 .destroy(；跳过 pool/arena 接收者与测试；无法证明类型相同，仅启发式" },
    .{ .id = .fixed_size_alloc_in_loop, .code = "zp-fixed-size-alloc-hot", .name = "fixed-size-alloc-hot", .severity = .info, .msg_zh = "循环内分配固定长度 []u8", .msg_en = "alloc(u8, comptime_int) of fixed size — cost adds up even off a hot path", .fix = "固定 size-class 缓冲池（tryAlloc / MemoryPool([N]u8) / 预分配切片），避免每次都走通用分配器", .fp_risk = "中：只报 alloc(u8, 字面量) 且字面量 ≥ 16；跳过 arena/pool/测试；与 zp-alloc-hot 可能同点并存" },
    .{ .id = .open_file_in_loop, .code = "zp-open-file-hot", .name = "open-file-hot", .severity = .hint, .msg_zh = "循环内打开文件；路径不变时应在循环外打开", .msg_en = "file opened; open once when the path stays the same — cost adds up even off a hot path", .fix = "同一路径在循环外打开一次再读。路径每次都变时无法外提。", .fp_risk = "中：路径随迭代变化时必须重新打开；默认 hint，未做语料分诊" },
    .{ .id = .clock_in_loop, .code = "zp-clock-hot", .name = "clock-hot", .severity = .hint, .msg_zh = "循环内采样时钟；稳态外采样一次", .msg_en = "clock sample; sample once outside the steady state — cost adds up even off a hot path", .fix = "不需要每次都是新时间戳时，在循环外采样一次。", .fp_risk = "中：每轮都要新时间戳时没有可外提的对象；默认 hint，未做语料分诊" },
    .{ .id = .json_in_loop, .code = "zp-json-hot", .name = "json-hot", .severity = .hint, .msg_zh = "循环内解析同一份 JSON；载荷不变时应在循环外解析一次", .msg_en = "JSON parsed; parse once when the payload stays the same — cost adds up even off a hot path", .fix = "同一段文本在循环外 parseFromSlice 一次。每轮载荷都变时无法外提。", .fp_risk = "中：载荷随迭代变化时必须重新解析；默认 hint，未做语料分诊" },
    .{ .id = .alloc_print_in_loop, .code = "zp-alloc-print-hot", .name = "alloc-print-hot", .severity = .hint, .msg_zh = "循环内对不变的值 allocPrint / Allocator.print；应在循环外格式化一次", .msg_en = "allocPrint or Allocator.print of a loop-invariant value", .fix = "格式参数在循环内不变时，在循环外格式化一次并复用切片。参数随迭代变化时无法外提。", .fp_risk = "中：只把字面量和循环内未赋值、非捕获、非循环内声明的标识符当不变；字段写入和索引赋值看不到。值随迭代变化时不报。默认 hint，未做语料分诊" },

};
pub fn get(id: Id) *const Rule {
    return &all[@backingInt(id)];
}

/// See the English guide for context.
pub fn parse(s: []const u8) ?Id {
    for (all) |r| {
        if (std.ascii.eqlIgnoreCase(s, r.code) or std.mem.eql(u8, s, r.name)) return r.id;
    }
    return null;
}

comptime {
    for (all, 0..) |r, i| std.debug.assert(@backingInt(r.id) == i);
}
