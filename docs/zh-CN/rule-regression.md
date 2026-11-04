# 规则回归覆盖

截至 **2026-10-22**（亚洲/上海）。空/反向深度分析 **已落地**（rb-hash-merge-in-loop 固定装置/消息；cx-string-append-unreserved / at-includes-hot 文档；测量为无用的墓碑；无严重性升级）。证据填充批次 A：goperf/pyperf/cppperf/phpperf/rustperf/luaperf/rubyperf；nim 被阻止。合同：[playbook.md § 规则回归](playbook.md)。每套件关卡：`packages/*/docs/evidence-policy.md`。气味：[smell-catalog.md](smell-catalog.md)

**柱**

- **坏 / 好**：`packages/<kit>/*-lint/fixtures/` 下的 lint 固件
- **证据**：`packages/<kit>/evidence/` 下的 `.md` 和 `.jsonl`（速度门）
- **严重性**：包默认 / 策略（cperf·jsperf `--preset app`; jvmperf 策略映射; zperf 历史上所有发现都会导致 CI 失败）
- **待定措施**：在提交/升级到 `error` 之前需要前/后 JSONL（兄弟自己的基准 — 该矩阵不会发明比率）

固定装置测试证明规则仍然**有效**；证据证明它仍然**意味着速度**。语料库残余计数 ≠ 两者。

---


**范围 (2026-10-27):** 默认匹配是 `--scope all`（或相应的套件等效项）跨套件；选择 `--scope loop` 来启用之前仅限循环的行为。以前包含 `in-loop` 的标识符已重命名为 `*-hot` 并被作废；详见每个套件的 `docs/rule-ids.md` 重命名表。

^ cperf(cp-alloc-hot – cp-printf-hot – cp-strlen-in-cond – cp-strcat-hot) (英语).

测试夹具使用描述性名称（而不是 `cp-alloc-hot.c`）。默认值来自 `docs/evidence-policy.md` / `--preset app`。

| 规则 | 错误设置 | 良好 / 负面 | 证据 md+jsonl | 默认严重性 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| cp-alloc-hot | `bad/cp-alloc-hot_malloc_loop.c` | 是的 (`arena_hoisted.c`，…) | **是** `evidence/cp-alloc-hot.*` | **错误** | 测量门存在 |
| cp-realloc-grow-one | `bad/cp-realloc-grow-one_realloc_grow.c` | 是 (`capacity_doubling.c`, `realloc_wrapper.c`) | **是** | **错误** | 测得约 12.6 倍 realloc 增长相比翻倍 |
| cp-printf-hot | `bad/cp-printf-hot_printf_loop.c` | 是 (`dump_*`, `ifdef_dump_*`, `treeview_*`, …) | **是** | **关闭** | 热 ~4.8× unbuf/buf；`#if 0` ~1× → 保持关闭 |
| cp-strlen-in-cond | `bad/cp-strlen-in-cond_strlen_cond.c` | 是的 (`cp-strlen-in-cond_strlen_hoisted.c`, …) | 还没有 | 提示 | 没有实际运行时间基准；仅语料真阳性 |
| cp-strcat-hot | `bad/cp-strcat-hot_strcat_loop.c` | 是的 (`cp-strcat-hot_strcat_once.c`) | 还没有 | **关闭** | G3 降级（CLI/路径 OK-惯用法）；没有实际运行时间基准 |
| cp-sprintf-hot | `bad/cp-sprintf-hot_sprintf_loop.c` | 是 | jsonl | **提示** | 微基准测试在一个形状上约 13.9×；保持提示；未经过语料库分类 |
| cp-fopen-hot | `bad/cp-fopen-hot_fopen_loop.c` | 是 | jsonl | **提示** | 单个形状微基准约423.4×；保持提示；未进行语料库分流 |
| cp-gettime-hot | `bad/cp-gettime-hot_gettime_loop.c` | 是 | jsonl | **提示** | 微基准 ~33.2× 在一个形状上；保持提示；未经过语料库筛选 |
| cp-wide-bool-flags | `bad/cp-wide-bool-flags_ints.c` | 是的 (`cp-wide-bool-flags_bits.c`) | jsonl | **提示** | 微基准 ~19.1× 在一个形状上; 保持提示; 未经过语料库分类 |

---

## jsperf（slug ID）

描述性夹具名称。默认值：`--preset app`（jp-console-hot=off）。

