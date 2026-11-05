### Lint 对照表

| ID | 主题 | 严重级别 | 证据 / 备注 |
|----|------|----------|-------------|
| jp-alloc-hot | 对象/数组/`new` 分配 | off（`all`：error） | [`jp-alloc-hot`](../../evidence/zh-CN/jp-alloc-hot.md) ~19× / ~6.4× —— GC/分配，非 deopt |
| jp-console-hot | `console.*` | hint（`engine`）/ off（`app`） | [`jp-console-hot`](../../evidence/zh-CN/jp-console-hot.md) ~1328× 丢弃 sink —— 依赖环境 |
| jp-delete-shape | 普通成员上的 `delete` | off（`all`：error） | [`jp-delete-shape`](../../evidence/zh-CN/jp-delete-shape.md) 相对墓碑 ~474×；语料命中几乎全是 OK 惯用法 |
| jp-delete-array-hole | 计算索引上的 `delete`（holey 数组） | error | [`jp-delete-array-hole`](../../evidence/zh-CN/jp-delete-array-hole.md) 相对 packed ~3.2× |
| jp-map-filter-chain | 链式 `.map` / `.filter` / `.flatMap` | hint | 长数组约 4.6×–9.8×；3 行 filter+map 为 1.28× |
| jp-regex-ctor-hot | `new RegExp`，模式非循环绑定 | hint | Node 26 固定模式约 4.4×；优先字面量或一次共享编译 |
| jp-json-hot | `JSON.parse` / `stringify`，文本非循环绑定 | hint | Node 26 不变文本约 140×；稳定时复用 |
| jp-dom-query-hot | DOM 查询，选择器非循环绑定 | hint | Node 26、很小 linkedom 上 JSONL 约 16×；未做语料 triage |
| jp-intl-datetimeformat-hot | `new Intl.DateTimeFormat` | hint | Node 26 约 36×；两边仍 format；未做语料 triage |
| jp-readfile-sync-hot | `readFileSync`，路径非循环绑定 | hint | Node 26，不变路径约 114× |
| jp-clock-hot | `Date.now` / `performance.now` | hint | Node 26 无 `await` 时约 70× / 110×；不需要新鲜时间时采样一次 |
| *（无）* | 模块解析 / 急切图 / barrel | — | §5 —— 用 `--cpu-prof` |

上表严重级别为默认 `app` preset。匹配作用域默认为 **`--scope all`**（到处）；`--scope loop` 恢复仅循环内匹配。策略：[`evidence-policy.md`](evidence-policy.md)。夹具：`jsperf-lint/fixtures/{bad,good}/`。

### 参考

- [corpus.md](corpus.md)
- `examples/bench/` · `scripts/run-v8-benches.sh` · `scripts/jit-check.sh` · `scripts/run-static-vs-v8.sh` · `scripts/regen-evidence.sh` · `examples/bench/require_cost_sketch.js`
- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
- Marvin Hagemeister — [Speeding up the JavaScript ecosystem](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)（第 1–13 部分；§5 引用方法）
