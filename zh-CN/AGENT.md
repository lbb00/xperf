# AGENT.md — XPerf 代理操作合同

**受众:** 在此 monorepo 上工作的编码代理（以及操作它们的人员）。
**人工产品文档** 保存在 [README.md](README.md) 中。**不要**将 README 的简短循环视为完整 — 本文件是关于*如何必须完成工作* 的权威指南。

笔记的时区：**Asia/Shanghai**。语料库保存在仓库**外部**（每个工具包一个本地目录）——**绝不**放入 git、压缩包或发布档案中。

---

## 硬关（不可跳过）

套件更换**不会进行**，直到下面每个适用的关卡都是绿色。跳过关卡是流程错误，而不是节省时间的方法。

| 门 | 所需 | 完成表示 |
|------|----------------|------------|
| **G0 配对夹具** | 任何新/更改的规则 | `fixtures/bad` 报错；`fixtures/good` 清理；Smoke 断言两者 |
| **G1 自用测试** | 任何 lint 更改 | 检查器源代码 + 在 `--strict-hints`（以及默认预设）下清理 `examples/` |
| **G2 语料库 ≥3** | 支架→就绪，或规则形状变化 | ≥3 棵大型真实树固定在 `docs/corpus.md` 中（URL+提交）；转储在 `_lint-runs/` 下 |
| **G3 TP/FP 分流** | 每次语料库（重新）运行后 | 对残余样本进行抽样 + 分类；撰写分流备注；落实反向选项；**重新检查** |
| **G4 证据** | 将规则升级为默认 `error` | `evidence/<RULE>.md` + 测量的 `evidence/<RULE>.jsonl` — 永远不要编造比例 |
| **无证据测量** | 当一个测试结果显示逆向 / 空 / 未发现作用 ≥~2× 胜率 | **删除匹配器**（在 `evidence/_removed/` 下标记为垃圾）；**不要**保留僵尸 `off`。未测量规则可以保留提示/关闭状态。 |
| **G5 同步检查** | 伞 / 包装 | `bash scripts/sync-check.sh` 正常 |
| **G6 隐私** | **每一次** 更改（文档、脚本、示例、证据、提交信息） | `bash scripts/privacy-check.sh --history` 退出 0 — 参见 [隐私](#privacy-and-publication-hygiene) |
| **G7 文档** | 任何 Markdown 或指南更改 | `bash scripts/doc-check.sh` 和 `bash scripts/build-guides.sh --check` 返回 0；编辑 `guide-src`，而不是生成的指南 — 参见 [docs/doc-style.md](../docs/zh-CN/doc-style.md) |

**G3是强制性的。** 语料库原始计数和仅路径跳转的反向优化 **不** 满足G3。路径跳转后的发现仍然不可靠，直到经过分类处理。

### “语料库就绪” 的含义

只有在 G3 后 **所有条件** 都成立时，一个套件才可以称为 **语料库就绪**：

1. TRIAGE 注释存在，并带有标签（TP/FP/OK-idiom/DOC/SKIP-path）以及 before→after 计数。
2. 反向优化后，样本 FP+DOC+SKIP-path 占比 **≤ ~40%**。
3. 至少有一些残留是真实的 **TP**（而不是“所有都是 OK-idiom”）。
4. 没有 G4 的情况下默认 `error`。

如果 (2) 或 (3) 失败：说 **不适合语料库**，保持提示/`off`，不要声称有用。Scaffold + G3-complete ≠ 适合语料库。

---

## 隐私和出版卫生

此存储库是公开的：每个被跟踪的文件、提交信息和作者字段都会被公开。**G6 由 `scripts/privacy-check.sh` 强制执行（在 CI 中也一样）；只有通过运行才算有效。**

**绝不提交：**

1. 非公开的公司、产品、客户或主机名称。该列表**不在**此代码库中（放在这里会泄露信息）；它位于每个维护者的本地黑名单中（`$XPERF_PRIVACY_DENYLIST`，默认 `~/.config/xperf/privacy-denylist`）。新名称应先添加到那里。
2. 私有网络标识符：overlay-VPN / 运营商NAT地址和DNS名称、RFC1918地址、内部主机名。
3. 维护者机器的路径、用户名或绝对路径的默认值。路径应从脚本位置或被git忽略的库内目录推导；允许环境变量覆盖。
4. 代码库外的文件引用（研究笔记、分类笔记、lint转储、语料库）以及关于开发机器的叙述。要说明“语料库不分发；请本地克隆”。
5. 凭证，即使在示例中也不能。在证据文件中不保留机器特定数据（主机名、CPU型号字符串）；写作“x86-64 Linux，8核”即可。

**在每次提交之前：** 运行 `bash scripts/privacy-check.sh --history`，在源头修复命中项（重写；绝不削弱检测），并阅读正则无法识别的差异（真实姓名、粘贴的日志、内部 URL）。

**如果出现泄露情况：** 停止并告知维护者。后续的提交不会从历史中移除泄露内容；重写历史需要明确批准，泄露的凭证必须被撤销。然后将缺失的模式添加到脚本或拒绝列表中，并进行负面测试。

---

## 规则ID（语义标识符）

规范查找 ID 只是 **语义短标签**：使用kebab-风格，格式为 `{family}-{smell}`，例如 `at-includes-hot`、`gp-append-nil-slice`、`zp-alloc-hot`。

| Rule | Detail |
|------|--------|
| 字符集 | `[a-z][a-z0-9-]*`，最多约 40 个字符，不能有开头/结尾的连字符，不能有 `--` |
| 稳定性 | Slugs 是**永远有效**的。移除的 slug 会在 `evidence/_removed/`（和/或 `docs/rule-ids.md`）下留下一个墓碑；**绝不重复使用**一个 slug |
| 默认范围 | 支持 `--scope` 的工具包 / 工具包等效项默认设置为 **`all`**（也报告循环/热点路径外的内容）。对于前者仅循环匹配，可选择使用 **`--scope loop`**。查找文本不得暗示“仅在循环中修复”。 |
| 重命名（`*-in-loop` → `*-hot`）| 被重命名的标识符会永远保留在 `evidence/_removed/*.REMOVED.md` 下，并在每个工具包的 `docs/rule-ids.md` 重命名表中列出；**绝不复用**旧的标识符 |
| 数值 | **已移除。** 旧代码 (`AT004`、`GP001`、`ZP001` 等) 在 `--severity`、抑制、固定装置或发出的 `rule` 字段中 **不再** 被接受。无别名层。|
| 新规则 | 仅限 slug — **不要** 分配 `XX000` 编号 |
| 地图 | [docs/rule-id-map.md](../docs/zh-CN/rule-id-map.md) 和 `scripts/rule-id-map.json` 是一次性的**历史性**迁移参考（非活跃）。每个套件的 `docs/rule-ids.md` 列出了活跃的标识符。 |
| 移除 (2026-10-22 抖动) | 仅墓碑，从未获得子弹：`CX001`、`CX003`、`CX004`、`BE002`、`KT004`、`OC001`、`OC004`、`PP004` |
| 移除（2026-10-22 无证据门） | 测量-无用 → 墓碑+删除匹配器：`jp-legacy-synchronized-type`，`jp-many-boolean-fields`（别名从不重复使用） |

G0 smoke 必须断言 **slug** ID。G4 证据文件以 slug 命名（`evidence/<slug>.jsonl`）。

## 闭环（权威）

```mermaid
flowchart TB
flowchart TB
  claim["guide / smell claim"]
  claim["guide / smell claim"]
  claim --> g0["paired fixtures<br/>bad fires, good stays clean · G0"]
  claim --> g0["paired fixtures<br/>bad fires, good stays clean · G0"]
  g0 --> rule["same-language lint rule<br/>default severity: hint"]
  g0 --> rule["same-language lint rule<br/>default severity: hint"]
  rule --> g1["self-dogfood · G1"]
  rule --> g1["self-dogfood · G1"]
  g1 --> g2["corpus dogfood<br/>at least 3 projects, out of repo · G2"]
  g1 --> g2["corpus dogfood<br/>at least 3 projects, out of repo · G2"]
  g2 --> g3["TP / FP triage · G3"]
  g2 --> g3["TP / FP triage · G3"]
  g3 --> rev["reverse-opt<br/>re-lint delta, before to after"]
  g3 --> rev["reverse-opt<br/>re-lint delta, before to after"]
  rev --> off["demote to off<br/>when almost all OK-idiom"]
  rev --> off["demote to off<br/>when almost all OK-idiom"]
  off --> g4["measured JSONL<br/>before escalating to error · G4"]
  off --> g4["measured JSONL<br/>before escalating to error · G4"]
  g4 --> reg["registries and corpus.md"]
  g4 --> reg["registries and corpus.md"]
```

残留语料计数是**审查提示**，绝不是速度声明。启发式火力 ≠ 有用。

支持人工文档: [docs/playbook.md](../docs/zh-CN/playbook.md), [docs/overview.md](../docs/zh-CN/overview.md), [docs/rule-regression.md](../docs/zh-CN/rule-regression.md).

---

## G3 — TP/FP 分诊（如何）

### 样本量

根据语料树，在路径跳过基线（或最新的 rN 转储）之后：

- 如果发现数 **≤ 40**：对 **全部** 进行分类。
- 如果发现数 **> 40**：对 **≥ 40 的分层样本** 进行分类，尽可能每个触发的规则 ID 至少覆盖两次。
- 当 **20% 的发现 > 80** 时，可以将分层样本上限设置为 **~80**（每条规则仍需 ≥2），完整的 20% 是可选的，而非强制。将上限记录在 TRIAGE 中。
- 优先选择热点路径 / 库核心代码而非测试（测试应已被跳过；如果未跳过，先修复跳过然后再重新采样）。

### 标签（必填）

| Label | Meaning |
|-------|---------|
| **TP** | 真实气味；修复可能有助于热或分配敏感的路径 |
| **FP** | 检查器错误（不在循环中，已预留/容量已满，错误的 API，宏/文档等） |
| **OK-成语** | 符合模式但为刻意 / 冷静 / 框架正确 — 保留提示或抑制形式 |
| **DOC** | Doctest / `@doc` 示例 / 注释 / 字符串 — 不得触发 |
| **SKIP-path** | 应该被路径策略排除 |

记录：`路径:行数`，规则ID，标签，一行原因。将完整的分类注释放在语料库旁边（在仓库外），并在 `packages/<kit>/docs/corpus.md` 中总结（误报主题 + 已落地的修复）。

### 分诊后

1. 采用反向选择的方法消除导致 **FP** / **DOC** / 系统性 **OK-idiom** 噪声的情况（路径跳过、AST/启发式收紧、允许列表）。
2. 为你修复的每个 FP 类添加 **good** 测试用例。
3. 重新运行 smoke + 自检 lint + 语料库；发布前后对照表。
4. 保留真实的 **TP** 残留作为提示，直到存在 **G4** 证据——不要大规模升级。
5. 如果某条规则的样本在成熟库中几乎全部是 **OK-idiom**：**将默认设置降级为 `off`**（或缩小模式匹配范围）并记录原因——这是必需的 G3 结果，而非可选优化。

### 停止 / 升级

- 如果样本中 FP+DOC+SKIP-path 的比例 **> ~40%**，不要称该工具包为“语料库就绪”；保持反向选择。
- 如果反向选择后几乎全部是 OK-idiom：降级/`off` — 不要假装有用。
- **语料库就绪** 定义：见“硬门槛”下的框。

---

## 新套件清单

1. 在 `packages/<name>/` 下搭建脚手架（与同级目录布局相同）：使用 **相同语言** 的 lint，**kit-local** 规则 ID（如 `nm-seq-add-hot`、`gp-make-hot` 等——不是共享的全局命名空间），README，证据存根（仅 md；**不**使用假 JSONL），配对的测试数据，`scripts/smoke-lint.sh` + `self-lint.sh`。
2. **连接伞式结构（所有这些）：**
   - 根目录 [README.md](README.md) 的包表行
   - `scripts/sync-check.sh` — 包括 `case` 分支 **和** scaffold 的 `for p in …` 列表
   - `.github/workflows/ci.yml` 的 smoke 作业（如果工具链特殊，`continue-on-error: true` 可接受）
   - `.github/pull_request_template.md` 复选框
   - [docs/smell-catalog.md](../docs/zh-CN/smell-catalog.md) 的 kit 行 + smell 矩阵存根
   - [docs/rule-regression.md](../docs/zh-CN/rule-regression.md) 规则表
   - [CHANGELOG.md](CHANGELOG.md) 的 `[Unreleased]` / 未发布条目
3. 在声称完成自家测试前，需在 ≥3 个语料库上运行 **G0–G3**。仅在升级时运行 G4。
4. 切勿在包的归档或同步中包含研究语料库。

### 选择语料库（G2）

- 优先选择**知名的生产级**项目树（语言标准库/编译器、流行框架、大型应用）。
- 小众语言：如果编译器/标准库 + **两个**广泛使用的库每个都有大量 `.ext` 源码是可以接受的（目标是**数百个文件**或明显的“大型”项目——不要为了凑“3”而编造小型示例仓库）。
- 在 `docs/corpus.md` 中固定**URL + 提交**（或浅层 `rev-parse --short`）及大小。
- 浅克隆（`git clone --depth 1`）是可以的。

---

## 缺少工具链 / G1 自我击中

1. ** 同一语文的油漆仍然是船只的目标。 ** 如果此机器缺少编译器/ SDK, 请不要 ** 跳过 G0 - G3 :
- 保持配对固定装置+烟雾,说明火灾情况/干净。
- 有记录的静脉-平反**(语言适当:例如`crips/text-lint.cjs ' 、Python镜像等)可产生G2/G3和固定烟雾。 在“Docs/corp.md”和“TRIAGE”中这样说。
- 在有真正工具链的情况下,用真正的工具链重新运行烟雾/自林;不声称没有二进制/SDK验证。
2. **G1自犬食品:** 检查来源必须在 " 严格物品 " 下保持清洁。
- 倾向于**重写**呼叫站点(`setLen ' /索引写作/`stdout.writeLine'而不是`echo ' /`print ' in rops),而不是削弱规则。
- ** 不要**将规则的对应标志(例如,下弦`.add(`)')放在检查器来源的`for ' /`while ' 身体内——这是自我打击,而不是实体FP类。
- 固定规则(数字XQ,API允许列表)+**好**固定装置是好的;不要削弱烟雾。
3. 一种方法名称为多种类型服务的语言(如`seq ' 上的Nim`add ' **和**`string ' 或宏`NimNode.add ' )在G3之后需要**特定语言的抑制**——TRIAGE文件。
4. ** 公司准备就绪** 仍然需要硬门下的定义。

---

## README 保留的内容 vs 这个文件

| Topic | Where |
|-------|--------|
| 软件包表、许可、如何运行代码检查工具 | [README.md](README.md) |
| 代理闭环，G0–G7，TP/FP 协议，隐私规则 | **此文件** |
| 人类操作叙述 | [docs/playbook.md](../docs/zh-CN/playbook.md)（此处为关卡评分点） |

当 README 和 AGENT.md 在流程上有分歧时，**以 AGENT.md 为准**。

---

## 诚实为本

- 永远不要编造基准数或 JSONL 比例。
- 永远不要提交语料库克隆、lint 转储或分类笔记；它们应保持在仓库之外。
- 永远不要仅通过读取文件声称 G6；只有运行 `scripts/privacy-check.sh --history` 并通过才算。
- 当证据缺失时，应说 **待定**。
- 测试通过 ≠ 墙钟声称。
- `OSS_READY` / “在真实代码中有用” / **语料库就绪** 都需要符合上述定义的 G3 分类笔记。