| 规则 | 错误夹具 | 良好 / 消极 | 证据 md+jsonl | 严重性 默认 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| jp-alloc-hot | `bad/jp-alloc-hot_new_in_loop.js`, `jp-alloc-hot_push_object.js` | 是 (`prealloc.js`, `jp-alloc-hot_reuse_buffer.js`, …) | **是** | **关闭** (应用) | ~19× / ~6.4× 实际时间（分配/GC）；G3 OK-习惯降级 |
| jp-console-hot | `bad/jp-console-hot_console_loop.js` | 是 (`jp-console-hot_console_outside_loop.js`) | **是** | **关闭**（应用）/ 提示 | 如果丢弃 stdout 大约 1328×；依赖环境 → 不是 CI 错误 |
| jp-delete-shape | `bad/jp-delete-shape_delete.js` | 是 (`no_delete.js`, …) | **是** `evidence/jp-delete-shape.*` | **关闭** (应用) | G3 OK-惯用语 降级 |
| jp-delete-array-hole | `bad/jp-delete-array-hole_holey_delete.js` | 是 (`no_holey_delete.js`，…) | **是** `evidence/jp-delete-array-hole.*` | **错误** | 已测量 |
| jp-string-plus-in-loop | 已移除（`evidence/_removed/fixtures/` 下的测试用例） | 纪念碑 | `_removed/` 下的 jsonl | **已移除** | 匹配形状时 `push`+`join` 并非约 2 倍 |
| jp-map-filter-chain | `bad/jp-map-filter-chain_map_filter_chain.js` | 是 (`jp-map-filter-chain_single_map.js`, 注释夹具) | **是** | 提示 | 35000 行 ~4.6×/9.8×；3 行过滤+映射 1.28×；保持提示 |
| jp-regex-ctor-hot | `bad/jp-regex-ctor-hot_ctor_loop.js` | `good/jp-regex-ctor-hot_ctor_once.js`, pattern-varies | jsonl | 提示 | Node 26 修复模式 ~4.4×；循环绑定未报告 |
| jp-json-hot | `bad/jp-json-hot_json_loop.js` | `good/jp-json-hot_json_once.js`, 文本变化 | jsonl | 提示 | Node 26 未更改文本约 140×；未报告 `rows[i]` |
| jp-dom-query-hot | `bad/jp-dom-query-hot_query_loop.js` | `good/jp-dom-query-hot_query_once.js`, selector-varies | jsonl | 提示 | Node 26 小型 linkedom 文档 ~16×；循环绑定未报告 |
| jp-intl-datetimeformat-hot | `bad/jp-intl-datetimeformat-hot_format_loop.js` | `good/jp-intl-datetimeformat-hot_format_once.js`, 地区变化 | jsonl | 提示 | Node 26 ~36×；循环绑定未报告 |
| jp-readfile-sync-hot | `bad/jp-readfile-sync-hot_read_loop.js` | `good/jp-readfile-sync-hot_read_once.js`，for-of 头部，路径变化 | jsonl | 提示 | 仅正文；Node 26 当路径保持不变时 ~114× |
| jp-clock-hot | `bad/jp-clock-hot_clock_loop.js` | `good/jp-clock-hot_clock_once.js`，await 循环，嵌套函数/箭头函数 | jsonl | 提示 | 紧密循环 ~26×/~19×；`await` 循环未报告；跳过嵌套函数体 |
| jp-query-all-star | `bad/jp-query-all-star_star_query.js`, `jp-query-all-star_in_template.js` | `good/jp-query-all-star_narrow.js`, template narrow | 尚无 | 提示 | full-tree `*`; 消息未说明缓存该节点; 看到模板脚本 |
| jp-execjs-in-timer | `bad/jp-execjs-in-timer_interval.js` | `good/jp-execjs-in-timer_once.js` | 还没有 | 提示 | 在 setInterval/setTimeout 中构建脚本；安装一次 + 短时间清理是干净的 |
| jp-clone-per-event | `bad/jp-clone-per-event_structured.js`、`jp-clone-per-event_json_roundtrip.js` | `good/jp-clone-per-event_field.js`、无关克隆 | 还没有 | 提示 | 仅事件类参数（`e`/`event`/…） |

---

## zperf（zp-alloc-hot–zp-fixed-size-alloc-hot）

所有28个配对固定装置。证据位于 `packages/zperf/evidence/`（Zig **0.17.0** `-Ofast`，2026-10-21）。政策：`packages/zperf/docs/evidence-policy.md`。CLI 在任何发现上仍然失败；**候选错误** = 预设生效时政策升级。

| 规则 | 坏 | 好 | 证据 | rules.zig sev | 备注 |
|------|-----|------|----------|---------------|-------|
| zp-alloc-hot | 是 | 是 | **是** | 警告 | ~**1.4×** GPA 对比 arena — 温和；保持警告 |
| zp-append-without-reserve | 是 | 是 | **是** | 信息 | ~**2.1×** 添加保留 |
| zp-page-allocator-small | 是 | 是 | **是** | 警告 | ~**341×** 页面 vs GPA — **候选错误** |
| zp-debug-allocator | 是 | 是 | **不适用** | 警告 | 仅限静态（模式切换） |
| zp-large-struct-by-value | 是 | 是 | **不确定** | 信息 | ReleaseFast 省略的微基准 |
| zp-print-hot | 是 | 是 | **是** | 警告 | ~**6e4×** 打印对比静默 — 环境输入/输出，不升级 |
| zp-unbuffered-io | 是 | 是 | **是** | 警告 | ~**49×** 空与 4KiB — **候选错误** |
| zp-missing-free | 是 | 是 | **不适用** | 警告 | 正确性（泄漏） |
| zp-extern-struct-padding | 是 | 是 | **是** | 警告 | ~**1.2×** 填充步幅 — 适中 |
| zp-broad-runtime-safety | 是 | 是 | **待定** | 警告 | 需要 ReleaseSafe 措施 |
| zp-可打包布尔值 | 是 | 是 | **待定** | 信息 | 密度 |
| zp-usize-index-field | 是 | 是 | **待定** | 信息 | 密度 |
| zp-aos-single-field | 是 | 是 | **是** | 提示 | ~**6.6×** AoS 对 SoA |
| zp-catch-unreachable-alloc | 是 | 是 | **不适用** | 警告 | 正确性（未定义行为） |
| zp-oversized-enum-tag | 是 | 是 | **不适用** | 信息 | 静态大小/ABI |
| zp-可选标量字段 | 是 | 是 | **待定** | 信息 | 密度 |
| zp-布尔数组 | 是 | 是 | **是** | 信息 | ~**30×** 布尔数组 vs 位集 |
| zp-静态字符串映射 | 是 | 是 | **是** | 信息 | ~**2.5×** 静态字符串映射 |
| zp-runtime-div-hot | 是 | 是 | **是** | 提示 | ~**12×** 模与掩码
| zp-queue-ordered-remove | 是 | 是 | **是** | 警告 | ~**466×** orderedRemove 与 ring — **候选错误** |
| zp-读取时移动 | 是 | 是 | **是** | 警告 | ~**17×** copyForwards 与 cursor — **潜在错误** |
| zp-per-packet-alloc | 是 | 是 | **是**（共享 zp-alloc-hot） | 警告 | 热路径分配；相同 ~1.4× |
| zp-不变浮点除法 | 是 | 是 | **是** | 提示 | ~**2.0×** 浮点除法 vs 倒数 |
| zp-map-put-without-ensure | 是 | 是 | **是** | 信息 | ~**2.8×** 映射确保 |
| zp-catch-unreachable-io | 是 | 是 | **不适用** | 警告 | 正确性 |
| zp-arena-reset-free-all | 是 | 是 | **是** | 警告 | ~**3.2×** free_all 对比 retain |
| zp-create-destroy-hot | 是 | 是 | **是** | 警告 | ~**11×** 创建/销毁 vs 池 — **潜在错误** |
| zp-fixed-size-alloc-hot | 是 | 是 | **是** | 警告 | ~**8.5×** 固定分配 vs 池 — **候选错误** |

