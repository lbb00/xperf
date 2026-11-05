# jvmperf 证据

每条规则的门对（`<RULE>.md` + `<RULE>.jsonl`）。政策：[../docs/evidence-policy.md](../../docs/zh-CN/evidence-policy.md)。政策列是每条规则在 `Rule.java` 中的默认严重性。

| 规则 | 文件 | 政策 |
|------|-------|--------|
| jp-boxed-primitive-collection | 是 | 关闭 |
| jp-string-concat-hot | 是 | **错误** |
| jp-regex-hot | 是 | 关闭 |
| jp-format-hot | 是 | 关闭 |
| jp-unpresized-collection | 是 | 关闭 |
| jp-boxed-stream | 是 | **错误** |
| jp-异常控制流 | 是 | 关 |
| jp-legacy-synchronized-type | 已移除 | 见 `_removed/` |
| jp-many-boolean-fields | 已移除 | 请参见 `_removed/` |
| jp-enum-key-hash-collection | 是 | **错误** |
| jp-collection-chain | 是 | 关闭 |
| jp-value-class-boxing | 是 | 提示 |
| jp-lambda-to-non-inline-hot | 是 | 关闭 |
| jp-lazy-default-mode | md 存根 | 关闭（待定） |
| jp-data-copy-hot | 是 | **错误** |
| jp-android-sparse-array | md 存根 | 提示（待定） |
| jp-log-hot | 是 | 关闭 |
| jp-sleep-polling | md 孔 | 关闭（待定） |
| jp-finalize | md stub | 提示（待定） |
| jp-expensive-alloc-hot | 是 | 关闭（否定） |
| jp-hot-heavy-alloc–jp-ui-text-append | md 存根 | 热重分配和热格式日志关闭，其他四个提示（等待 ART） |
| jp-baos-tobytearray-copy | 是 | **错误** |
| jp-hot-payload-copy | 是 | **错误** |
| vt-unsafe-threadlocal-pool | [md stub](vt-unsafe-threadlocal-pool.md) | 未发布 / 指南优先 |
| jp-client-factory-recreate | 是 | **错误** |
| jp-string-intern-hot | 是 | **错误** |
| jp-non-static-field-updater | 是 | 提示 |

原始转储：`research/bench-results/`（本地输出，未提交）。

关联：`research/benches/`（由 `scripts/run-static-vs-hotspot.sh` 编写）。
