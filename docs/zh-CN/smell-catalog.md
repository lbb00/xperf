# XPerf 跨语言气味目录

**XPerf** 总览图：跨套件相同的 *性能异常*。规则 ID 是 **每套件独有**（不共享）。在一个运行时上的 YES / 测量比 **不** 能转移到另一个运行时 —— 在迁移建议前需重新基准测试。

| 工具包 | 语言 | Lint ID |
|-----|----------|----------|
| [zperf](../../packages/zperf/) | Zig | zp-alloc-hot–zp-alloc-print-hot |
| [cperf](../../packages/cperf/) | C | cp-alloc-hot–cp-struct-by-value |
| [jsperf](../../packages/jsperf/) | JS/TS (V8) | jp-alloc-hot–jp-clone-per-event |
| [jvmperf](../../packages/jvmperf/) | Java/Kotlin | 29 个活跃的 `jp-*` 标识符, `jp-boxed-primitive-collection`…`jp-non-static-field-updater`（参见其 `docs/rule-ids.md`; **≠** jsperf） |
| [goperf](../../packages/goperf/) | Go | gp-make-hot–gp-time-now-hot |
| [pyperf](../../packages/pyperf/) | Python | pp-str-plus-hot–pp-open-hot |
| [swiftperf](../../packages/swiftperf/) | Swift | sp-array-no-reserve, sp-print-hot，以及 sp-dateformatter-hot / sp-json-decode-hot / sp-regex-hot / sp-file-read-hot / sp-clock-hot / sp-value-for-key-hot |
| [arktsperf](../../packages/arktsperf/) | ArkTS | at-alloc-hot–at-json-hot |
| [cppperf](../../packages/cppperf/) | C++17 | `cx-regex-ctor-hot`、`cx-endl-hot`、`cx-clock-hot`、`cx-ifstream-hot`、`cx-const-by-value`、`cx-vector-bool`（已移除字符串追加和字符串流） |
| [csharpperf](../../packages/csharpperf/) | C# | cs-list-add-no-capacity–按名称访问字段热 |
| [phpperf](../../packages/phpperf/) | PHP | ph-string-dot-hot–ph-echo-hot |
| [rubyperf](../../packages/rubyperf/) | Ruby | rb-string-plus-hot–rb-file-read-hot |
| [rustperf](../../packages/rustperf/) | Rust | rs-alloc-hot–rs-clock-hot (`rs-map-new-hot` 恢复，大约 1.5×) |
| [kotlinperf](../../packages/kotlinperf/) | Kotlin | `kt-list-add-hot`–`kt-println-hot`（已移除 empty-add） |
| [objcperf](../../packages/objcperf/) | Objective-C | `oc-nsstring-append-hot` / `oc-nslog-hot`（都关闭），加上 `oc-dateformatter-hot` / `oc-json-hot` / `oc-regex-hot` / `oc-file-read-hot` / `oc-clock-hot` / `oc-value-for-key-hot`（已移除 array-add） |
| [dartperf](../../packages/dartperf/) | Dart | dt-list-add-empty–dt-growable-add-empty |
| [luaperf](../../packages/luaperf/) | Lua | lu-table-insert-hot–lu-print-hot |
| [beamperf](../../packages/beamperf/) | Elixir + Erlang | be-list-concat-reduce–be-enum-map-filter-chain |
| [nimperf](../../packages/nimperf/) | Nim | nm-seq-add-hot–nm-seq-no-capacity |

**前缀重叠：** jsperf 和 jvmperf 都使用 `jp-` 前缀，但它们的 slug 集合是分开的。例如 `jp-boxed-primitive-collection` (~5.96×) 仅存在于 jvmperf，而 `jp-alloc-hot` (~19×，在应用预设下关闭) 仅存在于 jsperf。引用 `jp-*` 规则时请始终注明工具包名称。

---

## 如何阅读

1. 选择一个**气味** → 在将某个发现作为速度声明处理之前，先打开每个工具包的规则 + `packages/<kit>/evidence/<ID>.md`。
2. **证据**列引用的比率已在 evidence-policy / JSONL / STATIC-VS-* 中存在 — **不是这里凭空创造的**。
3. 单元格：
   - rule id + 简短备注 = 已发布的 lint（或指南示例）
   - **n/a** = 运行时物理不同；不要强行映射
   - **pending** = 规则或存根存在；尚无真实的时钟 JSONL
   - **guide** = 仅章节/示例（尚无 lint）
