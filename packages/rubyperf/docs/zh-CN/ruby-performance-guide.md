# Ruby 性能指南（v0）

少做平方级 builder，让热路径更安静。

> **范围：MRI Ruby 3+。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（`benchmark`、stackprof）。JRuby 与 TruffleRuby 不同——请重测。

## 目录

- [1. 字符串、数组与哈希](#1-字符串数组与哈希)
- [2. 热 I/O](#2-热-io)
- [3. 编译与解析](#3-编译与解析)
- [Lint 对照](#lint-对照)

## 1. 字符串、数组与哈希

`s += piece` 每次分配新字符串；优先 `s << piece`（或缓冲区）。`arr = arr + [x]` 会拷贝；优先 `<<` / `push`。

循环里的 `Hash#merge` 已移除。在 Ruby 4.0.8 上，建议的字面量构建比 `merge` 更慢（约 0.78×，再次约 0.65×），并大约多分配一倍对象。见 `evidence/_removed/rb-hash-merge-in-loop.REMOVED.md`。

Lint: `rb-string-plus-hot`, `rb-array-plus-rebind`（默认 off）
## 2. 热 I/O

紧密循环里的 `puts` / `print` 会刷新。门控调试输出或做缓冲。

Lint: `rb-puts-hot`（默认 off）
## 3. 编译与解析

`Regexp.new` 每次调用都编译。正则字面量会被缓存。对固定 payload 的 `JSON.parse` / `generate` 会重复解析。变化的 payload 不能外提。这些 lint 是 hint，并有微基准。`Date.parse` / `Time.parse` / `DateTime.parse` 已移除，原因与固定字符串解析相同：after 侧仅靠不解析才赢。

对同一路径 `File.read` 约 346×（相对读一次）。`File.open` 属同一 lint。每轮都变的路径不能外提。`Process.clock_gettime` 约 2.3×，`send` 约 1.9×；已检查但未给规则。

Lint: `rb-regexp-new-hot`, `rb-json-hot`, `rb-file-read-hot`（默认 hint）
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| rb-string-plus-hot | 循环内字符串 `+=` | off |
| rb-array-plus-rebind | 循环内 Array `+` / concat 重绑定 | off |
| rb-puts-hot | 循环内 `puts` / `print` | off |
| rb-regexp-new-hot | 循环内 `Regexp.new` | hint（有测量；未 corpus 分级） |
| rb-json-hot | 循环内 `JSON.parse` / `generate` | hint（有测量；未 corpus 分级） |

用 `--severity <rule>=hint` 启用 `off` 规则。升为 `error` 仅在有测量的 `evidence/rb-*.jsonl`——见 [evidence-policy.md](evidence-policy.md)。`rb-date-parse-in-loop` 与 `rb-hash-merge-in-loop` 已移除。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
