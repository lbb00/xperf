# Swift 性能指南（v0）

热路径少强制解包，少做平方级字符串 builder。

> **范围：Swift 5.9+。** 声称加速的断言会点名本地示例，或标明暂定。**Corpus lint 计数是启发式 dogfood**，不是基准。

## 0. 范围与方法

1. 先**测量**（Instruments，可用时用 `swift package benchmark`）。
2. 把每一章当核对清单。
3. ARC 与特化会改变成本——工具链升级后请重测。

## 目录

- [0. 范围与方法](#0-范围与方法)
- [1. Optional 与热路径](#1-optional-与热路径)
- [2. 字符串、集合与打印](#2-字符串集合与打印)
- [3. Formatter、JSON 与正则](#3-formatterjson-与正则)
- [Lint 对照](#lint-对照)
## 1. Optional 与热路径

紧密循环里的强制解包（`!`）在 nil 时会崩，并跳过更安全的控制流。优先每轮一次 `guard let` / `if let`，或外提。

在非 nil 数组上，强制解包与 `if let` 耗时相同，因此没有对应 lint。
## 2. 字符串、集合与打印

反复 `s += piece` 可能昂贵；测得需要时优先预留容量 / builder。热路径 `print` 受 I/O 限制——请门控。在有大小的循环里向空 `Array` 追加会边长边扩容；已知最终计数时先 `reserveCapacity`。

配套 lint：**sp-print-hot**（off；丢弃 stdout 时相对 `String` 约 10×）、**sp-array-no-reserve**（hint；许多小数组约 5×，一次大填充约 1.6×）。带 `reserveCapacity` 的字符串 `+=` 更慢，`map` 再 `joined` 约 1.2×，因此那些 lint 已移除。
## 3. Formatter、JSON 与正则

`DateFormatter`、`JSONDecoder`、`NSRegularExpression` 准备很重。热循环每轮新建会重复该工作；只建一次并复用。`JSONSerialization.jsonObject` 归入 JSON 情形。Swift `Regex` 值是另一套 API，不标记。这些 lint 是 **hint**。各自有 JSONL 微基准并保持 hint。它们不属于 2026-10-22 corpus-ready 裁决。

对同一路径 `String(contentsOfFile:)` 约 414×（相对读一次）。每轮都变的路径不能外提。

每轮 `Date()` 相对采一次样约 244×。需要新鲜时间戳的循环没有可外提的东西。`DateFormatter` 仍是独立规则。

每轮 `value(forKey:)` 相对读属性约 35×。每轮都变的名字不能变成直接属性。这与 Go 的 `FieldByName` 同族。

配套 lint：**sp-dateformatter-hot**、**sp-json-decode-hot**、**sp-regex-hot**、**sp-file-read-hot**、**sp-clock-hot**、**sp-value-for-key-hot**。
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| sp-print-hot | 循环内 `print(` | off（相对 String 约 10×；丢弃 stdout） |
| sp-array-no-reserve | 空 Array 追加且无 `reserveCapacity` | hint（小约 5×，一次大填充约 1.6×） |
| sp-dateformatter-hot | 循环内构造 date formatter | hint（有 JSONL；未 corpus 分级） |
| sp-json-decode-hot | 循环内 JSON decoder 或 jsonObject | hint（有 JSONL；未 corpus 分级） |
| sp-regex-hot | 循环内构造正则 | hint（有 JSONL；未 corpus 分级） |

用 `--severity <rule>=hint` 启用 `off` 规则。2026-10-22 的五条规则仍无 JSONL。2026-10-23 新增三行有 JSONL 微基准并保持 **hint**。它们不属于 2026-10-22 corpus-ready 裁决。见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