---

## jvmperf (jp-boxed-primitive-collection–jp-non-static-field-updater) — 摘要

ID 是 **jvmperf** `jp-*` 标识，而不是 jsperf。示例：大多是 `bad/<slug>.*` + 匹配的 `good/`；某些集合/装箱规则仅限 Kotlin；jp-boxed-stream / jp-non-static-field-updater 仅限 Java。**vt-unsafe-threadlocal-pool** 仅为指导，在 `jvmperf-lint/fixtures/guide/` 下（不随包发布）。

| 规则 | 不良设备 | 良好 / 消极 | 证据 md+jsonl | 严重性 默认 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| jp-boxed-primitive-collection | 是（java+kt） | 是 | **是** | **错误** | ~5.96× STATIC-VS-HOTSPOT |
| jp-string-concat-hot | 是 (java+kt) | 是 | **是** | **错误** | J23 ~14.2× |
| jp-regex-hot | 是 (java+kt) | 是 | **是** | 提示 | J26 ~1.36× |
| jp-format-hot | 是（Java+KT） | 是 | **是** | **错误** | 约17× |
| jp-unpresized-collection | 是 (java+kt) | 是 | **是** | 提示 | 部分 ~1.6× |
| jp-boxed-stream | 是（Java） | 是 | **是** | **错误** | J32 ~149× |
| jp-exception-control-flow | 是（Java+KT） | 是 | **是** | **错误** | J32 ~64× |
| jp-legacy-synchronized-type (**已移除**) | 是 (java+kt，已归档) | 是 | **是** (~1.08×) | — | 测量无胜利；墓碑 `_removed/` |
| jp-多个布尔字段 (**已移除**) | 是 (java+kt，已归档) | 是 | **是** (1.0×) | — | COH 无占用优势；墓碑 `_removed/` |
| cx-sstream-in-loop (**已移除**) | 已归档 | 已归档 | -O2 下 1.24× | — | 字符串流重用；墓碑 |
| pp-regex-compile-in-loop (**已移除**) | 已存档 | 已存档 | 小于 3× | — | CPython 缓存 `re.compile`; 墓碑 |
| rs-map-new-in-loop | `bad/rs-map-new-in-loop_map_loop.rs` | 是 | **是** | 提示 | 两次安静的 rustc 1.99 运行大约 1.51× 和 1.53×；已恢复 |
| pp-datetime-format-in-loop (**已删除**) | 已归档 | 已归档 | 不提升 | — | 更改输入无法跳过调用 |
| gp-time-parse-in-loop (**已删除**) | 已归档 | 已归档 | 不提升 | — | 输入更改无法跳过调用 |
| rb-date-parse-in-loop (**已删除**) | 已归档 | 已归档 | 不提升 | — | 更改输入无法跳过调用 |
| jp-enum-key-hash-collection | 是 (java+kt) | 是 | **是** | **错误** | EnumMap ~2.1× |
| jp-collection-chain | 是 (kt) | 是 | **是** | **错误** | JDK 27 / Kotlin 2.4.21 ~265× |
| jp-value-class-boxing | 是 (kt) | 是 | **是** | **错误** | JDK 27 ~4.0× 时间，~5× B/操作 |
| jp-lambda-to-non-inline-hot | 是 (kt) | 是 | **是** | **错误** | JDK 27 分配 ~244×；时间 ~0.47× |
| jp-lazy-default-mode | 是 (kt) | 是 | 仅 md 存根 | 提示 | 待定 — 情境懒加载 |
| jp-data-copy-hot | 是 (kt) | 是 | **是** | **错误** | JDK 27 ~208× 时间，分配仍然 ~10001× |
| jp-android-sparse-array | 是 | 是 | md 桩 | 提示 | 待定 ART |
| jp-log-hot | 是 | 是 | **是** | **错误** | J32 ~28×（调试关闭） |
| jp-sleep-polling | 是 | 是 | md 存根 | 提示 | 待定的睡眠设计 |
| jp-finalize | 是 | 是 | md stub | 提示 | 待完成/Cleaner |
| jp-expensive-alloc-hot | 是 | 是 | **是** | 提示 | 负 tiny-pool |
| jp-热-重-分配–jp-用户界面-文本-追加 | 是 | 是 | 中等存根 | 提示 | 待定 ART/设备 |
| jp-baos-tobytearray-copy | 是 | 是 | **是** | **错误** | J32 ~12.8× |
| jp-热负载复制 | 是 | 是 | **是** | **错误** | J32 ~15.8× |
| vt-unsafe-threadlocal-pool | 仅作指南 | 指南 | **md 存根** ([vt-unsafe-threadlocal-pool.md](../../packages/jvmperf/evidence/zh-CN/vt-unsafe-threadlocal-pool.md)) | — | 未发布 / 先指南 |
| jp-client-factory-recreate | 是 | 是 | **是** | **错误** | J32 HttpClient ~5e5× |
| jp-string-intern-hot | 是 | 是 | **是** | **错误** | J32 intern ~6.6× |
| jp-non-static-field-updater | 是 (Java) | 是 | **是** | 提示 | 创建 ~165×；增加 ~1.0× |

