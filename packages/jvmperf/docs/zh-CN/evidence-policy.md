# jvmperf 证据政策

## 门槛

只有当以下两者都存在于 `packages/jvmperf/evidence/` 下时，JP 规则才可以被记录/处理为 **`error`**（保留/升级合同以供指南和未来的 `--preset` 使用）:

1. `<RULE>.md` — 声明、利用，**JDK 版本 + JVM 参数**（使用时包括 `-XX:+UseCompactObjectHeaders`），限制
2. `<RULE>.jsonl` — ≥1 个前/后测量对，字段包括 `rule`、`case`、`role`（`before` = 问题，`after` = 修复）、`jdk`、`jvm_args`、`ns_per_op`（或 `median_ms` / `total_size_bytes`）、`alloc_b_per_op`、`ratio`、`ts`

否则该规则保持 **`hint`** 或 **`off`**（一个审核提示）：适用于内部测试和固定装置，但不是“必须为速度修复”的信号。

CLI 仍然可能在任何发现时 **以非零退出**（除非使用 `--no-fail`）；打印的严重性标签遵循此策略表。完整的 `--preset` 配置稍后可选（镜像 jsperf/cperf）。

## 相关兄弟

- 实时时钟 / 每操作字节协议：`scripts/run-static-vs-hotspot.sh`（写入 `research/benches/static-vs-hotspot.{json,jsonl}`）

**不要**因为 PrintCompilation / compilation-log 的行数看起来吓人就升级——那些只是噪音（和 V8 `--trace-deopt` 计数的道理一样）。

## 当前映射

截至 2026-10-22（亚洲/上海）；基准测试在 JDK 25.0.4.1 + COH 上进行。策略是 `Rule.java` 中每条规则的默认严重性。

