# swiftperf 证据政策

## 门槛

一条规则只有在有 `evidence/<RULE>.md` + `.jsonl` **以及**明确的政策决定的情况下才可以被视为 **`error`**。仅测量的 JSONL 并不会自动升级。批次 B（2026-10-22）保持了软件包默认设置。

## 当前映射

截至2026-10-22，第B批次G4。

| 规则 | 严重性（默认） | 证据 | 异味 |
|------|--------------------|----------|-------|
| sp-print-hot | 关闭 | [sp-print-hot.md](../../evidence/zh-CN/sp-print-hot.md) | 大约是 String 的 10 倍，标准输出到 /dev/null；保持关闭 |
| sp-array-no-reserve | 提示 | [sp-array-no-reserve.md](../../evidence/zh-CN/sp-array-no-reserve.md) | 对许多小数组约快 5 倍；对一个大填充约快 1.6 倍；保持提示 |
| sp-dateformatter-hot | 提示 | JSONL 存在（`sp-dateformatter-hot.md` + `.jsonl`）；保持提示 | 在循环中构建的日期格式化器；未经过语料库分类 |
| sp-json-decode-hot | 提示 | JSONL 存在（`sp-json-decode-hot.md` + `.jsonl`）；保持提示 | JSON 解码器或 jsonObject 在循环中；未经过语料库整理 |
| sp-regex-hot | 提示 | JSONL 存在（`sp-regex-hot.md` + `.jsonl`）；保持提示 | 在循环中构建的正则表达式；未经过语料库筛选 |
| sp-file-read-hot | 提示 | 已测量 (`sp-file-read-hot.md` + `sp-file-read-hot.jsonl`); 保持提示 | 循环中的 `contentsOfFile`; 仅相同路径; 非语料库分类 |
| sp-clock-hot | 提示 | 已测量（`sp-clock-hot.md` + `sp-clock-hot.jsonl`）；停留提示 | 循环中的 `Date()`；未进行语料库分类 |
| sp-value-for-key-hot | 提示 | 测量过的（`sp-value-for-key-hot.md` + `sp-value-for-key-hot.jsonl`）；保持提示 | 循环中的 `value(forKey:)`；未经过语料筛选 |

2026-10-23 添加的三行保持 **hint**。每行现在都有一个 JSONL 微基准。它们在 2026-10-22 的语料库准备好的判决之外，并且比例是一个形状，而不是一般的加速。
