# 文档风格

由 `bash scripts/doc-check.sh` 与 `bash scripts/build-guides.sh --check` 强制执行（二者均在 CI 中运行）。在源头修正；不要放宽检查。

## 全部 Markdown

- 首行必须是一个 `# H1`；标题层级不可跳级；仅使用 ATX（`#`）标题。
- 无行尾空白、无 CRLF、恰好一个末尾换行。
- 相对链接必须可解析。不要链接到仓库外的文件。
- 列表使用 `-`；代码围栏在适用时带上语言标签。
- 除 `zh-CN/` 目录外一律使用英文。

## 每个 package

| 文件 | 要求 |
|------|------|
| `README.md` | 含 `## Run lint` 与 `## Layout`（建议顺序：Contents、Focus、Run lint、Layout） |
| `docs/corpus.md` | 先写 `## Pins`；其后章节为带日期的笔记 |
| `docs/evidence-policy.md` | 先 `## Gate`，再 `## Current map`（标题不含日期或版本；把“截至 <date>”写在该节首行） |
| `docs/rule-ids.md` | 一个 H1；墓碑放在 `## Removed (tombstone; never reuse)` 下 |
| `evidence/<slug>.md` | 含 `Claim`、`How measured`、`Runtime` 表与结果；或待定规则用 `Status` / `Reason` / `Unblock` |

## 指南

`docs/guide-src/*.md`（或 `guide-src/<lang>/*.md`）是唯一源。指南本身由生成得到：

```sh
bash scripts/build-guides.sh          # 从 guide-src 重写指南
bash scripts/build-guides.sh          # 从 guide-src 重写指南
bash scripts/build-guides.sh --check  # 若指南被手改则失败
bash scripts/build-guides.sh --check  # 若指南被手改则失败
```

- 分片按字节拼接，因此仅当指南在该处需要空行时，分片才以空行结尾。
- 分片内的链接相对**生成后的指南**书写，而不是相对 `guide-src/`。
- 分片名为 `NN_topic.md`；`00_head.md` 打开指南。