今天的 CLI 仍可能在任何发现上失败；策略严重性是保持/升级合同，直到预设到位。

---



---


**脚手架证据合同:** 在 JSONL 存在之前，每条脚手架规则必须有一个命名的待处理存根 `packages/<kit>/evidence/<ID>.md`（不仅仅是一个文件夹的 README）。这满足了注册表的一致性，而无需发明比例。

## goperf (gp-make-hot–gp-defer-hot) — 语料库就绪

| 规则 | 坏的装置 | 好的装置 | 证据 | 默认 | 备注 |
|------|-------------|--------------|----------|---------|-------|
| gp-make-hot | `bad/gp-make-hot_make_loop.go` | 是 | **是** | **关** | G4 ~265× make-each；保持关闭（G3 可用成语） |
| gp-string-plus-hot | `bad/gp-string-plus-hot_string_plus.go` | 是 | **是** | **关闭** | G4 ~2919× += 与 Builder；保持关闭 |
| gp-fmt-hot | `bad/gp-fmt-hot_fmt_loop.go` | 是 | **是** | **关闭** | G4 ~1.8–2.8× fmt 对比 strconv；保持关闭 |
| gp-append-nil-slice | `bad/gp-append-nil-slice_append_grow.go` | `good/gp-append-nil-slice_presize.go` | **是** | 提示 | G4 ~12.2× append 增长 vs 预设大小 |
| gp-defer-hot | `bad/gp-defer-hot_defer_loop.go` | `good/gp-defer-hot_close_each.go` + 闭包 | **是** | 提示 | G4 ~33× 循环中的 defer 与 每次关闭 |
| gp-regexp-compile-hot | `bad/gp-regexp-compile-hot_compile_loop.go` | `good/gp-regexp-compile-hot_compile_once.go` | jsonl | 提示 | 微基准 ~7.1× 对一个形状；保留提示；未经过语料库分流 |
| gp-json-marshal-hot | `bad/gp-json-marshal-hot_marshal_loop.go` | `good/gp-json-marshal-hot_marshal_once.go` | jsonl | 提示 | 微基准测试在一个形状上大约快 368.4 倍；保留提示；未经过语料库筛选 |
| gp-reflect-hot | `bad/gp-reflect-hot_reflect_loop.go` | `good/gp-reflect-hot_reflect_once.go` | jsonl | 提示 | 微基准 ~1×，无实际开销；保持提示 |


## pyperf（pp-str-plus-hot–pp-print-hot）——语料库准备就绪

| 规则 | 坏的装置 | 好的装置 | 证据 | 默认 | 备注 |
|------|-------------|--------------|----------|---------|-------|
| pp-str-plus-hot | `bad/pp-str-plus-hot_str_plus.py` | 是 | **是** | **关闭** | G4 ~5.5× += 与 join；保持关闭 |
| pp-list-plus-rebind | `bad/pp-list-plus-rebind_list_plus.py` | 是 | **是** | 提示 | G4 ~1117× list+ 重新绑定；保持提示 |
| pp-print-hot | `bad/pp-print-hot_print_loop.py` | 是 | **是** | **关闭** | G4 ~3.4× 打印循环；保持关闭 |
| pp-json-hot | `bad/pp-json-hot_json_loop.py` | `good/pp-json-hot_json_once.py` | jsonl | 提示 | 微基准约81.6×在一个形状上；保持提示；未经过语料库筛选 |
| pp-deepcopy-hot | `bad/pp-deepcopy-hot_deepcopy_loop.py` | `good/pp-deepcopy-hot_deepcopy_once.py` | jsonl | 提示 | 微基准测试在一个形状上约快 21.8×；保留提示；未按语料库分类 |
| *(已移除 — 无标识)* 循环中重新临时处理 | `bad/pp004_re_adhoc.py`（已归档） | `good/pp004_re_compiled.py` | **是** | — | 墓碑；G4 ~1.35× / 热启动可能会逆转 |


## swiftperf (sp-force-unwrap-in-loop–sp-map-joined-chain) — 语料库就绪

| ID | 坏的装置 | 好的 | 证据 | 默认 | 备注 |
|----|-------------|------|----------|---------|-------|
| sp-force-unwrap-in-loop | force_loop | 是 | **已阻止** | **关闭** | G4 阻止 — Linux 上没有 `swiftc` |
| sp-string-plus-in-loop | string_plus | 是 | **已阻止** | **关闭** | G4 已阻止 — 无 Swift 工具链 |
| sp-print-hot | 打印循环 | 是 | **阻止** | **关闭** | G4 阻止 — 无 Swift 工具链 |
| sp-array-no-reserve | append_no_reserve | 是 | **阻塞** | 提示 | G4 阻塞 — 无 Swift 工具链 |
| sp-map-joined-chain | map_joined | 是 | **阻塞** | 提示 | G4 阻塞 — 无 Swift 工具链 |
| sp-dateformatter-hot | `sp-dateformatter-hot_formatter_loop.swift` | 是 | jsonl | 提示 | 微基准测试 ~29.8× 在一个形状上；保持提示；未进行语料库筛选 |
| sp-json-decode-hot | `sp-json-decode-hot_decode_loop.swift` | 是 | jsonl | 提示 | 微基准 ~1958.0× 在一个形状上；保持提示；未经过语料库分类 |
| sp-regex-hot | `sp-regex-hot_regex_loop.swift` | 是 | jsonl | 提示 | 微基准测试 ~16.4× 单一形状；保持提示；未经过语料库分类 |

r4 n=32 TP 65.6% FP+DOC+SKIP 0% → **语料库准备好：是**（文本检查回退；当 Swift 存在时使用 SPM）。G4 2026-10-22：**阻止**（没有假 JSONL）。2026-10-23 的三个提示不在该裁定范围内。


