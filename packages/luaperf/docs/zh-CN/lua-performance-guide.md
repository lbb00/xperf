# Lua 性能指南（v0）

少做 table 扩容，少做平方级字符串拼接，让热循环更安静。

> **范围：Lua 5.1–5.4 / LuaJIT 形态的模式。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（LuaJIT `-jv`、简单墙钟计时）。各章是核对清单，不是强制重写令。

## 目录

- [1. Table](#1-table)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [Lint 对照](#lint-对照)

## 1. Table

不知道最终大小时 `table.insert` 仍可用，但热循环里反复扩容会受伤。已知 `n` 时，优先预分配数组部分后用 `t[#t+1] = x`，或按索引写字段。

```lua
local t = {}
for i = 1, n do
  t[i] = i
end
```

Lint: `lu-table-insert-hot`（默认 off）
## 2. 字符串与热 I/O

循环里的 `a .. b` 会产生许多临时对象。优先收集片段再 `table.concat`。不要把 `print` 放进紧密循环（门控或缓冲）。

Lint: `lu-string-concat-hot`（default error); `lu-print-hot`（默认 hint）
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| lu-table-insert-hot | 循环内 table.insert / 扩容 | off |
| lu-string-concat-hot | 循环内字符串 `..` | error |
| lu-print-hot | 循环内 `print` | hint |

仅在有 `evidence/lu-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。lu-print-hot 有测量证据但仍保持 hint（依赖 I/O sink）。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
