## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| CX001 | 已移除（抖动） | — |
| cx-regex-ctor-hot | 循环内构造 `std::regex` | hint（有 JSONL；未 corpus 分级） |
| cx-endl-hot | 循环内 `endl` flush | hint（有 JSONL；未 corpus 分级） |
| cx-clock-hot | 循环内采时钟 | hint（有 JSONL；相对一次采样约 147×；未 corpus 分级） |
| cx-ifstream-hot | 循环内打开文件流 | hint（有 JSONL；单字节文件约 2025×；未 corpus 分级） |
| cx-const-by-value | 按值拷贝 `const` string 或 vector | hint（有 JSONL；拷贝会分配时约 15–21×；未 corpus 分级） |
| cx-vector-bool | 打包 bool 元素容器 | hint（有 JSONL；遍历相对字节 vector 约 12×；未 corpus 分级） |
| CX003 | 已移除（抖动） | — |
| CX004 | 已移除（抖动） | — |

仅在有 `evidence/cx-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。退役的 CX004 表明 `-O2` 可能抹掉效果；若声称速度，请在 `-O0` / sanitizer 下测量。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
