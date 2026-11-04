# Lua 性能指南（v0）

少做 table 扩容，少做平方级字符串拼接，让热循环更安静。

> **范围：Lua 5.1–5.4 / 偏 LuaJIT 形态的模式。** 声称加速的断言会点名本地示例，或标明暂定。**Corpus lint 计数是启发式 dogfood**，不是基准。

## 如何阅读

1. 先**测量**（LuaJIT `-jv`、简单墙钟计时）。
2. 把每一章当核对清单，不是强制重写令。

## 目录

- [0. 范围与方法](#0-范围与方法)
- [1. Table](#1-table)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [Lint 对照](#lint-对照)
## 1. Table

不知道最终大小时 `table.insert` 仍可用，但热循环里反复扩容会受伤。已知 `n` 时，优先预分配数组部分后用 `t[#t+1] = x`，或按索引写字段。

```lua
local t = {}
local t = {}
for i = 1, n do
for i = 1, n do
  t[i] = i
  t[i] = i
end
end
```
## 2. 字符串与热 I/O

循环里的 `a .. b` 会产生许多临时对象。优先收集片段再 `table.concat`。不要把 `print` 放进紧密循环（门控或缓冲）。
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| lu-table-insert-hot | 循环内 table.insert / 扩容 | off |
| lu-string-concat-hot | 循环内字符串 `..` | error |
| lu-print-hot | 循环内 `print` | hint |

仅在有 `evidence/lu-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。lu-print-hot 有测量证据但仍保持 **hint**（依赖 I/O sink）。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