## arktsperf（在 at-alloc-hot–在 at-json-hot）—— 语料库准备就绪

| 编号 | 不良装置 | 良好 | 证据 | 默认 | 注意事项 |
|----|-------------|------|----------|---------|-------|
| at-alloc-hot | new_loop | 是 | **是**（节点代理） | **关闭** | G4 ~33× 新建与重用；保持关闭 |
| at-object-delete | 删除 | 是 | **是**（不确定） | **关闭** | G4 ~1.0×（填充主导）；孤立删除适中；保持关闭 |
| at-console-hot | console_loop | 是 | **是**（节点代理） | **关闭** | G4 ~208×；保持关闭 |
| at-includes-hot | includes_loop | 是 (+ `at-includes-hot_string_lut`) | **是** (节点代理) | 提示 | G4 ~29× includes→Set; String.indexOf→LUT (Map~1×); 保持提示 |
| at-json-hot | json_loop | 是 | **是**（节点代理） | 提示 | G4 ~2.2× 解析 / ~1.7× 字符串化；保持提示 |

r3 n=56 TP 66.1% FP+DOC+SKIP 0% → **语料准备就绪：是**。G4 是 **Node/V8 代理**，不是 ArkTS VM — 不会升级为错误。


## cppperf（`cx-string-append-unreserved`）— 语料库就绪

活动规则：**cx-string-append-unreserved**（默认 **提示**）。Vector-push / iostream / `.at()` 规则 **已移除**（墓碑）。专用 C++17（≠ cperf）。

| 规则 | 错误夹具 | 良好 / 负面 | 证据 md+jsonl | 默认严重性 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| *(已移除 — 无标识)* 向量在未保留空间的情况下推入 | `bad/cx001_push_loop.cpp`（已存档） | 是 | **是** | — | 墓碑；G4 ~1.58× @-O2 |
| cx-string-append-unreserved | `bad/cx-string-append-unreserved_string_plus.cpp` | 是的 (`cx-string-append-unreserved_append_reserve.cpp`) | **是的** | **提示** | G4 ~1.09× 字符 @-O2; 块 ~1.8×; 保持提示 |
| cx-regex-ctor-hot | `bad/cx-regex-ctor-hot_regex_loop.cpp` | `good/cx-regex-ctor-hot_regex_once.cpp` | jsonl | **提示** | 微基准 ~1.55×，小；保持提示 |
| cx-endl-hot | `bad/cx-endl-hot_endl_loop.cpp` | `good/cx-endl-hot_newline.cpp` | jsonl | **提示** | 微基准 ~1×，无明显成本；保持提示 |
| *(已移除 — 无标识)* 循环中的 iostream | `bad/cx003_iostream_loop.cpp`（已存档） | 是 | **是** | — | 墓碑；G4 ~1.01× |
| *(已移除 — 无标识)* `.at()` 在循环中 | `bad/cx004_at_loop.cpp`（已存档） | 是 | **是** | — | 墓碑；G4 ~0.85× 反向 @-O2 |

---

## csharpperf (cs-list-add-no-capacity–cs-regex-hot) — 语料库就绪

cs-list-add-no-capacity–cs-console-hot 默认 **关闭**，G3 后。**cs-regex-hot** 默认 **提示**。G4 在 .NET 8.0.426（2026-10-22）；**无严重性升级**。

| 规则 | 不良设备 | 良好 / 消极 | 证据 md+jsonl | 默认严重性 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| cs-list-add-no-capacity | `bad/cs-list-add-no-capacity_add_loop.cs` | 是 (`cs-list-add-no-capacity_capacity.cs`) | **是** | **关闭** | G4 ~13× 列表容量；保持关闭 |
| cs-string-plus-hot | `bad/cs-string-plus-hot_string_plus.cs` | 是 (`cs-string-plus-hot_builder.cs`) | **是** | **关** | G4 ~3758× string+=；保持关闭 |
| cs-console-hot | `bad/cs-console-hot_console_loop.cs` | 是 (`cs-console-hot_console_outside.cs`) | **是** | **关闭** | G4 ~6× 控制台为空；保持关闭 |
| cs-regex-hot | `bad/cs-regex-hot_regex_loop.cs` | 是 (`cs-regex-hot_compiled_regex.cs`) | **是** | **提示** | G4 ~2.6× IsMatch 对比 Compiled；保持提示 |
| cs-linq-materialize-hot | `bad/cs-linq-materialize-hot_tolist_loop.cs` | `good/cs-linq-materialize-hot_tolist_once.cs` | jsonl | 提示 | .NET 10 ~38.9× 在一个形状上；保持提示；非语料库三角化 |
| cs-format-hot | `bad/cs-format-hot_format_loop.cs` | `good/cs-format-hot_format_once.cs` | jsonl | 提示 | .NET 10 ~5.0× 在一个形状上；保持提示；非语料库分类 |

---

## phpperf (ph-string-dot-hot–ph-echo-hot) — 语料库就绪

ph-array-merge-rebind 默认 **错误**，在 G4 之后（`ph-array-merge-rebind.md`+`jsonl`）。ph-string-dot-hot 默认 **关闭**（G3 OK-惯用语重）和 ph-echo-hot **提示**；两者都有测量的 JSONL。

| 规则 | 不良设备 | 良好 / 消极 | 证据 md+jsonl | 严重性 默认 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| ph-string-dot-hot | `bad/ph-string-dot-hot_str_dot.php` | 是（`ph-string-dot-hot_implode.php`） | **是** | **关闭** | G4 ~3.3× .= 与 implode 对比；保持关闭 |
| ph-array-merge-rebind | `bad/ph-array-merge-rebind_array_merge.php` | 是 (`ph-array-merge-rebind_push.php`) | **是** | **错误** | array_merge 重新绑定；G4 2026-10-22 |
| ph-echo-hot | `bad/ph-echo-hot_echo_loop.php` | 是 (`ph-echo-hot_echo_outside.php`) | **是** | 提示 | G4 ~4.4× 每次回显；保持提示 |

