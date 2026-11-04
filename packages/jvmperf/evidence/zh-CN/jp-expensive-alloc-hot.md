# jp-expensive-alloc-hot — 循环中的高成本分配（作用域 + 负池神话）

## 申诉（规则意图）

应将**昂贵可重用**类型（`SimpleDateFormat`、`ObjectMapper`、`MessageDigest`、大型常量缓冲区等）的热构造提升或缓存。这就是 jp-expensive-alloc-hot 所标记的内容。

## 邻近测量（仅凭此**不要**升级）

小型逃逸对象是另一回事：一个天真的线程本地/回收 **小型 `Point` 类对象的池可能在墙钟时间上输给普通 TLAB `new`**，同时在每次操作字节数上获胜。

- 测试平台：`J24_PoolVsAlloc.java` / `scripts/run_jmh.sh J24_PoolVsAlloc`
- 对比：`pooled` vs `tlabAlloc`，批量大小 `batch=1`
- 原始数据：`research/bench-results/J24_PoolVsAlloc.jsonl`
- 关联：STATIC-VS-HOTSPOT 案例 5 **部分 / 负面**

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海 |
| JDK | **27 (27+35)** |
| JVM 参数 | `-XX:+UseCompactObjectHeaders` |
| `pooled[batch=1]` | **8.250 ns/op**, **0.000 B/op** |
| `tlabAlloc[batch=1]` | **3.826 ns/op**, **16.000 B/op** |
| **池 / TLAB 时间** | **池慢约 2.16 倍** |

## 与 lint 的对应

默认严重性 **关闭**（使用 `--enable` 运行它）。证据文档 **说明我们为何不将** jp-expensive-alloc-hot 从 J24 升级为 `error`：该规则的有价值目标是昂贵的工厂；J24 警告不要在循环中的每个 `new` 操作中都理解为“始终使用池”。

## 限制

- 没有JMH配对将“新简单数据格式”与“线程本地”/“日期Formatter”相隔开来——这将是正向升级的路径。
- VT + 脂肪 ' Thread Local ' 池 → 见指南JP029(指南-第一固定装置),而不是jp - 成本-分配热。
