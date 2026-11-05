# beamperf 语料库目标

大型树木**不会**被供应，语料库也不会随仓库一起分发：将它克隆到仓库之外的任何本地目录，并将该路径传递给代码检查工具。
使用以下命令进行代码检查：

```sh
elixir packages/beamperf/beamperf-lint/beamperf_lint.exs \
  <corpus-dir>/<name> --format json --no-fail
```

检查器是 **Elixir/Erlang** (`beamperf-lint`)。规则：全部四条（见 [rule-ids.md](rule-ids.md)）。扫描 `.ex` / `.exs` / `.erl` 文件。

## 固定目标

克隆于 2026-10-21（亚洲/上海）。

| 树 | 提交 | 大小 | Lint (r2 → r3 重新设计) |
|------|--------|------|-------------------------|
| **elixir** | `aad5397` 浅 `https://github.com/elixir-lang/elixir.git` | 22M | **1 → 4** (be-map-merge-hot:3 be-enum-map-filter-chain:1) |
| **凤凰** | `e5880ef` 浅 `https://github.com/phoenixframework/phoenix.git` | 7.6M | **0 → 0** |
| **牛仔** | `6475600` 浅 `https://github.com/ninenines/cowboy.git` | 11M | **0 → 0** |

路径跳过: `test(s)/`、`example(s)/`、`docs/`、`benchmark(s)/`、`_build/`、`deps/`、`fixtures/`、`tmp/`、`scripts/`、`iex/`、`integration_test/`。

## G3 TP/FP 分诊 (2026-10-22 亚洲/上海)

| | r1 n=70 | r2 n=1 | **r3 n=4** |
|--|---------|--------|------------|
| TP | 4.3% | 100% | **75%** |
| FP+DOC+SKIP | **64.3%** | 0% | **0%** |
| OK-idiom | 31.4% | 0% | 25% |

**语料库准备好了吗？`yes`**（r3 重新设计）。默认值：`be-list-concat-reduce`、`be-map-merge-hot` 和 `be-enum-map-filter-chain` **提示**；`be-io-puts-hot` **关闭**。无 G4 / 无默认 `error`。

### 重新设计（`beamperf-lint`）
- be-io-puts-hot → **关闭**（BE002 已弃用）；be-map-merge-hot merge-in-loop；be-enum-map-filter-chain 枚举链；Erlang `Acc ++ [` 无循环头
- Elixir `%{}` 不再被视为 Erlang `%` 注释
