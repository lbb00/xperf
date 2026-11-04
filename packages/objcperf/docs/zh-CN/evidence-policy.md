# objcperf 证据政策

## 门槛

一条规则只有在有 `evidence/<RULE>.md` + `.jsonl` **以及** 明确的政策决策时，才能被视为 **`error`**。仅测量的 JSONL 本身 **不会** 自动升级。2026-10-22 的 G4 填充保持了软件包默认值。

## 当前映射

截至2026-10-23。测量的行是2026-10-22的G4填充。三个新的分类标签是 hint、pending 和 not corpus-triaged。

| 规则 | 严重性（默认） | 证据 | 异味 |
|------|--------------------|----------|-------|
| oc-nsstring-append-hot | 关闭 | **是** GNUstep ~569× | NSString 附加 |
| oc-nslog-hot | 关闭 | **是** fprintf 代理 ~191× | 循环记录 |
| oc-dateformatter-hot | 提示 | 已测量（`oc-dateformatter-hot.md` + `oc-dateformatter-hot.jsonl`）；保持提示 | 循环中初始化/分配或新建日期格式化器；未进行语料库筛选 |
| oc-json-hot | 提示 | 测量（`oc-json-hot.md` + `oc-json-hot.jsonl`）；保持提示 | 在循环中解析或编码 JSON；未进行语料库筛选 |
| oc-regex-hot | 提示 | 测量（`oc-regex-hot.md` + `oc-regex-hot.jsonl`）；保持提示 | 在循环中编译的正则表达式；未经过语料库筛选 |
| oc-file-read-hot | 提示 | 测量（`oc-file-read-hot.md` + `oc-file-read-hot.jsonl`）；保持提示 | 循环中的 `stringWithContentsOfFile`；仅限相同路径；未进行语料库分类 |
| oc-clock-hot | 提示 | 测量 (`oc-clock-hot.md` + `oc-clock-hot.jsonl`); 保持提示 | 循环中的 `[NSDate date]`; 未经语料库分类 |
| oc-value-for-key-hot | 提示 | 已测量 (`oc-value-for-key-hot.md` + `oc-value-for-key-hot.jsonl`); 保持提示 | 循环中的 `valueForKey:`；未经过语料库筛选 |
| OC001 | 已移除 | 墓碑 | 见 `evidence/_removed/` |
| OC004 | 已移除 | 墓碑 | 见 `evidence/_removed/` |
