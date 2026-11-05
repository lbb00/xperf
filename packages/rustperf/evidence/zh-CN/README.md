# rustperf 证据

所有六条规则都有一个声明文件和测量过的 JSONL（挂载在 [`../examples/bench`](../../examples/bench)）：

- **rs-alloc-hot** — `rs-alloc-hot.md` + `.jsonl`; Vec::new 重用约 2.7× / fixture 克隆约 1.1× / to_string 约 1.7×；默认 **关闭**（比例适中，G3 OK-idiom 占主导）。
- **rs-println-hot** — `rs-println-hot.md` + `.jsonl`; 缓冲写入约 12.6×（I/O、环境相关）；默认 **提示**。
- **rs-format-rebind-hot** — `rs-format-rebind-hot.md` + `.jsonl`; `format!` 重新绑定约 99×（别名来自 rs-string-plus-in-loop G4 的 `format!` 配对）；默认 **错误**。
- **rs-collect-vec-hot** — `rs-collect-vec-hot.md` + `.jsonl`; 约 1.8×；默认 **提示**。

请参阅 [`../docs/evidence-policy.md`](../../docs/zh-CN/evidence-policy.md) 和根目录下的 [`docs/rule-regression.md`](../../../../docs/zh-CN/rule-regression.md)。