---

## rubyperf (rb-string-plus-hot–rb-file-read-hot) — 语料库准备就绪

rb-string-plus-hot–rb-puts-hot 在 G3 之后默认 **关闭**。**rb-hash-merge-in-loop** 已于 2026-10-23 删除：字面量构建比 `merge` 更慢，并且分配更多。

| 规则 | 错误夹具 | 良好 / 负面 | 证据 md+jsonl | 默认严重性 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| rb-string-plus-hot | `bad/rb-string-plus-hot_str_plus.rb` | 是 | **是** | **关** | G4 ~32× += 与 <<; 保持关闭 |
| rb-array-plus-rebind | `bad/rb-array-plus-rebind_array_plus.rb` | 是 | **是** | **关闭** | G4 ~181× array+ 重新绑定；保持关闭 |
| rb-puts-hot | `bad/rb-puts-hot_puts_loop.rb` | 是 | **是** | **关** | G4 ~5.1× 每次 puts；保持关闭 |
| rb-hash-merge-in-loop (**已移除**) | 已归档 | 已归档 | 墓碑 | — | Ruby 4.0.8 直接量比 merge 慢 (~0.78×) 且对象数量约为 2× |
| rb-regexp-new-hot | `bad/rb-regexp-new-hot_regexp_loop.rb` | `good/rb-regexp-new-hot_regexp_once.rb` | jsonl | 提示 | 微基准测试在一个形状上大约快 7.7 倍；保留提示；未经过语料库筛选 |
| rb-json-hot | `bad/rb-json-hot_json_loop.rb` | `good/rb-json-hot_json_once.rb` | jsonl | 提示 | 微基准约10.5×在一个形状上；保持提示；未经过语料库筛选 |

## rustperf (rs-alloc-hot–rs-collect-vec-hot) — 语料库准备就绪 (r4)

rs-vec-no-capacity/rs-collect-vec-hot 重新设计 2026-10-22。r4 clap 残差 **6×TP** / FP+DOC+SKIP **0%** → **语料库就绪：是**。rs-format-rebind-hot `format!` 重新绑定 → **错误** (~99×)；rs-string-plus-in-loop/rs-vec-no-capacity/rs-collect-vec-hot → **提示**；rs-alloc-hot → **关闭**（G4 测量，保持关闭）；rs-println-hot → **提示**（已测量）。

| 规则 | 错误设置 | 良好 / 负面 | 证据 md+jsonl | 默认严重性 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| rs-alloc-hot | `bad/rs-alloc-hot_clone_loop.rs` | 是 (`rs-alloc-hot_with_capacity.rs`) | **是** | **关闭** | 分配/克隆；G4 ~2.7× Vec / ~1.1× 克隆 — 保持关闭 |
| rs-string-plus-in-loop | `bad/rs-string-plus-in-loop_string_plus.rs` | 是 (`rs-string-plus-in-loop_write.rs`, `rs-string-plus-in-loop_tiny_sep.rs`) | **是** | 提示 | 仅 `+=` / `push_str`；约 1× 均摊
| rs-println-hot | `bad/rs-println-hot_println_loop.rs` | 是 (`rs-println-hot_println_outside.rs`) | **是** | 提示 | G4 ~12.6× 每次写入与缓冲区; 保持提示 |
| rs-format-rebind-hot | `bad/rs-format-rebind-hot_format_rebind.rs` | 是 (`rs-format-rebind-hot_write.rs`, `rs-format-rebind-hot_let_format.rs`, `rs-format-rebind-hot_brace_wrap.rs`) | **是**（别名 G4） | **错误** | `format!` 重绑定重用；约 99× 对比 `write!` |
| rs-vec-no-capacity | `bad/rs-vec-no-capacity_vec_new_push.rs` | 是的（`rs-vec-no-capacity_with_capacity.rs`, `rs-vec-no-capacity_cfg_test.rs`） | **是的** | 提示 | G4 ~1.0× 大 / ~2.1× 小 构建器；保持提示 |
| rs-collect-vec-hot | `bad/rs-collect-vec-hot_collect_in_loop.rs` | 是（`rs-collect-vec-hot_count_no_collect.rs`） | **是** | 提示 | G4 ~1.8× collect 对比 count；保持提示 |
| rs-regex-new-hot | `bad/rs-regex-new-hot_regex_loop.rs` | `good/rs-regex-new-hot_regex_once.rs` | 仅限 md | 提示 | 待处理措施；未进行语料库分类 |

---

## kotlinperf (kt-list-add-hot–kt-println-hot) — 语料库就绪

kt-list-add-hot–kt-println-hot 默认 **关闭**（G3 OK-习语）。空集合添加规则 **已移除**（墓碑）。G4 运行在 kotlinc 2.0.21 / JRE 21（2026-10-22）；kit-local `kt-*` ≠ jvmperf JMH。**无升级**。

| 规则 | 不良设备 | 良好 / 消极 | 证据 md+jsonl | 默认严重性 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| kt-list-add-hot | `bad/kt-list-add-hot_list_loop.kt` | 是 (`kt-list-add-hot_capacity.kt`) | **是** | **关闭** | G4 ~2.1× 空 vs 容量 @2e6；保持关闭 |
| kt-string-plus-hot | `bad/kt-string-plus-hot_string_plus.kt` | 是的 (`kt-string-plus-hot_buildString.kt`) | **是的** | **关闭** | G4 ~1170× += 与 buildString；保持关闭 |
| kt-println-hot | `bad/kt-println-hot_println_loop.kt` | 是的 (`kt-println-hot_println_outside.kt`) | **是** | **关闭** | G4 约 99 次 println；保持关闭 |
| *(已移除 — 无标识)* 空列表 + 添加 | `bad/kt004_empty_add.kt`（已存档） | 是 | **是**（不确定） | — | 墓碑；G4 ~0.84–1.26× |

