# 发布

## 我们发布什么

每次打 `v*` 标签，GitHub Actions 会构建一份 **源码分发**：

- 产物：`xperf-<tag>-packages.tar.gz`（例如：`xperf-v0.1.0-packages.tar.gz`）
- 内容：`packages/`、`docs/`、`site-app/`、`pages/`、`mkdocs.yml`、根文档（`README.md`、`LICENSE`、`NOTICE`、`AGENT.md`、`CONTRIBUTING.md`、`CHANGELOG.md`、`CODE_OF_CONDUCT.md`、`SECURITY.md`）以及 `scripts/`
- 校验和：`xperf-<tag>-packages.tar.gz.sha256`

语料不打进源码包。不含 bench 二进制。v0.1 不上传 npm / crates.io / Maven。

## 暂不发布的内容

| 类型 | 原因 |
|------|------|
| 全部 19 个 kit 的注册表 package | 工具链各异；没有统一二进制 |
| 每个 kit 的预编译 lint 二进制 | 支持路径是源码运行（Node/Make/Go/Zig/Gradle/Cargo/…） |

## 如何发版

1. 变更合入 `main`（CI 绿灯）。
2. 打标签：`git tag v0.1.0 && git push origin v0.1.0`
3. 工作流 [release.yml](../../.github/workflows/release.yml) 运行 `scripts/pack-source-dist.sh`，上传产物并创建 GitHub Release。

本地演练：`bash scripts/pack-source-dist.sh v0.1.0 /tmp/xperf-dist`

`workflow_dispatch` 可在不打新标签时重新打包。

## 文档站

GitHub Pages 从 `main` 构建指南。工作流：[pages.yml](../../.github/workflows/pages.yml)。源码包不含生成后的 HTML。

构建会把仓库名读进站点 URL（`https://<owner>.github.io/<repo>/`）。若仓库改名，请更新 README 链接。

本地预览：

```sh
bash scripts/build-pages.sh serve
bash scripts/build-pages.sh serve
```

打开 `http://localhost:3000/`。需要 Node.js 22+。命令会把 Markdown 复制到 `site-app/content`（已 gitignore）并启动文档应用。你打开的第一页会即时编译。

侧栏语言控件为 English / 中文。英文页在 `/`。中文页在 `/zh/`。没有中文译文的页面保持英文并会标明。

## CI 与发布

| 工作流 | 时机 | 任务 |
|--------|------|------|
| [ci.yml](../../.github/workflows/ci.yml) | PR / 推送到 main | 各 kit smoke/测试 + `sync-check` |
| [pages.yml](../../.github/workflows/pages.yml) | PR / 推送到 main | 文档站。推送到 `main` 还会部署 GitHub Pages |
| [release.yml](../../.github/workflows/release.yml) | `v*` 标签（或手动） | 源码包 + 校验和 → GitHub Release |
