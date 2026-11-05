# Dart 性能指南（v0）

少做 list 扩容，少产生字符串 `+` 临时对象，让热循环更安静。

> **范围：Dart 3.x（VM / Flutter）。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（`benchmark_harness`、DevTools CPU profiler）。各章是核对清单，不是强制重写令。

## 目录

- [1. List](#1-list)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [Lint 对照](#lint-对照)

## 1. List

热循环里的 `List.add` 在容量摊销时可以接受，但每次迭代新建可增长 list 不行。尽可能用 `List.filled` / `List.generate` / 已知长度。

Lint: `dt-list-add-empty`（默认 off）; `dt-growable-add-empty`（empty growable list + `add` in a size-hinted loop; 默认 hint）
## 2. 字符串与热 I/O

循环里的 `s = s + x` 会造出许多字符串。优先 `StringBuffer`。不要把 `print` 放进紧密循环。

Lint: `dt-string-plus-hot`, `dt-print-hot`（默认 off）
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