4. 跨语言移植必须**重新基准测试** ([roadmap-next.md](roadmap-next.md) §5)。
5. 固定装置触发 ≠ 速度；deopt / PrintCompilation 行数 ≠ 升级 ([rule-regression.md](rule-regression.md))。

---

## 目录

| 气味 | zperf | cperf | jsperf | jvmperf | 证据 | 备注 |
|-------|-------|-------|--------|---------|----------|-------|
| **alloc-in-loop / arena / pool** | **zp-alloc-hot** 大约是 arena 的 1.4 倍 GPA；**zp-per-packet-alloc**（热路径，和 zp-alloc-hot 相同）；**zp-create-destroy-hot** 创建/销毁约比 pool 快 11 倍；**zp-fixed-size-alloc-hot** 固定 `alloc(u8,N)` 比 pool 快约 8.5 倍 | **cp-alloc-hot** 大约是 arena 的 10.8 倍 malloc 循环（**错误**） | **jp-alloc-hot** 大约是一次的 ~19× / ~6.4× `new`/push（在应用预设下关闭 — 分配/GC，不是去优化） | **jp-expensive-alloc-hot** 循环中昂贵的工厂（提示；tiny-pool **负**）；**jp-hot-heavy-alloc** 热重分配（**等待 ART**）；**jp-hot-payload-copy** 框架缓冲重用约 15.8 倍（**错误**） | z: zp-alloc-hot, zp-create-destroy-hot, zp-fixed-size-alloc-hot JSONL；c: cp-alloc-hot；js: jp-alloc-hot；jvm: jp-expensive-alloc-hot, jp-hot-payload-copy (+ jp-hot-heavy-alloc stub) | 相同的 *思路*（提取/重用）；Zig smp 已经很便宜 → 固定大小优先使用 pool。jvm jp-expensive-alloc-hot ≠ “总是 pool”。 |
| **缓冲区增长 / 容量 / 构建器** | **zp-append-without-reserve** 约为 append reserve 的 2.1 倍；**zp-map-put-without-ensure** 约为 map ensure 的 2.8 倍；**zp-shift-on-read** 约为 cursor 的 17 倍 (**候选错误**) | **cp-realloc-grow-one** 约为 realloc+1 的 12.6 倍，相对于翻倍 (**错误**) | **jp-string-plus-in-loop** (**已移除** 2026-10-23；`push`+`join` 并不是约 2 倍); V8 数组增长方式不同；预分配似乎在 jp-alloc-hot 的良好场景下有效 | **jp-string-concat-hot** 约为字符串 `+=` 的 14.2 倍，相对于构建器 (**错误**)；**jp-unpresized-collection** 约为无预设填充的 1.6 倍 (**提示** 部分); **jp-baos-tobytearray-copy** 约为 BAOS `toByteArray` 的 12.8 倍，相对于 `writeTo` (**错误**) | z: zp-append-without-reserve, zp-shift-on-read, zp-map-put-without-ensure; c: cp-realloc-grow-one; jvm: jp-string-concat-hot, jp-unpresized-collection, jp-baos-tobytearray-copy | 最接近的跨套件对：cp-realloc-grow-one ↔ zp-append-without-reserve ↔ jvm jp-string-concat-hot。与 JS 空洞数组不同。 |
| **热点 IO / 打印 / 日志 / 格式化** | **zp-print-hot** ~6e4× 打印对比安静模式（**环境 I/O**，不升级）； **zp-unbuffered-io** ~49× 空 Writer 对比 4KiB（**候选错误**） | **cp-printf-hot** ~4.8× 无缓冲/缓冲 热操作；`#if 0` ~1× → **关闭**（默认应用预设） | **jp-console-hot** ~1328× 控制台对比安静模式（**应用关闭 / 引擎提示 — 环境**） | **jp-format-hot** ~17× `String.format` 热操作（**错误**）；**jp-log-hot** ~28× 未保护的日志拼接（**错误**）；**jp-hot-format-log** 热格式化/日志（**待 ART**） | z: zp-print-hot, zp-unbuffered-io; c: cp-printf-hot; js: jp-console-hot; jvm: jp-format-hot, jp-log-hot (+ jp-hot-format-log stub) | 优先使用缓冲 I/O / 级别保护。不要单独升级环境绑定的打印。 |
| **形状 / 布局 / SoA / 密度** | **zp-aos-single-field** 约 6.6× AoS→SoA；**zp-packable-bools** / 相关密度存根（**待定**）；**zp-large-struct-by-value** 按值（**不确定** `-Ofast`）；**zp-bool-array** 约 30× bool[] 对比 bitset | **指南** SoA 示例（`p01_soa.c`）；**无 CP 规则** | 指南 **§04** 映射 / IC / 多态（静态 VS V8 约 12×）；**无布局 JP** | **jp-many-boolean-fields**（**已移除** 2026-10-22；COH 16=16 无收益）；Kotlin 其他地方布局气味 | z: zp-aos-single-field, zp-bool-array JSONL + 待处理存根；移除外部填充（约 1.2×）；js: STATIC-VS-V8；jvm: jp-many-boolean-fields | V8 隐藏类 ≠ C 填充 ≠ Zig `extern` ≠ HotSpot 对象头. |
| **有孔/稀疏元素** | **不适用** — Zig 切片 ≠ V8 元素类型 | **不适用** — C 的“稀疏”指 CSR/哈希，是不同的问题 | **jp-delete-array-hole** ~3.2× 有孔 `delete a[i]` vs 紧凑（**错误**）；静态 case2 ~5.5× | **jp-android-sparse-array** Android SparseArray（**待 ART 支持**） — **不是** V8 有孔 | js：jp-delete-array-hole（+ 静态 VS V8）；jvm：仅 jp-android-sparse-array 桩 | **不要**将 jp-delete-array-hole 映射到 CP 或 ZP。Android Sparse* ≠ V8 有孔。 |
| **删除 / 移除 / 墓碑** | **zp-queue-ordered-remove** ~466× `orderedRemove` 与 ring (**候选错误**) | **不适用** | **jp-delete-shape** ~474× `delete` 属性 (**在应用程序预设下关闭 — G3 OK-习惯用法降级**) | **不适用** 作为 V8/Zig 移除；最接近的重用气味是 buffer/pool | js: jp-delete-shape; z: zp-queue-ordered-remove | 相关 *中间结构删除的成本*，不是相同的气味 (JS 墓碑 ≠ Zig memmove)。 |
| **同步 / 锁 / 受争用的类型** | **不适用**（无 ZP 同步规则） | **不适用** | **不适用** | **jp-legacy-synchronized-type**（**已移除** 2026-10-22；约 1.08× / HT 负） | jvm: `_removed/` 墓碑 | 受争用的锁成本取决于工作负载；单独的微基准不会升级。 |
| **装箱 / 值装箱 / 流装箱** | **不适用**（无托管装箱） | **不适用** | **不适用**（数字是值；对象在 alloc jp-alloc-hot 下） | **jp-boxed-primitive-collection** 约 5.96× 装箱集合（**错误**）；**jp-boxed-stream** 约 149× 装箱流（**错误**）；**jp-value-class-boxing** 约 5× 每操作值类装箱（**错误**） | JVM: jp-boxed-primitive-collection, jp-boxed-stream, jp-value-class-boxing; STATIC-VS-HOTSPOT | JVM 特定；jsperf 没有装箱规则。 |
| **字符串 / intern / concat 系列** | **不适用** 作为 JVM intern；Zig 有 zp-static-string-map StaticStringMap ~2.5× | **不适用** | **不适用** 作为 intern（jp-string-plus-in-loop **已移除** 2026-10-23；在 jp-alloc-hot 下的分配成本） | **jp-string-concat-hot** concat（**错误**）；**jp-string-intern-hot** ~6.6× `intern()` 在循环中（**错误**）；**jp-format-hot** format（**错误**） | jvm: jp-string-concat-hot, jp-format-hot, jp-string-intern-hot; z: zp-static-string-map | 与 jp-format-hot 的 hot-IO/format 行重叠；此处列出用于字符串表 / 构建器系列。 |
| **正则 / 解析控制流** | **不适用** | **不适用** | **jp-map-filter-chain** (**提示**；35000 行 ~4.6×–9.8×，3 行过滤+映射 ~1.3×) | **jp-regex-hot** ~1.36× 循环中正则编译 (**提示**)；**jp-exception-control-flow** ~64× 异常作为控制流 (**错误**) | jvm: jp-regex-hot, jp-exception-control-flow | 正则的墙较弱 → 保持提示；异常作为控制流较强。 |
| **集合链 / 复制 / lambda 分配（Kotlin）** | **不适用** | **不适用** | **不适用** | **jp-collection-chain** ~265× 急切链（**关闭**）；**jp-lambda-to-non-inline-hot** ~244× 每操作字节非内联 lambda（**关闭**）；**jp-data-copy-hot** ~208× 循环中的 `copy`（**错误**）；**jp-lazy-default-mode** 惰性模式（**待定**） | jvm：jp-collection-chain, jp-lambda-to-non-inline-hot, jp-data-copy-hot (+ jp-lazy-default-mode 存根) | 以 Kotlin 为中心；每操作字节通常比每操作纳秒更清晰。 |
| **枚举 / 映射 专用化** | **zp-static-string-map** StaticStringMap ~2.5×（字面键） | **不适用** | **不适用** | **jp-enum-key-hash-collection** ~2.1× EnumMap 对比 HashMap 枚举键（**错误**） | z: zp-static-string-map; jvm: jp-enum-key-hash-collection | 编译时 / 序号映射 — 类似的*想法*，不同的 API。 |
| **客户端 / 更新器 / 工厂重建** | **不适用** | **不适用** | **不适用** | **jp-客户端-工厂-重建** ~5e5× HttpClient 新建 vs 重用 (**错误**); **jp-非静态字段-更新器** 创建 ~165× / 稳定增长 ~1.0× (**提示**) | JVM: jp-客户端-工厂-重建, jp-非静态字段-更新器 | 工厂重用; 稳态可能平稳 (jp-非静态字段-更新器)。 |
| **Android / ART 设备气味** | **不适用** | **不适用** | **不适用** | 仅 **jp-android-sparse-array**、**jp-hot-heavy-alloc–jp-ui-text-append** 存根（**等待 ART/设备**）：SparseArray、热分配、格式/日志、系统调用、Bitmap、Handler post、UI 文本 | jvm 证据存根 jp-android-sparse-array … jp-ui-text-append | 在 ART/设备工具箱之前，没有 box JSONL。 |
| **正确性 / 仅限静态（非速度门槛）** | **zp-debug-allocator** 模式切换；**zp-missing-free** 内存泄漏；**zp-catch-unreachable-alloc** `catch unreachable`；**zp-oversized-enum-tag** 枚举标签大小 — 全部 **不适用** 墙 | — | — | **jp-finalize** finalize（**设计/正确性待定**）；**vt-unsafe-threadlocal-pool** 仅指导 VT/pool 神话（**未发布**） | z: stubs zp-debug-allocator / zp-missing-free / zp-catch-unreachable-* / zp-oversized-enum-tag；jvm: jp-finalize + vt-unsafe-threadlocal-pool | 不要为这些发明速度 JSONL。 |

