# goperf 语料库目标

大型树木**不是**经过供应的，并且语料库不会随仓库一起分发：将其克隆到仓库之外的任何本地目录，并将该路径传递给代码检查器。

## 固定目标

| 树 | 链接 | 提交 | 备注 |
|------|-----|--------|-------|
| gin | https://github.com/gin-gonic/gin | `0f09c3a9b4626d9fe9979cf4d0521d6ae32ab646` | 浅层；默认设置下无发现 |
| testify | https://github.com/stretchr/testify | `87a7b9d57689f6579db2da795ab8deeab29cb724` | 浅层 |
| go (src/) | https://github.com/golang/go | `05dbbf9175d021c5a61a69e3cc22abbd483d7fb0` | 稀疏检出 `src/`；`cmd/` 被跳过 |

## G3 摘要（2026-10-22 亚洲/上海）——重新设计

| 树 | r2（重新设计前） | r6（默认设置） | 准备好语料库？ |
|------|-------------------|---------------|---------------|
| 杜松子酒 | 0 | **0** | （根据启发式方法清理） |
| 作证 | 5 | **13** | OK-习语 利用
| go-src | 429 | **210** | gp-append-nil-slice/gp-defer-hot |

**判决：语料库准备就绪 `是`。** 样本 n=93：TP 77.4% / OK-习语 22.6% / FP+DOC+跳过 0%。默认值：gp-make-hot–gp-fmt-hot **关闭**；gp-append-nil-slice/gp-defer-hot **提示**。没有虚构的证据 JSONL / 没有 G4 升级。

### 重新设计说明
- gp-append-nil-slice：空切片 + 在带大小提示的循环中 append
- gp-defer-hot：循环中的 defer（非嵌套闭包；字符串已清空）
- 跳过：`cmd/`、`generate.go`、`_codegen/`

不要将语料库来源提交到 `packages/goperf`。

## 2026-10-23 — 提示规则不在 2026-10-22 判决范围内

2026-10-22 的语料库准备判决不包括以下子弹头。它们仍然保持 **提示** 状态，尚未经过 G2/G3。

- `gp-regexp-compile-hot`、`gp-json-marshal-hot`、`gp-reflect-hot` — 磁盘上的 JSONL；仍然是提示
