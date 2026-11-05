# Objective-C 性能指南（v0）

Foundation 集合、字符串与日志核对清单。与 [swiftperf](../../../swiftperf/) 不同。

> **范围：Objective-C（ARC 或 MRC）。** lint 是对 `.m`/`.h` 的行窗扫描。加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（Instruments Time Profiler / Allocations）。升为更高严重级别前，请在真机或 macOS 上测量。

## 目录

- [1. 集合](#1-集合)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [3. Formatter、JSON 与正则](#3-formatterjson-与正则)
- [Lint 对照](#lint-对照)

## 1. 集合

`[[NSMutableArray alloc] init]` 再多次 `addObject:` 可能反复扩容。已知 `n` 时优先 `arrayWithCapacity:`。没有 lint 覆盖：抖动受控复测未显示可靠加速后，容量规则已移除。
## 2. 字符串与热 I/O

循环里的 `stringByAppendingString:` 会分配许多不可变字符串。优先 `NSMutableString`。不要把 `NSLog` 放进紧密循环（门控，或谨慎使用 os_log）。

Lint: `oc-nsstring-append-hot`, `oc-nslog-hot`（默认 off）
## 3. Formatter、JSON 与正则

循环里的 `[[NSDateFormatter alloc] init]`、`[NSDateFormatter new]`、`NSJSONSerialization`（`JSONObjectWithData` / `dataWithJSONObject`）以及 `NSRegularExpression`（`regularExpressionWithPattern`）每轮重复准备。formatter 或表达式只建一次；数据允许时，payload 只解析或编码一次。这些 lint 是 hint。各自有 JSONL 微基准并保持 hint。它们不属于 2026-10-22 corpus-ready 裁决。它们不会复活已移除的数组容量规则。

对同一路径 `stringWithContentsOfFile:` 约 450×（相对读一次）。每轮都变的路径不能外提。

每轮 `[NSDate date]` 相对采一次样约 769×。需要新鲜时间戳的循环没有可外提的东西。`NSDateFormatter` 仍是独立规则。

每轮 `valueForKey:` 相对读字段约 124×。不是固定字段的名字不能改写成直接读取。这与 Go 的 `FieldByName` 同族。

Lint: `oc-dateformatter-hot`, `oc-json-hot`, `oc-regex-hot`, `oc-file-read-hot`, `oc-clock-hot`, `oc-value-for-key-hot`（默认 hint）
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| oc-nsstring-append-hot | 循环内 stringByAppendingString | off |
| oc-nslog-hot | 循环内 NSLog | off |
| oc-dateformatter-hot | 循环内 date formatter alloc/init 或 new | hint（有 JSONL；未 corpus 分级） |
| oc-json-hot | 循环内 JSON 解析或编码 | hint（有 JSONL；未 corpus 分级） |
| oc-regex-hot | 循环内编译正则 | hint（有 JSONL；未 corpus 分级） |

仅在有 `evidence/oc-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。两条数组容量规则（OC001、OC004）已移除；见 [rule-ids.md](rule-ids.md)。`oc-dateformatter-hot`、`oc-json-hot`、`oc-regex-hot` 有 JSONL 微基准并保持 hint。它们不属于 2026-10-22 corpus-ready 裁决。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
- [swiftperf](../../../swiftperf/)（同级）
