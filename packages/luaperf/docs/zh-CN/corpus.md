# luaperf 语料库目标

大型树木**不是**经过供应的，并且语料库不会随仓库一起分发：将其克隆到仓库之外的任何本地目录，并将该路径传递给代码检查器。

## 固定目标

浅克隆。

| 树 | 提交 | 大小 |
|------|--------|------|
| **kong** | `2103212` | 31M |
| **apisix** | `016dcd0` | 51M |
| **lua-resty-core** | `873d072` | 2.8M |

使用以下工具进行代码检查：

```sh
lua5.4 packages/luaperf/luaperf-lint/luaperf-lint.lua \
lua5.4 packages/luaperf/luaperf-lint/luaperf-lint.lua \
  <corpus-dir>/<name> --format json --no-fail
  <corpus-dir>/<name> --format json --no-fail
```

检查器是 **Lua 5.4**（`luaperf-lint`）。规则 lu-table-insert-hot–lu-print-hot（**lu-table-insert-hot 默认 `off`**；**lu-string-concat-hot 默认 `error`** 与 G4；lu-print-hot `hint` 与 G4）。

## 内部测试版：G3 r2 和 G4 r3 之后（2026-10-21 到 2026-10-22，亚洲/上海）

| Tree | baseline → r1 → r2 → **r3** |
|------|------------------------------|
| **kong** | 2475 → 75 → 19 → **11** (lu-string-concat-hot:10 lu-print-hot:1) |
| **apisix** | 560 → 198 → 26 → **23** (lu-string-concat-hot:23) |
| **lua-resty-core** | 13 → 0 → 0 → **0** |

**语料库准备好：是** — r3 样本 n=34：TP 73.5%，FP+DOC+SKIP 2.9%；在 lu-string-concat-hot 上的真实 TP；lu-string-concat-hot 错误有 G4（`evidence/lu-string-concat-hot.md`+`jsonl`）。lu-print-hot 有已测量的证据但保持提示。

### 反向优化

- 路径跳过：`spec/` `t/` `test(s)/` `example(s)/` `docs/` `benchmark(s)/` `.ci/` `autodoc/` `fixtures/` `vendor/` `cli/` `bin/` `scripts/`
- **lu-table-insert-hot 默认 `off`** — OpenResty/Lua `table.insert` 收集习惯用法
- lu-string-concat-hot：仅在 **标识符边界** 上累积（在 `ineligible_key` 内部不匹配中间标识符 `key`）
- lu-print-hot：仅裸 `print(`（不包括 `buffered_print` / `ngx_print`）

不要将语料库来源提交到 `packages/luaperf`。
