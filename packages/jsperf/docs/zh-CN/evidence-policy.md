# jsperf 证据政策

## 门槛

只有在 `packages/jsperf/evidence/` 下同时存在以下两者时，JP 规则才可以被记录/处理为 **`error`**:

1. `<RULE>.md` — 声明、利用、Node/V8 版本、限制
2. `<RULE>.jsonl` — ≥1 个前/后测量对，包含字段 `rule`、`case`、`node`、`v8`、`median_ms`、`ops`、`ratio`、`ts`（可选 `role`：`before` = 问题, `after` = 修复）

否则规则是 **`hint`**（审查提示）：适用于内部测试和固定组件，不是“必须修复以提升速度”的信号。

仅凭证据是**必要的，但不充分**来判断`错误`。只有当实际时间一致**且**失败模式符合规则的保持契约（形状 / 有孔 / 热 `删除`）时才升级。配置/垃圾回收或依赖环境的 I/O 异味，即使有 JSONL，也可能保持**`提示`** / **`关闭`**。

## 当前映射

截至2026-10-23。“默认”是 `app` 预设；`--preset all` 会将所有规则提升为错误。

| 规则 | 默认严重性 | 证据 | 测量比率 (Node v20.19.2 / V8 11.3.244.8-node.38) |
|------|----------|----------|--------------------------------------------------|
| jp-delete-shape | **关闭** | [jp-delete-shape.md](../../evidence/zh-CN/jp-delete-shape.md) · [jp-delete-shape.jsonl](../../evidence/jp-delete-shape.jsonl) | `delete` / tombstone **~474次**；JSONL 存在，但语料审核发现命中几乎全是正确用法 → **关闭**；使用 `--preset all` / `--severity jp-delete-shape=error` 启用 |
| jp-delete-array-hole | **错误** | [jp-delete-array-hole.md](../../evidence/zh-CN/jp-delete-array-hole.md) · [jp-delete-array-hole.jsonl](../../evidence/jp-delete-array-hole.jsonl) | 有空洞的 `delete a[i]` / 紧凑 **~3.2×** |
| jp-alloc-hot | **关闭**（默认） | [jp-alloc-hot.md](../../evidence/zh-CN/jp-alloc-hot.md) · [jp-alloc-hot.jsonl](../../evidence/jp-alloc-hot.jsonl) | JSONL ~19×/~6.4× 存在；G3 语料库几乎全部为正确用法 → **关闭**；可通过 `--preset all` / `--severity jp-alloc-hot=hint` 启用 |
| jp-console-hot | **提示** (`engine`) / **关闭** (`app`) | [jp-console-hot.md](../../evidence/zh-CN/jp-console-hot.md) · [jp-console-hot.jsonl](../../evidence/jp-console-hot.jsonl) | 循环中的 `console.log` / 安静 **~1328×**（丢弃接收器）— 真实但依赖环境 → 不算错误 |

| jp-string-plus-in-loop | **已移除** | [墓碑](../../evidence/_removed/jp-string-plus-in-loop.REMOVED.md) | `push` + `join` 在匹配的形状上并非约 2 倍；匹配器已删除 |
| jp-map-filter-chain | **提示** | [jp-map-filter-chain.md](../../evidence/zh-CN/jp-map-filter-chain.md) · [jsonl](../../evidence/jp-map-filter-chain.jsonl) | 35000 行约 4.6× / 9.8×；一个 3 行的 filter+map 是 1.28×；保持提示 |
| jp-regex-ctor-hot | **提示** | 已测量（`jp-regex-ctor-hot.md` + `jp-regex-ctor-hot.jsonl`）；保持提示 | `new RegExp`（稳定模式）；未进行语料库筛选 |
| jp-json-hot | **提示** | 已测量（`jp-json-hot.md` + `jp-json-hot.jsonl`）；保持提示 | `JSON.parse` / `stringify`（稳定文本）；未进行语料库分类 |
| jp-dom-query-hot | **提示** | 测量 (`jp-dom-query-hot.md` + `jp-dom-query-hot.jsonl`); 保持提示 | DOM 查询（稳定选择器）；在 Node 26 上约 16×，一个小的 linkedom 文档 |
| jp-intl-日期时间格式-hot | **提示** | 测量 (`jp-intl-datetimeformat-hot.md` + `jp-intl-datetimeformat-hot.jsonl`); 保持提示 | `new Intl.DateTimeFormat`; Node 26 大约 36×; 未进行语料库分类 |
| jp-readfile-sync-hot | **提示** | 测量过的 (`jp-readfile-sync-hot.md` + `jp-readfile-sync-hot.jsonl`); 保持提示 | `readFileSync`（稳定路径）；未进行语料筛选 |
| jp-clock-hot | **提示** | 测量 (`jp-clock-hot.md` + `jp-clock-hot.jsonl`); 保持提示 | `Date.now` / `performance.now`; 未经过语料库分类 |

提示文本说明测量的前提（未更改的路径、文本、模式、选择器或格式化程序；没有 `await` 的紧密循环用于时钟）。没有 JSONL 的规则不会命名替代项。仅看起来像基准的调用不会获得基准的重写。该策略是指南和 `--preset` 的**保留/升级**契约。

## 再生

```sh
cd packages/jsperf
bash scripts/regen-evidence.sh
# or:
# node examples/bench/evidence_jp003_jp004.js
# node examples/bench/evidence_jp001_jp002.js
# node examples/bench/evidence_jp005_jp006.js
```

在 Node 主要升级后重新运行；更新匹配的 `.md` 表格。

## CLI 预设

- 默认 `--preset app`：**jp-delete-array-hole=error**；**jp-map-filter-chain**、**jp-regex-ctor-hot**、**jp-json-hot**、**jp-dom-query-hot**、**jp-intl-datetimeformat-hot**、**jp-readfile-sync-hot** 和 **jp-clock-hot** = 提示；**jp-alloc-hot**、**jp-console-hot**、**jp-delete-shape** = 关闭（关闭规则见 G3 2026-10-22）。**jp-string-plus-in-loop** 已移除。
- `engine`：与 app 相同，除了 **jp-console-hot** = 提示。
- `all`：所有规则都是错误。
- 覆盖：`--severity RULE=error|hint|off`（可重复；优先于预设）。
