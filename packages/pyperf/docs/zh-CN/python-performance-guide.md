# Python 性能指南（v0）

少做平方级 builder，让热路径更安静。

> **范围：CPython 3.10+。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（`timeit`、`py-spy`、`cProfile`）。PyPy 与其他 VM 不同——请重测。

## 目录

- [1. 字符串与列表](#1-字符串与列表)
- [2. 热 I/O](#2-热-io)
- [3. 解析与深拷贝](#3-解析与深拷贝)
- [Lint 对照](#lint-对照)

## 1. 字符串与列表

循环里的 `s += piece` 在 CPython 上是平方级的。优先 `''.join(...)` 或 `io.StringIO`。反复 `xs = xs + [item]` 同样会拷贝；优先 `append`。

Lint: `pp-str-plus-hot`（默认 off，G3 后）; `pp-list-plus-rebind`（默认 hint）
## 2. 热 I/O

紧密循环里的 `print` 会刷新并格式化。门控调试输出或做缓冲。

Lint: `pp-print-hot`（默认 off，G3 后）
## 3. 解析与深拷贝

循环里的 `json.loads` / `json.dumps` 与 `deepcopy` 会重复本可在循环外完成的工作（当值不变时）。变化的 payload 不能外提。这些 lint 是 hint，并有微基准。`re.compile` 已移除：CPython 会缓存，测得差距低于 3×。`datetime.strptime` / `strftime` 已移除：固定字符串仅在跳过调用时更快，变化的字符串没有可外提的东西。

循环里对同一路径 `open` 会反复打开。某一测量形态（1 字节文件）约 409×。每轮都变的路径不能外提。`time.perf_counter_ns` 约 2.9×，`getattr` 约 1.4×；已检查但未给规则。

Lint: `pp-json-hot`, `pp-deepcopy-hot`, `pp-open-hot`（默认 hint）
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| pp-str-plus-hot | 循环内字符串 `+=` | off（G3） |
| pp-list-plus-rebind | 循环内 list `+` 重绑定 | hint |
| pp-print-hot | 循环内 `print(` | off（G3） |
| pp-json-hot | 循环内 `json.loads` / `dumps` | hint（有测量；未 corpus 分级） |
| pp-deepcopy-hot | 循环内 `deepcopy` | hint（有测量；未 corpus 分级） |

仅在有 `evidence/pp-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。临时的 `re.METHOD(literal)` 规则（PP004）已移除；见 [rule-ids.md](rule-ids.md)。`pp-regex-compile-in-loop` 与 `pp-datetime-format-in-loop` 已移除。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