---

## objcperf (oc-nsstring-append-hot–oc-nslog-hot) — 语料库准备就绪

激活：oc-nsstring-append-hot / oc-nslog-hot（默认 **关闭**）。日期格式化器、JSON 和正则表达式规则是 **提示**，不属于 2026-10-22 语料库裁定的一部分。数组添加规则 **已移除**（墓碑）。G4 在 **GNUstep**（非 Apple 运行时） 2026-10-22。与 swiftperf 区别。**不升级**。

| 规则 | 错误设置 | 良好 / 负面 | 证据 md+jsonl | 默认严重性 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| *(已移除 — 无标识)* NSMutableArray 添加 | `bad/oc001_add_loop.m`（存档） | 是 | **是**（gnustep-proxy） | — | 墓碑；G4 ~1.18× / dive ~1× |
| oc-nsstring-append-hot | `bad/oc-nsstring-append-hot_append_loop.m` | 是 (`oc-nsstring-append-hot_mutable.m`) | **是** (gnustep) | **关闭** | G4 ~569× 拼接；保持关闭 |
| oc-nslog-hot | `bad/oc-nslog-hot_nslog_loop.m` | 是 (`oc-nslog-hot_nslog_outside.m`) | **是** (fprintf 代理) | **关闭** | G4 ~191×；保持关闭 |
| oc-dateformatter-hot | `bad/oc-dateformatter-hot_alloc_loop.m` | 是 | jsonl | 提示 | 微基准 ~30.4× 在一个形状上；保持提示；未经过语料库整理 |
| oc-json-hot | `bad/oc-json-hot_json_loop.m` | 是 | jsonl | 提示 | 微基准测试 ~15.8× 单一形状；保持提示；未经过语料库筛选 |
| oc-regex-hot | `bad/oc-regex-hot_regex_loop.m` | 是 | jsonl | 提示 | 微基准 ~14.9× 在一个形状上；保持提示；未经过语料库筛选 |
| *(已移除 — 无标识)* 空数组 + 添加 | `bad/oc004_empty_add.m`（已存档） | 是 | **是**（gnustep-proxy） | — | 墓碑；G4 ~1.18× / dive ~1× |

---

## dartperf（dt-list-add-empty–dt-growable-add-empty）—— 语料库准备就绪

dt-list-add-empty–dt-print-hot 默认 **关闭**。**dt-growable-add-empty** 默认 **提示**。Dart 3.13.6 上的 G4（2026-10-22）。**无升级**。

| 规则 | 不良设备 | 良好 / 消极 | 证据 md+jsonl | 默认严重性 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| dt-list-add-empty | `bad/dt-list-add-empty_add_loop.dart` | 是的 (`dt-list-add-empty_filled.dart`) | **是** | **关闭** | G4 ~3.1× 填充与空添加；保持关闭 |
| dt-string-plus-hot | `bad/dt-string-plus-hot_string_plus.dart` | 是 (`dt-string-plus-hot_buffer.dart`) | **是** | **关闭** | G4 ~247× 字符串+；保持关闭 |
| dt-print-hot | `bad/dt-print-hot_print_loop.dart` | 是的 (`dt-print-hot_print_outside.dart`) | **是的** | **关闭** | G4 ~128× 写入；保持关闭 |
| dt-growable-add-empty | `bad/dt-growable-add-empty_empty_add.dart` | 是 (`dt-growable-add-empty_filled.dart`) | **是** | **提示** | G4 ~2.4×; 保持提示 |

---

## luaperf（lu-table-insert-hot–lu-print-hot）—— 语料库准备就绪

lu-table-insert-hot 默认 **关闭**（G3 OK-习语）。lu-string-concat-hot 默认 **错误**，在 G4 之后（`lu-string-concat-hot.md` + `jsonl`）。lu-print-hot G4 有证据；默认保持 **提示**（依赖 I/O 环境）。

| 规则 | 错误夹具 | 良好 / 负面 | 证据 md+jsonl | 默认严重性 | 备注 |
|------|-------------|-----------------|-------------------|------------------|-------|
| lu-table-insert-hot | `bad/lu-table-insert-hot_insert_loop.lua` | 是（`lu-table-insert-hot_index.lua`） | **是** | **关闭** | G4 ~4.7× 插入 vs 索引；保持关闭 |
| lu-string-concat-hot | `bad/lu-string-concat-hot_concat_loop.lua` | 是 (`lu-string-concat-hot_concat.lua`) | **是** | **错误** | string ..; G4 2026-10-22 |
| lu-print-hot | `bad/lu-print-hot_print_loop.lua` | 是 (`lu-print-hot_print_outside.lua`) | **是** | 提示 | 循环中打印；G4 2026-10-22 保持提示 |

---

## beamperf（be-list-concat-reduce–be-enum-map-filter-chain）— 语料库准备就绪

| 编号 | 不良装置 | 良好 | 证据 | 默认 | 注意事项 |
|----|-------------|------|----------|---------|-------|
| be-list-concat-reduce | `bad/be-list-concat-reduce_list_plus.exs` (+ `.erl`) | 是 | **是** | 提示 | G4 ~453× ++ 与 cons；保持提示 |
| *(已移除 — 无标识)* `<>` 字符串追加 | `bad/be002_string_append.exs`（已存档） | 是 | **是**（混合） | — | 墓碑；chunk<>获胜；tiny/digits可能反转 |
| be-io-puts-hot | `bad/be-io-puts-hot_io_loop.exs` | 是 | **是** | **关** | G4 ~3810× IO.puts；保持关闭 |
| be-map-merge-hot | `bad/be-map-merge-hot_merge_in_loop.exs` | 是 | **是** | 提示 | G4 ~6.9× Map.merge 对比 put；KW ~2×；保持提示 |
| be-enum-map-filter-chain | `bad/be-enum-map-filter-chain_enum_chain.exs` | 是 | **是** | 提示 | G4 ~4.5× map|>filter 一次传递；保持提示 |