---

**目录行：** 15 个气味家族（z/c/js/jvm）+ go/py/swift/arkts/cpp/csharp/php/ruby/rust/kotlin/objc/dart/lua/beam/nim 的版块。**所有 19 套工具包均可用于语料库**（AGENT.md G3, 2026-10-22 Asia/Shanghai）— 结果仍为启发式，不保证加速效果。

**jvmperf 策略快照：** 查看 `packages/jvmperf/docs/evidence-policy.md` 以获取当前的错误/提示/关闭/待处理映射（slug ID）。仅供参考：`vt-unsafe-threadlocal-pool`（未发布）。已移除无效测量：`jp-legacy-synchronized-type`，`jp-many-boolean-fields`。

---

## 更新的套件

默认设置大多是**关闭**或**提示**。以下所有套件在 G3 下都是**语料库就绪**的。大多数规则都有测量的 JSONL（见 [rule-regression.md](rule-regression.md)）；nimperf 没有，因为 G4 被阻止（没有工具链）。在升级严重性之前请重新基准测试。

| 气味 | goperf | pyperf | swiftperf | arktsperf | 备注 |
|-------|--------|--------|-----------|-----------|-------|
| **循环中分配 / 竞技场 / 池** | **gp-使热** 循环中的 `make`/`new` (**关闭**) | 作为 make **不适用**；最接近的是 pp-list-plus-rebind 列表增长 | **不适用** (ARC) | **在分配时变热** 循环中的对象/`new`/push`{` (**关闭**) | 与 cp-alloc-hot / js jp-alloc-hot 相同的*理念*；每个工具包的证据策略中的比例（swift: 无，G4 阻塞） |
| **缓冲区增长 / 字符串构建器** | **gp-string-plus-hot** 字符串 `+=` (**关闭**); **gp-append-nil-slice** 在 nil 切片上 append (**提示**) | **pp-str-plus-hot** 字符串 `+=` (**关闭**); **pp-list-plus-rebind** 列表 `+` 重新绑定 (**提示**) | **sp-array-no-reserve** 在不使用 `reserveCapacity` 的情况下 append (**提示**); 字符串 `+=` 被移除 (~1×，reserve 更慢) | *(折叠到 at-alloc-hot)* | 最接近 jvm jp-string-concat-hot / cp-realloc-grow-one 系列 |
| **热 IO / 打印 / 日志** | **gp-fmt-hot** 循环中的 `fmt.*printf` (**关闭**) | **pp-print-hot** `print(` (**关闭**) | **sp-print-hot** `print(` (**关闭**) | **at-console-hot** `console.*` (**关闭**) | 与环境绑定；未升级 |
| **删除 / 形状** | **不适用** | **不适用** | **不适用** | 没有 ArkTS 删除规则（已移除；节点代理约 1×） | 与 jsperf jp-delete-shape 的想法一致；ArkTS 虚拟机可能不同 |
| **强制解包 / 不安全可选** | **不适用** | **不适用** | 不允许强制解包的规则（已移除；与 `if let` 同时） | **不适用** | Swift 特定 |
| **循环中的 defer / 链 / 查找** | **gp-defer-hot** 循环中的 `defer`（**提示**） | **不适用** | 无 `map`/`joined` 规则（已移除；约 1.2×） | **at-includes-hot** `includes` 查找（**提示**）；**at-json-hot** `JSON.parse`/`stringify`（**提示**） | 特定于 Kit；不暗示跨 Kit 映射 |

