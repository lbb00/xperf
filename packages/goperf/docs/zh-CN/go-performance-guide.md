# Go 性能指南（v0）

少一点分配噪声，少一点意外的 `fmt` / 字符串增长停顿。

> **范围：Go 1.21+。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（`go test -bench`、`pprof`、`benchstat`）。逃逸分析与内联会改变成本——工具链升级后请重测。

## 目录

- [1. 分配](#1-分配)
- [2. 字符串与格式化](#2-字符串与格式化)
- [3. 编译、编码与反射](#3-编译编码与反射)
- [Lint 对照](#lint-对照)

## 1. 分配

画像显示分配压力时，紧密循环里优先复用缓冲区（`sync.Pool`、预分配 slice），而不是 `make`/`new`。逃逸分析可能把小值留在栈上——没有 bench 就不要改。

Lint: `gp-make-hot`（默认 off，G3 后）; `gp-append-nil-slice`（空 slice + 有大小提示循环里的 append；默认 hint）
## 2. 字符串与格式化

循环里反复 `s += piece` 是平方级的。优先 `strings.Builder` 或 `bytes.Buffer`。热路径上的 `fmt.Sprintf` / `fmt.Printf` 也会分配；门控调试打印，或在测得更便宜时改用更轻的 appender。

Lint: `gp-string-plus-hot`, `gp-fmt-hot`（默认 off，G3 后）; `gp-defer-hot`（循环内 `defer`；默认 hint）
## 3. 编译、编码与反射

循环里的 `regexp.Compile` / `MustCompile` 与 `json.Marshal` / `Unmarshal` 会重复本可一次完成的工作（当模式或 payload 不变时）。循环里的 `FieldByName`、`MethodByName`、`reflect.New` 属于 reflect lint。对具体值的 `TypeOf` 约 1.3×，不匹配。`time.Parse` 已移除：固定时间戳仅在跳过解析时更快，变化的时间戳没有可外提的东西。这些 lint 是 hint。

对同一路径 `os.Open` 约 2300×（相对打开一次）。`time.Now` 约 104×（相对采一次样）。该时钟规则不是已移除的 `time.Parse` 规则。变化的路径不能外提；需要新鲜时间戳的循环也没有可外提的东西。

Lint: `gp-regexp-compile-hot`, `gp-json-marshal-hot`, `gp-reflect-hot`, `gp-os-open-hot`, `gp-time-now-hot`（默认 hint）
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| gp-make-hot | 循环内 `make`/`new` | off（G3） |
| gp-string-plus-hot | 循环内字符串 `+=` | off（G3） |
| gp-fmt-hot | 循环内 `fmt.Sprintf`/`Printf` | off（G3） |
| gp-append-nil-slice | 空 slice + 有大小提示循环里的 append | hint |
| gp-defer-hot | 循环内 `defer` | hint |
| gp-regexp-compile-hot | 循环内 `regexp.Compile` | hint（有测量；未 corpus 分级） |
| gp-json-marshal-hot | 循环内 `json.Marshal` / `Unmarshal` | hint（有测量；未 corpus 分级） |
| gp-reflect-hot | 循环内 `FieldByName` / `MethodByName` / `reflect.New` | hint（有 JSONL；不匹配 `TypeOf`） |

仅在有 `evidence/<rule>.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