r3 n=4 TP 75% FP+DOC+SKIP 0% → **语料库准备好：是**。G4 be-list-concat-reduce–be-enum-map-filter-chain 在 OTP 27 / Elixir 1.18（2026-10-22）上；无需升级。


## nimperf (nm-seq-add-hot–nm-seq-no-capacity) — 语料库就绪

| 规则 | 坏设备 | 好设备 | 证据 | 默认 | 备注 |
|------|-------------|--------------|----------|---------|-------|
| nm-seq-add-hot | `bad/nm-seq-add-hot_add_loop.nim` | 是 | 待定 | **关闭** | G3 OK-惯用法；**G4 阻塞** — Debian apt 中没有 `nim` |
| nm-string-amp-in-loop (**已移除**) | 已存档 | 已存档 | 墓碑 | — | Nim 2.2.12 `join` 比 `&=` 慢 (~0.79×，之前 ~0.69×) |
| nm-echo-hot | `bad/nm-echo-hot_echo_loop.nim` | 是 | 待定 | **关闭** | G4 阻止（没有 nim 工具链） |
| nm-seq-no-capacity | `bad/nm-seq-no-capacity_empty_add.nim` | `good/nm-seq-no-capacity_ofcap.nim` | 待处理 | 提示 | G4 阻塞（没有 Nim 工具链） |


## 批次备注

**批次 B G4 (2026-10-22)：** arkts Node-proxy JSONL；测量了 beam/csharp/dart/kotlin；objc **GNUstep**（非 Apple）；swift **被阻止**（无 swiftc）。默认设置未更改——本轮不升级为 `error`。

## 诚实指出的差距

**磁盘审计 2026-10-21 ~19:31 亚洲/上海** — 每个跳过 / 待定 / 不适用 / 不确定的规则现在都有一个命名为 `evidence/<ID>.md` 的存根（没有编造的 JSONL）。

1. **cperf**:差 + 好 + `证据/cp-*.{ md,jsonl}` 适用于已发运的规则——**完成**.
2. **jsperf**:差 + 好 + `证据/jp-*.{md,jsonl}`}` 运规则——**完成**.
3. **zperf**:所有现行规则的配对固定装置。 测量过的JSONL + 登记根(待付/N/A/未结)——见`packages/zperf/docs/evidence-policy.md'和`packages/zperf/evidence/'。
4. **jvmperf固定装置**:运出`jp-*`bad+good(朗镜)'。 **vt-不安全线上本地池** 指南仅载于`固定/指南/' + [`vt-不安全线上本地池.md'] (./packages/jvmperf/证据/vt-不安全线上本地池.md)——未发运。
5. **jvmperf证据**:为运出的带有数字的规则测量误差/差错;**为ART/device和情况规则花根**。 见`packages/jvmperf/docs/evidence-policy.md'。
6. ** 尚待执行的措施**(诚实——需要利用/env):zperf密度/安全根;jvm Android ART设备规则。
7. ** Naming**:c/js好固定装置是描述性的——测试表明套间清洁性,而不是一个文件-每个规则。
8. ** 不** 将实体堆放或剥离/汇编线计数视为*含义*的回归。

## 跨语言检查（2026-10-23）

在其他可运行的工具链上，对已经在 C 或 C++ 中有成本的文件打开和时钟采样形状进行了计时。仅当比率很大且标准库有可重用的句柄或可以放在循环外的样本时，才添加提示。变化的路径无法提升。需要新的时间戳的循环没有可以提升的内容。默认情况下保持提示。

已检查且未添加：

| 形状 | 比例 | 为什么没有圆珠 |
| --- | ---: | --- |
| Python `time.perf_counter_ns` | 2.866 | 循环旁的小 |
| Ruby `Process.clock_gettime` | 2.332 | 循环旁的小项 |
| Python `getattr` | 1.442 | 无明显成本 |
| Ruby `send` | 1.938 | 没有明显成本 |
| JavaScript `Reflect.get` | 8.168 | 几个纳秒；不是 Go 的 `FieldByName` 形式 |

名称查找确实达到了标准，提示：C# `GetField` 加上 `GetValue` 在 .NET 10 上大约比直接访问字段慢 53 倍（`cs-field-by-name-hot`；缓存的 `FieldInfo.GetValue` 仍约慢 42 倍），Objective-C `valueForKey:` 大约慢 124 倍（`oc-value-for-key-hot`），Swift `value(forKey:)` 大约慢 35 倍（`sp-value-for-key-hot`）。

Zig 0.17 的 `Io.Dir.openFileAbsolute` 大约是 2134×，`Io.Clock.awake.now` 大约是 42×；两者都是带 JSONL 的提示。Zig 对一个不变对象的 `json.parseFromSlice` 大约是 2683×，而解析一次（`zp-json-hot` 提示）则比较。第一次 Swift `Date()` 运行和第一次 Objective-C `NSDate` 运行被丢弃，因为编译器移除了循环后的结果。重新运行并保留结果大约是 244× 和 769×，这两个提示现在都有 JSONL。

没有标准库对象，因此没有 slug 和没有数字：C、C++ 和 Rust 的标准库中没有 JSON 解析器。Zig 0.17 的标准库中没有正则表达式编译器。

未在此主机上测量，因此没有数值，也没有新的标识：JVM 和 Kotlin（无 JDK / kotlinc）、PHP、Dart、Lua、Nim、Elixir、ArkTS（不要复制 Node 数字）。