### cpp / csharp / php / ruby

| 气味 | cppperf | csharpperf | phpperf | rubyperf | 备注 |
|-------|---------|------------|---------|----------|-------|
| **缓冲区增长 / 容量** | **已移除**（向量在未预留容量的情况下推入 — 墓碑）| **cs-list-add-no-capacity** `List.Add` 无容量 (**关闭**) | **ph-array-merge-rebind** `array_merge` 重新绑定 (**错误**) | **rb-array-plus-rebind** 数组 `+` / 拼接 (**关闭**)。`Hash#merge` 已移除（在 Ruby 4.0.8 中，字面构建更慢且分配更多） | 与 cp-realloc-grow-one / jvm jp-unpresized-collection 相同 *理念*；php 是唯一有 `错误` 的（G4）|
| **字符串构建器** | 没有 C++ 字符串追加规则（已移除；~1.1×） | **cs-string-plus-hot** 字符串 `+=`（**关闭**） | **ph-string-dot-hot** `.=`（**关闭**） | **rb-string-plus-hot** 字符串 `+=`（**关闭**） | 最接近 jvm jp-string-concat-hot / gp-string-plus-hot |
| **热 IO / 打印** | **已移除**（循环中的 iostream — 墓碑）| **cs-console-hot** `Console.Write*` (**关闭**) | **ph-echo-hot** `echo`/`print` (**提示**) | **rb-puts-hot** `puts`/`print` (**关闭**) | 受环境限制；未升级 |
| **循环中的正则表达式** | — | **cs-regex-hot** 循环中的正则表达式（**提示**） | — | — | 最接近 jvm jp-regex-hot；弱墙，保持提示 |
| **边界检查索引** | **已移除**（循环中的 `.at()` — 墓碑；反向 @-O2） | — | — | — | 当索引已验证时，优先使用 `operator[]`；规则未发布 |

