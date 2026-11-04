## Lint 对照表

| ID | 主题 | 严重级别 / 备注 |
|----|------|-----------------|
| cp-alloc-hot | 循环内 malloc/calloc/realloc | **error** — 有证据；VM 上少见；sqlite/gcc 十余到数十 |
| cp-realloc-grow-one | 无容量的 realloc 增长 | **error** — 有证据；成熟树几乎从不开火 |
| cp-printf-hot | 循环内 printf/fprintf/puts | 默认 **off** — 热路径 YES / 死代码 NEGATIVE；需要 dump 抑制 |
| cp-strlen-in-cond | 循环条件里的 strlen | **hint** — 重算约 125×，能提升约 1× |
| cp-strcat-hot | 循环内 strcat/strncat | 默认 **off** — 约 221×；冷 CLI/路径可接受 |
| cp-sprintf-hot | 循环内格式化写缓冲 | **hint** — 有 JSONL；未做语料 triage |
| cp-fopen-hot | 循环内打开文件 | **hint** — 有 JSONL；未做语料 triage |
| cp-gettime-hot | 循环内采样时钟（不含裸 `time`） | **hint** — 有 JSONL；未做语料 triage |
| cp-wide-bool-flags | 同一 struct 四个及以上全宽布尔标志 | **hint** — 有 JSONL；未做语料 triage |
| cp-regex-hot | 循环内 `regcomp`（不匹配 `regexec`） | **hint** — JSONL 约 9.7×；未做语料 triage |
| cp-alloca-hot | 循环内 `alloca` / `__builtin_alloca`（不匹配 VLA） | **hint** — 测过栈覆盖；墙钟约 1×；未做语料 triage |
| cp-struct-by-value | 可见下界 ≥512 字节且 ≥4 字段的 struct 按值参数 | **hint** — JSONL 跨 TU 约 12.3×；未做语料 triage |

## 参考

- [corpus.md](corpus.md) — clone pin 与 r2→r3 表
- 共享方法：[XPerf playbook](../../../../docs/zh-CN/playbook.md)
- 布局演示：`examples/p01_soa.c`、`examples/p02_restrict_note.c`