| 规则 | 政策 | 证据 | 关联 / 注释 |
|------|--------|----------|------------------|
| **jp-boxed-primitive-collection** | **关闭** | [jp-boxed-primitive-collection](../../evidence/zh-CN/jp-boxed-primitive-collection.md) | JDK 27 n=1e6 ~**1.32×**, n=1e5 ~**7.37×**; 静默 JDK 21 ~**11×** / ~**8.5×** |
| **jp-string-concat-hot** | **错误** | [jp-string-concat-hot](../../evidence/zh-CN/jp-string-concat-hot.md) | JDK 27 J23 部件=256 ~**21.3×** |
| jp-regex-hot | **关闭** | [jp-regex-hot](../../evidence/zh-CN/jp-regex-hot.md) | JDK 27 时间 ~**0.76×**，分配 ~**2.4×**；安静 JDK 21 时间 ~**1.67×** |
| **jp-format-hot** | **关闭** | [jp-format-hot](../../evidence/zh-CN/jp-format-hot.md) | JDK 27 ~**29×** |
| jp-unpresized-collection | **关闭** | [jp-unpresized-collection](../../evidence/zh-CN/jp-unpresized-collection.md) | JDK 27 n=10k ~**1.43×** |
| **jp-boxed-stream** | **错误** | [jp-boxed-stream](../../evidence/zh-CN/jp-boxed-stream.md) | JDK 27 boxedReduce/mapToInt ~**37×** |
| **jp-exception-control-flow** | **关闭** | [jp-exception-control-flow](../../evidence/zh-CN/jp-exception-control-flow.md) | JDK 27 ~**4.0×**（峰值）；静默 JDK 21 ~**27×** |
| jp-legacy-synchronized-type | **已移除** | [墓碑](../../evidence/_removed/jp-legacy-synchronized-type.REMOVED.md) | 测量约 ~1.08× / HT 阴性 — 匹配器已删除 |
| jp-many-boolean-fields | **已移除** | [墓碑](../../evidence/_removed/jp-many-boolean-fields.REMOVED.md) | COH 16=16 无胜 — 匹配器已删除 |
| **jp-enum-key-hash-collection** | **错误** | [jp-enum-key-hash-collection](../../evidence/zh-CN/jp-enum-key-hash-collection.md) | JDK 27 EnumMap ~**11.6×** |
| **jp-collection-chain** | **关闭** | [jp-collection-chain](../../evidence/zh-CN/jp-collection-chain.md) | JDK 27 / Kotlin 2.4.21 eager/seq ~**265×** |
| **jp-value-class-boxing** | **提示** | [jp-value-class-boxing](../../evidence/zh-CN/jp-value-class-boxing.md) | JDK 27 时间 ~**4.0×**, 分配 ~**5.0×** |
| **jp-lambda-to-non-inline-hot** | **关闭** | [jp-lambda-to-non-inline-hot](../../evidence/zh-CN/jp-lambda-to-non-inline-hot.md) | JDK 27 分配 ~**244×**；时间 ~**0.47×** |
| jp-lazy-default-mode | **关闭** | [jp-lazy-default-mode.md](../../evidence/zh-CN/jp-lazy-default-mode.md) 仅 | **待测量** — 情境懒惰模式 |
| **jp-data-copy-hot** | **错误** | [jp-data-copy-hot](../../evidence/zh-CN/jp-data-copy-hot.md) | JDK 27 时间 ~**208×**, 分配 ~**10001×** |
| jp-android-sparse-array | 提示 | 存根 md | **待定** — 需要 ART/设备 |
| **jp-log-hot** | **关闭** | [jp-log-hot](../../evidence/zh-CN/jp-log-hot.md) | JDK 27 时间平均 ~**0.43×**（一次峰值）；安静的 JDK 21 ~**18×**；分配 ~**23200 B** |
| jp-sleep-polling | **关闭** | stub md | **待定** — 睡眠占主导；设计不是微型的 |
| jp-最终确认 | 提示 | 存根 md | **待定** — 最终确认正确性 / 更清理 |
| jp-expensive-alloc-hot | **关闭** | [jp-expensive-alloc-hot](../../evidence/zh-CN/jp-expensive-alloc-hot.md) | tiny-pool **负面** |
| jp-hot-heavy-alloc | **关闭** | 存根 md | **待处理** — ART/设备热分配 |
| jp-hot-format-log | **关闭** | stub md | **待处理** — ART/设备热格式/日志 |
| jp-hot-system-call | 提示 | 存根 md | **待定** — ART/设备系统调用 |
| jp-bitmap-decode-no-reuse | 提示 | 桩 MD | **待定** — ART/设备位图 |
| jp-hot-post-lambda | 提示 | 存根 md | **待处理** — ART 处理程序发布 |
| jp-ui-text-append | 提示 | stub md | **待定** — ART UI 文本 |
| **jp-baos-tobytearray-copy** | **错误** | [jp-baos-tobytearray-copy](../../evidence/zh-CN/jp-baos-tobytearray-copy.md) | JDK 27 toByteArray/writeTo ~**99×** |
| **jp-hot-payload-copy** | **错误** | [jp-hot-payload-copy](../../evidence/zh-CN/jp-hot-payload-copy.md) | JDK 27 newFrame/reuse ~**158×** |
| vt-unsafe-threadlocal-pool | —（未发布）| [存根](../../evidence/zh-CN/vt-unsafe-threadlocal-pool.md); 指南固定装置 | guide-first §10.2 |
| **jp-client-factory-recreate** | **错误** | [jp-client-factory-recreate](../../evidence/zh-CN/jp-client-factory-recreate.md) | JDK 27 HttpClient 新建+关闭/重用 ~**1.97e5×** |
| **jp-string-intern-hot** | **错误** | [jp-string-intern-hot](../../evidence/zh-CN/jp-string-intern-hot.md) | JDK 27 intern/plain ~**6.3×** |
| jp-non-static-field-updater | 提示 | [jp-non-static-field-updater](../../evidence/zh-CN/jp-non-static-field-updater.md) | JDK 27 创建 ~**526×**；静默 JDK 21 稳态 ~**1.13×** |

**计数（当前默认值）：** 活跃规则 **29**（原为 31；移除了 jp-legacy-synchronized-type / jp-many-boolean-fields）：8 个 **错误**，8 个 **提示**，13 个 **关闭**。表格仍列出墓碑规则和未发布规则。默认严重性遵循 `Rule.java` / G3 反向优化。

## 再生

```sh
cd packages/jvmperf
# Lint/tests: JAVA_HOME → JDK 21. Optional benches may use 25:
JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64 bash scripts/run_jmh.sh J32_RuleEvidenceBatch
JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64 bash scripts/run_kotlin_alloc.sh K15
# then refresh evidence/*.jsonl from bench-results if numbers move
```

在 JDK 主要升级后重新运行。永远不要发明比例。

另请参阅共享的 [rule-regression.md](../../../../docs/zh-CN/rule-regression.md)。