**cppperf vs cperf:** cppperf 专用于 C++17；cperf 保持 C11（+ 轻量 C++）。

### rust / kotlin / objc / dart / lua / beam

| 气味 | rustperf | kotlinperf | objcperf | dartperf | luaperf | beamperf | 备注 |
|-------|----------|------------|----------|----------|---------|----------|-------|
| **缓冲区增长 / 容量** | **rs-alloc-hot** 分配/克隆 (**关**)；**rs-collect-vec-hot** 循环中收集 (**提示**)；带大小的 `Vec::new` 加上 push 已移除 (~1× 大填充) | **kt-list-add-hot** 列表分配 (**关**) | **已移除** (NSMutableArray 添加 — 墓碑) | **dt-list-add-empty** List.add (**关**)；**dt-growable-add-empty** 空可增长 + 添加 (**提示**) | **lu-table-insert-hot** table.insert (**关**) | **be-list-concat-reduce** 列表 `++` (**提示**)；**be-map-merge-hot** `Map.merge` (**提示**)；**be-enum-map-filter-chain** 先 map 后 filter (**提示**) | 与 cp-realloc-grow-one 相同的 *想法* |
| **字符串构建器** | **rs-format-rebind-hot** `format!` 重绑定 (**错误**, ~99×); 平均分摊 `+=` 已移除 (~1×) | **kt-string-plus-hot** 字符串 `+=` (**关闭**) | **oc-nsstring-append-hot** stringByAppendingString (**关闭**) | **dt-string-plus-hot** 字符串 `+` (**关闭**) | **lu-string-concat-hot** `..` (**错误**) | **已移除** (`<>` 追加 — 墓碑; 混合/反向) | 最接近 JVM jp-string-concat-hot; Rust 区分平摊与 format! |
| **热 IO / 打印** | **rs-println-hot** println! (**提示**) | **kt-println-hot** println (**关闭**) | **oc-nslog-hot** NSLog (**关闭**) | **dt-print-hot** print (**关闭**) | **lu-print-hot** print (**提示**) | **be-io-puts-hot** IO.puts / io:format (**关闭**) | 环境绑定；未升级 |

