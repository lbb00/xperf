# jp-format-hot — `String.format` / 在高频循环中格式化

## 主张

在 HotSpot 上，热使用 `String.format`（及类似方法）要比使用 `StringBuilder` 追加（或对日期型文本使用可重用的 `DateTimeFormatter`）构建相同的字符串慢得多且分配更多。

## 如何测量

- Harness:`jmh-benches/./J27 FormatHot.java'通过`scripts/run jmh.sh J27 FormatHot'
- 工作:小模式的代表=1;JMH 1.37 avgt + `-prof gc';`-XX:+ 使用压缩对象头'
- ** 在**`弦乐论坛 ' 之前
- ** 之后:** `钢铁建造工附录 ' (又记录:`日期Time Formatter ' )
- Raw:`研究/结果/J27-FormatHot.jsonl'
- 证据:STATIC-VS-HOTSPOT案3

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海 |
| JDK | **27 (27+35)** |
| JVM 参数 | `-XX:+UseCompactObjectHeaders` |
| 在 `stringFormat[reps=1]` 之前 | **1022.449 纳秒/次操作**, **1368.006 字节/次操作** |
| 在 `stringBuilderAppend[reps=1]` 之后 | **35.147 ns/次操作**, **88.000 B/次操作** |
| **前/后比例** | **约29.1×** 时间 |
| vs `dateTimeFormatter[reps=1]` | **141.005 ns/次** → 格式化/DTF ~**7.3×** |

## 与 lint 的对应

`jvmperf-lint` jp-format-hot (`format-in-loop`)。默认严重性 **关闭**（使用 `--enable` 启用）。

## 限制

- 日志记录 / 罕见错误路径：实际时间通常无关紧要 — 保持抑制。
- 一次性脚本和异常信息是较弱的升级目标。
