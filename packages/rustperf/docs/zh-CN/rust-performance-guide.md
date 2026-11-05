# Rust 性能指南（v0）

少一点分配器噪声，少一点意外的字符串 / 打印停顿。

> **范围：Rust edition 2021+。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（`cargo bench`、`criterion`、`perf`）。LLVM 优化会改变成本——工具链升级后请重测。

## 目录

- [1. 分配与 clone](#1-分配与-clone)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [3. Regex](#3-regex)
- [Lint 对照](#lint-对照)

## 1. 分配与 clone

画像显示有压力时，热循环里优先复用与容量，而不是 `Vec::new` / `.clone()` / `.to_string()`。

```rust
// prefer: pre-sized or reused buffer
let mut v = Vec::with_capacity(n);
for i in 0..n { v.push(i); }
```

Lint: `rs-alloc-hot`（默认 off，G3 后；G4 有测量）
## 2. 字符串与热 I/O

循环里用 `format!("{s}…")` / `s = format!(…)` 累加分配很重（会拷贝不断变长的前缀）——**rs-format-rebind-hot**。优先 `with_capacity` + `write!`，或先收集再 join。对单一增长的 `String` 做普通 `+=` / `push_str`，在大填充上相对 `with_capacity` 约 1×，因此该 lint 已移除。不要把 `println!` / `eprintln!` 放进紧密循环（门控或缓冲）。

大 `Vec::new` 再 `push` 相对 `with_capacity` 约 1×，该 lint 已移除。逐项循环里避免 `.collect::<Vec<_>>()`，若复用缓冲区或流式计数即可（**rs-collect-vec-hot**）。

Lint: `rs-format-rebind-hot`（default error; G4: ~99× vs `write!`); `rs-println-hot`, `rs-collect-vec-hot`（默认 hint）
## 3. Regex

循环里的 `Regex::new` 会反复编译模式。在 `regex` 1.13.1 与 rustc 1.99 上，每轮构造再匹配短 haystack，相对构造一次约 963×（两侧仍匹配）。该 lint 为 hint。`HashMap::new` 加一次 insert，重复 20000 次，相对清空同一 map 约 1.5×（两次安静的 rustc 1.99 运行；`rs-map-new-hot`，hint）。

对同一路径 `File::open` 在 rustc 1.99 上约 416×（相对打开一次）。`Instant::now` 约 20×（相对采一次样）。变化的路径不能外提；需要新鲜时间戳的循环也没有可外提的东西。

Lint: `rs-regex-new-hot`, `rs-file-open-hot`, `rs-clock-hot`（默认 hint）
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| rs-alloc-hot | 循环内 alloc/clone | off（G3 OK-idiom；G4 有测量） |
| rs-println-hot | 循环内 println! / eprintln! | hint |
| rs-format-rebind-hot | 循环内 `format!` 重绑定累加 | error（G4：相对 `write!` 约 99×） |
| rs-collect-vec-hot | 循环内 collect::<Vec> | hint |
| rs-regex-new-hot | 循环内 `Regex::new` | hint（短 haystack 上 JSONL 约 963×） |

见 [evidence-policy.md](evidence-policy.md)。若一次性包装占主导，可用 `--severity rs-format-rebind-hot=hint` 降级。摊销的 `+=` 与大 `Vec::new` + push 已移除。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
