## 2. `delete` 与 shape

### 2.1 为什么热对象上的 `delete` 伤性能

`delete obj.key` 改变对象的 hidden class。引擎可能掉下 monomorphic IC；空洞在某些路径上会逼进 dictionary 模式。优先：

- 字段可选且希望 shape 稳定时，用 `obj.key = undefined` / `null`。
- 「是否存在」很常见时，用并行 `Set` / bitset / 稠密旁表。
- 在冷路径重建新对象，而不是在热循环里 delete。

Lint：**jp-delete-shape** —— 成员表达式上的 `delete`（文件级启发式；默认不限循环）。实测门禁：[`evidence/jp-delete-shape`](../../evidence/zh-CN/jp-delete-shape.md)（相对墓碑约 **474×**，Node v20.19.2）；JSONL 同意，但语料 triage 发现命中几乎全是 OK 惯用法（见 [evidence-policy](evidence-policy.md)），故默认 **off**（`--preset all` 或 `--severity jp-delete-shape=error` 开启）。

### 2.2 有意的 `delete`（bootstrap / 功能剥离）

Node 的 `lib/internal/bootstrap/**` 用 `delete` 做模块缓存与功能剥离。那是启动 / 一次性，不是每请求热路径。

**jsperf-lint：** 对 jp-delete-shape 与 jp-delete-array-hole 跳过 `internal/bootstrap/` 下文件、匹配 `*bootstrap*` 的文件名，以及 inspect/debugger/test-runner 路径。

**证据（dogfood）：** Node `lib/` jp-delete-shape 在 bootstrap 跳过后 **27 → 21**（r1→r2）；r3 保持 **21**，同时 jp-alloc-hot 在动。剩余 delete 需逐案评审（CLI 拆卸、稀有 map）。

### 2.3 可选的未来

`--hot-only`（要求 jp-delete-shape 有循环上下文）尚未交付。在此之前，把循环外的 jp-delete-shape 当作 shape 味道，而不是自动 bug。

---
