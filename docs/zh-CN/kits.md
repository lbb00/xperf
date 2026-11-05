# 套件状态

列出每个包的 Lint 入口点、默认严重性和语料库注释。规则 ID 仅为 **短标签**。计数与每个工具包的 `docs/rule-ids.md` 匹配（不包括墓碑）。启发式命中是审查提示，而非加速手段。

在 AGENT.md G3 门下，所有 **19** 个工具包对于 2026-10-22（亚洲/上海）已分级的规则集都是 **语料库就绪** 的。2026-10-23 添加的提示规则 **不** 包含在该裁定中。现在有几个带有微基准测试并保持 **提示** 状态。公平重运行仍在 1× 附近的规则已被移除。新的标识没有进行语料库分级。

| 软件包 | 代码检查 | 活跃 | 备注 |
|---------|------|-------:|-------|
| [zperf](../../packages/zperf/) | `zperf-lint` | 31 | Zig 0.17+。G3/r4 降级了 OK-idiom mass 规则；一些默认设置仍然启用（例如 `zp-page-allocator-small`, `zp-broad-runtime-safety`）。`zp-alloc-print-hot` 是未更改格式字符串的提示。 |
| [cperf](../../packages/cperf/) | `cperf-lint` | 12 | C11 检查器 + 预设。`cp-alloc-hot` / `cp-realloc-grow-one` 错误；strlen, sprintf, fopen, clock, wide-bool-flag, `regcomp`, `alloca`-in-loop, 以及大值传递结构体提示；`cp-printf-hot` / `cp-strcat-hot` 在默认应用预设下关闭。2026-10-23 的提示有微基准测试，并不属于语料库裁决的一部分。 |
| [jsperf](../../packages/jsperf/) | `jsperf-lint` | 11 | 纯节点 ≥18，无 npm 依赖。`jp-delete-array-hole` 错误；map-filter / regex-ctor / JSON / DOM-query / `Intl.DateTimeFormat` / `readFileSync` / 时钟提示；在应用预设下关闭 alloc / 控制台默认设置。`jp-string-plus-in-loop` 已移除（`push` + `join` 并非约 2×）。 |
| [jvmperf](../../packages/jvmperf/) | `jvmperf-lint` | 29 | Java (Gradle)。在测试中固定使用 JDK **21**。在 G3/G4 之后混合出现错误/提示/关闭；请参阅工具包证据政策。|
| [goperf](../../packages/goperf/) | `goperf-lint` | 10 | `gp-append-nil-slice` / `gp-defer-hot` 加上正则表达式 / JSON / 反射名称查找提示；`gp-make-hot`–`gp-fmt-hot` 关闭。`time.Parse` 已被移除。 |
| [pyperf](../../packages/pyperf/) | `pyperf-lint` | 6 | `pp-list-plus-rebind` 加 JSON / deepcopy 提示；`pp-str-plus-hot` / `pp-print-hot` 关闭。`re.compile` 和 `datetime.strptime` 已被移除。 |
| [swiftperf](../../packages/swiftperf/) | `swiftperf-lint` | 8 | `sp-array-no-reserve` 提示（小构建者约 5×；一个大填充约 1.6×）。循环打印保持关闭（约 10× 输出到 /dev/null）。强制解包，字符串 `+=`，以及 `map`/`joined` 已移除。日期格式化器 / JSON 解码 / `NSRegularExpression` 提示仍然存在。2026-10-23 的提示不属于语料库判定。若缺少 Swift SDK，则进行文本检查路径。 |
| [arktsperf](../../packages/arktsperf/) | `arktsperf-lint` | 4 | 节点在 `.ets`/`.ts`/`.js` 上进行 lint 检查。`at-includes-hot` / `at-json-hot` 提示；分配 / 控制台默认关闭。 |
| [cppperf](../../packages/cppperf/) | `cppperf-lint` | 6 | 专用 C++17（≠ cperf）。regex、endl、clock、ifstream、按值 const 和 vector-bool 提示。字符串追加、字符串流以及若干 jitter id **已删除**。短 `const` 字符串保持在约 1×，并仍有提示。 |
| [csharpperf](../../packages/csharpperf/) | `csharpperf-lint` | 10 | 需要 `dotnet`。`cs-regex-hot`、LINQ 实例化、`string.Format` 和 JSON 提示；列表添加 / 字符串拼接 / 关闭控制台。 |
| [phpperf](../../packages/phpperf/) | `phpperf-lint` | 3 | `ph-array-merge-rebind` 错误 (G4); `ph-string-dot-hot` 关闭; `ph-echo-hot` 提示. |
| [rubyperf](../../packages/rubyperf/) | `rubyperf-lint` | 6 | 正则表达式 / JSON / 文件读取提示；字符串加 / 数组加 / 延迟输出。`Date.parse` 和 `Hash#merge` 已移除。 |
| [rustperf](../../packages/rustperf/) | `rustperf-lint` | 7 | `rs-format-rebind-hot` 错误；println / collect / 正则提示；`rs-alloc-hot` 关闭。已去除摊销 `+=`、`Vec::new` 加上 push，以及循环中的 `HashMap::new`。 |
| [kotlinperf](../../packages/kotlinperf/) | `kotlinperf-lint` | 3 | Kotlin-first (≠ jvmperf JMH)。所有三个规则默认关闭；一个抖动 ID **已移除**。 |
| [objcperf](../../packages/objcperf/) | `objcperf-lint` | 8 | Objective-C（≠ swiftperf）。`oc-nsstring-append-hot` / `oc-nslog-hot` 关闭；日期格式化器、JSON 和正则表达式提示。两个抖动 ID **已移除**。|
| [dartperf](../../packages/dartperf/) | `dartperf-lint` | 4 | `dt-growable-add-empty` 提示；list-add / string-plus / 打印 默认关闭。 |
| [luaperf](../../packages/luaperf/) | `luaperf-lint` | 3 | `lu-string-concat-hot` 错误 (G4); `lu-table-insert-hot` 关闭; `lu-print-hot` 提示. |
| [beamperf](../../packages/beamperf/) | `beamperf-lint` | 4 | Elixir + Erlang。list-concat / map-merge / enum-chain 提示；`be-io-puts-hot` 关闭。一个抖动ID **已移除**。 |
| [nimperf](../../packages/nimperf/) | `nimperf-lint` | 4 | 需要 `nim`。`nm-seq-no-capacity` 提示；默认关闭 seq-add / string / echo。 |

没有编造的发布网址。

历史数字 → slug 映射（命令行界面**不**接受数字）：[rule-id-map.md](rule-id-map.md)。
