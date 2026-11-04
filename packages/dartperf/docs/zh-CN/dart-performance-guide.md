# Dart 性能指南（v0）

少做 list 扩容，少产生字符串 `+` 临时对象，让热循环更安静。

> **范围：Dart 3.x（VM / Flutter）。** 声称加速的断言会点名本地示例，或标明暂定。**Corpus lint 计数是启发式 dogfood**，不是基准。

## 如何阅读

1. 先**测量**（`benchmark_harness`、DevTools CPU profiler）。
2. 把每一章当核对清单，不是强制重写令。

## 目录

- [如何阅读](#如何阅读)
- [1. List](#1-list)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [Lint 对照](#lint-对照)
## 1. List

热循环里的 `List.add` 在容量摊销时可以接受，但每次迭代新建可增长 list 不行。尽可能用 `List.filled` / `List.generate` / 已知长度。

配套 lint：**dt-list-add-empty**、**dt-growable-add-empty**（空的可增长 list + 在有大小提示的循环里 `add`）。
## 2. 字符串与热 I/O

循环里的 `s = s + x` 会造出许多字符串。优先 `StringBuffer`。不要把 `print` 放进紧密循环。

配套 lint：**dt-string-plus-hot**、**dt-print-hot**。
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| dt-list-add-empty | List 增长 / 无容量线索的 `add` | off |
| dt-string-plus-hot | 循环内字符串 `+` | off |
| dt-print-hot | 循环内 `print` | off |
| dt-growable-add-empty | 空可增长 list + 有大小提示循环里的 `add` | hint |

仅在有 `evidence/<rule>.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