**kotlinperf** 是以 Kotlin 为优先的启发式方法；测量的 JVM/JMH 证据保留在 **jvmperf** 中（不要重复）。**objcperf** ≠ **swiftperf**。**beamperf** 涵盖 `.ex`/`.exs`/`.erl`。

### 尼姆

| 气味 | nimperf | 备注 |
|-------|---------|-------|
| **缓冲区增长 / 容量** | **nm-seq-add-hot** 循环中序列 `.add` （G3 后 **关闭**）；**nm-seq-no-capacity** 空序列 + `.add` （**提示**） | Nim/Arraymancer/nimbus 上的 OK-惯用法；可选。没有 JSONL（G4 被阻止，没有 `nim`） |
| **字符串构建器** | **已移除** (`&=` / `s = s & x` — 墓碑；`join` 更慢) | 最接近 jvm jp-string-concat-hot / rb-string-plus-hot |
| **热 IO / 打印** | **nm-echo-hot** 在循环中 `echo` (**关闭**) | 环境绑定；未升级 |

## 空 / 稀薄的细胞（诚实）

| Gap | Why |
|-----|-----|
| cperf **SoA lint** | 仅供指南示例。**cp-wide-bool-flags** 是四个全宽布尔标志的提示，并不是 SoA 规则 |
| jsperf **打印** 映射但严重性 **关闭**（应用）| 已测量，环境绑定 |
| jsperf **buffer-grow** 专用规则 | 通过 jp-alloc-hot 预分配测试工具粗略覆盖；由于 join 基准测试错过了约 2 倍，jp-string-plus-in-loop 已被移除 |
| zperf **同步/锁定** | 无规则 |
| 跨套件 **有孔** 外部 js | 物理差异 → 设计上 **不适用** |
| jvm **jp-android-sparse-array** … **jp-ui-text-append** | 需要 ART/设备 |
| zperf **zp-可打包布尔值** / **zp-usize-索引字段** / **zp-可选标量字段** 密度 | 待定密度测试工具 |
| jvm **jp-sleep-polling** sleep-polling | 待定 — 设计/情境，不是微观 |
| **vt-unsafe-threadlocal-pool** | 首先指南；不在 `Rule.RULES` 中 |
| nimperf **证据** | G4 被阻止（测量主机上没有 Nim 工具链）；仅为存根，没有 JSONL |
| arktsperf / objcperf **证据** | 在代理上测量（Node/V8，GNUstep），而非目标运行时 |
| swiftperf **在 Linux CI 上构建** | 需要 Swift 工具链；缺失时跳过测试 |
| csharpperf **无需 SDK 构建** | 需要 `dotnet`；缺失时跳过测试 |
| arktsperf **设备基准测试** | 首选 HarmonyOS 设备；仅使用节点代理不会提升权限 |
| cppperf 与 cperf 重叠 | 故意拆分：C++ 工具包与 C11 工具包分开 |

