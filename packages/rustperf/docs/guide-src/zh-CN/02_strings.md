## 2. 字符串与热 I/O

循环里用 `format!("{s}…")` / `s = format!(…)` 累加分配很重（会拷贝不断变长的前缀）——**rs-format-rebind-hot**。优先 `with_capacity` + `write!`，或先收集再 join。对单一增长的 `String` 做普通 `+=` / `push_str`，在大填充上相对 `with_capacity` 约 1×，因此该 lint 已移除。不要把 `println!` / `eprintln!` 放进紧密循环（门控或缓冲）。

大 `Vec::new` 再 `push` 相对 `with_capacity` 约 1×，该 lint 已移除。逐项循环里避免 `.collect::<Vec<_>>()`，若复用缓冲区或流式计数即可（**rs-collect-vec-hot**）。

Lint: `rs-format-rebind-hot`（default error; G4: ~99× vs `write!`); `rs-println-hot`, `rs-collect-vec-hot`（默认 hint）
