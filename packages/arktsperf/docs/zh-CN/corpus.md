# arktsperf 语料库目标

大型树木**不是**经过供应的，并且语料库不会随仓库一起分发：将其克隆到仓库之外的任何本地目录，并将该路径传递给代码检查器。

## 固定目标

截至2026-10-22（亚洲/上海）；真正的ArkTS树。

| 树 | 提交 / 来源 | Lint r2 → r3 重新设计 | 注释 |
|------|-----------------|----------------------|-------|
| **基本功能** | gitee `openharmony/applications_app_samples` `a826ab0e` `code/BasicFeature` | 29 → **22** | at-includes-hot, at-json-hot |
| **用户界面** | 同一代码库 `code/UI` | 13 → **8** | 包含热点 |
| **dimina-harmony** | 本地 Harmony/ArkTS 树（非供应商化；发布时固定 URL+提交） @ `cfd73f9914da1f417a4f1af62fa08b7642548f5d` | 6 → **26** | BASE64 at-includes-hot TP |

**语料库准备好：是**（r3 重新设计）。默认值：`at-includes-hot` 和 `at-json-hot` **提示**；其他三条规则 **关闭**。没有 G4。

不要将语料库来源提交到 `packages/arktsperf`。
