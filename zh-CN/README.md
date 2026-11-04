# XPerf

跨语言的**性能味道**检查：同一 playbook，按语言分成 kit，每条规则都要经得起测量。

文档站：[guides](../docs/) · 语言 kit：[packages](../packages/) · 快速上手：[quickstart](../docs/zh-CN/quickstart.md) · kit 状态：[kits](../docs/zh-CN/kits.md)。

## 这是什么

XPerf 是伞形仓库。每个 kit（如 `jsperf`、`cperf`、`zperf`）提供：

- 该语言的性能指南（从 `docs/guide-src/` 组装）
- 行窗启发式 lint（`*-lint`）
- 带 JSONL 的证据笔记（墙钟 before/after）
- 语料 dogfood 说明（树不 vendored）

主张须有本地基准、上游来源，或标为暂定。语料 lint 计数是启发式 dogfood，不是基准。

## 从哪开始

1. 读 [overview](../docs/zh-CN/overview.md) 与 [playbook](../docs/zh-CN/playbook.md)。
2. 打开你语言的 kit：`packages/<kit>/`。
3. 按 [quickstart](../docs/zh-CN/quickstart.md) 跑 lint。
4. 把发现当评审提示；用 `evidence/` 与真实 profile 再定是否重写。

## 许可

见 [LICENSE](../LICENSE) 与 [NOTICE](../NOTICE)。行为准则：[CODE_OF_CONDUCT](CODE_OF_CONDUCT.md)。贡献：[CONTRIBUTING](CONTRIBUTING.md)。安全：[SECURITY](SECURITY.md)。
