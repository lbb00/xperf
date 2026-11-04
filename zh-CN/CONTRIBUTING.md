# 参与贡献

感谢帮助改进 **XPerf**。工作在 `packages/<kit>/`。保持共享闭环（代理看 [AGENT.md](AGENT.md)；人看 [docs/playbook.md](../docs/zh-CN/playbook.md)）：

1. 指南中的主张 → 可测量示例或引用的上游证据。
2. 仅在 **语料 ≥3** 且完成 **TP/FP triage**（AGENT G2–G3）后加 lint 规则；FP 率必须可接受。
3. Dogfood：检查器源码 + examples 在默认规则下保持干净；有意反模式放在 `fixtures/bad/`（或显式抑制）。
4. 仅在有成对夹具 **以及** before/after 证据 JSONL 时，才把规则升到默认 **error**（见 [docs/rule-regression.md](../docs/zh-CN/rule-regression.md) 与各 kit 的 `docs/evidence-policy.md`）。

跨语言味道指针：[docs/smell-catalog.md](../docs/zh-CN/smell-catalog.md)。
规则 ID 是**按 kit** 的 slug；jsperf 与 jvmperf 共享 `jp-` 前缀但 slug 集合不相交，引用 `jp-*` 规则时请点名 kit。

## 开 PR 之前

在仓库根目录运行：

```sh
bash scripts/sync-check.sh
bash scripts/sync-check.sh
bash scripts/doc-check.sh && bash scripts/build-guides.sh --check   # Markdown 或指南变更
bash scripts/doc-check.sh && bash scripts/build-guides.sh --check   # Markdown 或指南变更
bash scripts/privacy-check.sh --history
bash scripts/privacy-check.sh --history
```

然后构建/测试你改动的 kit。各语言命令：[docs/quickstart.md](../docs/zh-CN/quickstart.md)。Kit 默认：[docs/kits.md](../docs/zh-CN/kits.md)。

改 `site-app/` 或 `mkdocs.yml` 时的文档站：

```sh
bash scripts/build-pages.sh serve
bash scripts/build-pages.sh serve
```

**严重级别 / 退出码：** cperf 与 jsperf 遵守 preset。zperf 与 jvmperf 在 preset 落地前仍可能对任何发现让进程失败 —— 文档里升到 `error` 仍需要证据 JSONL（见各 kit 的 `docs/evidence-policy.md`）。

纯文档变更不需要每套工具链；在 PR 里说明你跑了什么。

**许可 / 贡献：** 根目录 [LICENSE](../LICENSE) 与本文件为准。不在包级重复 `LICENSE`。每个 kit 保留指向此处的短 `CONTRIBUTING.md` stub（以及有用时的一行 kit 检查）。

## PR 检查清单

- [ ] 改动的 kit 仍被 `scripts/sync-check.sh` 列为 `present`
- [ ] `bash scripts/privacy-check.sh --history` 通过（无私人姓名、地址、机器路径或仓库外引用；见 AGENT.md）
- [ ] 行为或严重级别变化时，更新指南 / README / 规则表
- [ ] 夹具：`bad/` 仍失败，`good/` 仍干净（或有文档化抑制）
- [ ] **没有证据 JSONL 就不要标 `error` 严重级别**（`packages/<kit>/evidence/<RULE>.jsonl`，或在 kit 证据策略 / rule-regression 登记的显式 skip stub `.md`）
- [ ] **PR 中不要带语料**（无 `*-corpus/`、无大型第三方树、无源码 `*.tar.gz`）。只在 `docs/corpus.md` 引用 URL + commit
- [ ] 证据 JSONL 保持小；不提交 regen 临时文件
- [ ] 语气：干练的技术中文（英文原文保持 dry technical English）

## 包布局检查清单（新 kit 或大改）

- `README.md`（MIT 仅在根 [LICENSE](../LICENSE) —— 不要把 LICENSE 拷进 kit）
- 指向本文件的短 `CONTRIBUTING.md` stub
- `docs/guide-src/`（或组装后的指南）在 `docs/` 下
- `docs/evidence-policy.md` 与 `docs/corpus.md`（仅引用）
- 小且可构建/可运行的 `examples/`
- 带 good/bad 夹具与短规则表的 `<kit>-lint/`
- 放 JSONL + 诚实 skip stub 的 `evidence/`

新 kit 遵循同一布局；规则从 **hint** 起步，仅通过 [AGENT.md](AGENT.md) 的 G3/G4 门禁升到 **off** 或 **error**。

## 不要提交什么

- 无命名基准或引用的营销文案或未经核实的「N× 更快」主张
- 完整研究语料或 Mac/用户磁盘同步 blob
- 公开 PR 中的密钥、凭据或私有通告内容（见 `SECURITY.md`）

## 行为与安全

- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [SECURITY.md](SECURITY.md)

## 变更日志

面向用户的变更：在 [CHANGELOG.md](CHANGELOG.md) 当前唯一章节下追加条目（或发版时开新的 SemVer 章节）。Kit 没有自己的版本；发布是仓库范围的 git 标签。不要复活数字规则 ID。

## 首次提交 / git 卫生

**应**跟踪：指南、lint 源码、夹具、小的 `evidence/*.jsonl` + skip stub、脚本、根 OSS 元数据（LICENSE、NOTICE、SECURITY、CoC、CI）。

**不得**提交（亦见 `.gitignore`）：

- `packages/*/lib/` 下的 `*.jar`（用 `packages/jvmperf/scripts/fetch-lib.sh` 拉取）
- 已构建的 ELF/Mach-O bench（如 `examples/bench/evidence_fill`）
- .NET `obj/`、`bin/Release/`、`bin/Debug/`、`*.pdb`、`*.dll`
- `packages/*/research/*.{log,txt}` 探测 dump
- `*-corpus/`、`*.tar.gz`、同步 blob
- `.claude/`（本地代理笔记）
- 把绝对机器路径当作唯一文档化位置 —— 优先仓库相对路径或环境变量 / CLI 参数

首次提交前干跑：`git add -n .`，确认体积只有源码（无多 MB jar 或二进制）。