---

## 证据指示

| 工具包 | 策略 | 关联 / 批次（不在仓库中） |
|-----|--------|----------------------------------|
| 共享 | [规则回归.md](rule-regression.md) | 本目录 |
| zperf | [packages/zperf/docs/evidence-policy.md](../../packages/zperf/docs/zh-CN/evidence-policy.md) | `packages/zperf/evidence/` |
| cperf | [packages/cperf/docs/evidence-policy.md](../../packages/cperf/docs/zh-CN/evidence-policy.md) | `STATIC-VS-O2`（不在仓库中） |
| jsperf | [packages/jsperf/docs/evidence-policy.md](../../packages/jsperf/docs/zh-CN/evidence-policy.md) | `STATIC-VS-V8`（不在仓库中） |
| jvmperf | [packages/jvmperf/docs/evidence-policy.md](../../packages/jvmperf/docs/zh-CN/evidence-policy.md) | `STATIC-VS-HOTSPOT`，`EVIDENCE-BATCH`（不在仓库中） |

上面命名的相关和批处理笔记**不**属于此 git 仓库——它们仅作为普通名称列出，以便 GitHub 界面不会出现 404。

---


## 热编译 / 解析 / 查询 (2026-10-23)

这些蛞蝓是**提示**。固定装置是成对的。没有 JSONL，它们不是 2026-10-22 语料裁决的一部分。

| 套件 | 译名 | 气味 |
|-----|------|-------|
| pyperf | pp-json-hot | 循环中的 `json.loads` / `dumps` |
| pyperf | pp-deepcopy-hot | 循环中的 `deepcopy` |
| jsperf | jp-regex-ctor-hot | `new RegExp`（稳定模式；默认作用域全部） |
| jsperf | jp-json-hot | `JSON.parse` / `stringify`（稳定文本；默认范围全部） |
| jsperf | jp-dom-query-hot | `querySelector` / `getElementById`（稳定选择器；默认范围全部） |

| jsperf | jp-query-all-star | `querySelectorAll('*')` 全树遍历（包括模板） |
| jsperf | jp-execjs-in-timer | 在定时器内构建了 `executeJavaScript`/`evaluate` |
| jsperf | 每事件的 jp 克隆 | `structuredClone` / 事件类参数的 JSON 往返转换 |
| goperf | gp-regexp-compile-hot | 循环中的 `regexp.Compile` |
| goperf | gp-json-marshal-hot | 循环中的 `json.Marshal` / `Unmarshal` |
| goperf | gp-reflect-hot | 循环中的 `reflect.TypeOf` / `ValueOf` |
| cppperf | cx-regex-ctor-hot | 在循环中构造的 `std::regex` |
| cppperf | cx-endl-hot | 循环中的 `endl` 刷新 |
| csharpperf | cs-linq-materialize-hot | 循环中的 `ToList` / `ToArray` / `ToDictionary` |
| csharpperf | cs-format-hot | 循环中的 `string.Format` |
| rubyperf | rb-regexp-new-hot | 循环中的 `Regexp.new` |
| rubyperf | rb-json-hot | 循环中的 `JSON.parse` / `generate` |
| rustperf | rs-regex-new-hot | 循环中的 `Regex::new` |

## 相关

- [overview.md](overview.md) — 伞状状态
- [playbook.md](playbook.md) — 共享循环 + 回归合同
- [roadmap-next.md](roadmap-next.md) — 空单元格的下一个填充
- [docs/README.md](README.md) — 文档索引
