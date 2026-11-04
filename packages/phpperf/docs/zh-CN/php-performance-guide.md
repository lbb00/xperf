# PHP 性能指南（v0）

少做平方级 builder，让热路径更安静。

> **范围：PHP 8+。** 声称加速的断言会点名本地示例，或标明暂定。**Corpus lint 计数是启发式 dogfood**，不是基准。

## 如何阅读

1. 先**测量**（`hrtime`、Blackfire、Xdebug）。
2. 把每一章当核对清单。
3. 扩展 / JIT 不同——请重测。

## 目录

- [0. 范围与方法](#0-范围与方法)
- [1. 字符串与数组](#1-字符串与数组)
- [2. 热 I/O](#2-热-io)
- [Lint 对照](#lint-对照)
## 1. 字符串与数组

循环里的 `$s .= $piece` 在规模变大时仍可能昂贵；优先收集器 + `implode`。反复 `$a = array_merge($a, …)` 会拷贝；优先 `$a[] = $item`。

配套 lint：**ph-string-dot-hot**、**ph-array-merge-rebind**。
## 2. 热 I/O

紧密循环里的 `echo` / `print` 会刷新输出。门控调试输出或做缓冲。

配套 lint：**ph-echo-hot**。
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| ph-string-dot-hot | 循环内字符串 `.=` | off |
| ph-array-merge-rebind | 循环内 `array_merge` 重绑定 | **error** |
| ph-echo-hot | 循环内 `echo` / `print` | hint |

仅在有 `evidence/ph-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
