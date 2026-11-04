# swiftperf 语料库目标

大型树木**不是**经过供应的，并且语料库不会随仓库一起分发：将其克隆到仓库之外的任何本地目录，并将该路径传递给代码检查器。

## 固定目标

浅层克隆，2026-10-22 亚洲/上海。

| 树 | 提交 | Lint r3 → r4 重新设计 | 备注 |
|------|--------|----------------------|-------|
| **swift-nio** | `108daca` `https://github.com/apple/swift-nio.git` | 16 → **20** | sp-array-no-reserve/sp-map-joined-chain |
| **Alamofire** | `bda9ed5` `https://github.com/Alamofire/Alamofire.git` | 1 → **6** | ParameterEncoding sp-map-joined-chain TP |
| **swift-argument-parser** | `efd239f` `https://github.com/apple/swift-argument-parser.git` | 21 → **6** | 使用/工具/自动完成已跳过 |

**注意（2026-10-22）：** 没有 `swift` 工具链。G0–G3 使用 [`scripts/text-lint.cjs`](../../scripts/text-lint.cjs)（与 SPM 源代码启发式一致）。安装 Swift 5.9+ 以构建 `swiftperf-lint` 并重新验证。

**语料库就绪: 是** (r4 重新设计；文本校验一致性)。默认值: sp-array-no-reserve/sp-map-joined-chain **提示**；sp-force-unwrap-in-loop–sp-print-hot **关闭**。无 G4。

不要将语料库来源提交到 `packages/swiftperf`。

## 2026-10-23 — 新提示规则，未分类

下面的 slug 是 **提示**。每个都有一个 JSONL 微基准测试，并且尚未经过 G2/G3。2026-10-22 可用于语料库的裁定不包括它们。

- `sp-date for matter-hot ' 、`sp-json-decode-hot ' 、`sp-regex-hot '
