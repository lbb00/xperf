# phpperf 语料库目标

大型树木**不是**经过供应的，并且语料库不会随仓库一起分发：将其克隆到仓库之外的任何本地目录，并将该路径传递给代码检查器。

## 固定目标

浅克隆。

| 树 | 提交 | 大小 |
|------|--------|------|
| **framework** | `6107396` | 46M |
| **symfony** | `ad1bfbb2` | 181M |
| **composer** | `e7417e7` | 13M |

使用以下工具进行代码检查：

```sh
php packages/phpperf/phpperf-lint/phpperf-lint.php \
php packages/phpperf/phpperf-lint/phpperf-lint.php \
  <corpus-dir>/<name> --format json --no-fail
  <corpus-dir>/<name> --format json --no-fail
```

检查器是 **PHP 8+**（`phpperf-lint`）。规则 ph-string-dot-hot–ph-echo-hot（**ph-string-dot-hot 默认 `off`**；**ph-array-merge-rebind 默认 `error`** 与 G4；ph-echo-hot `hint`）。

## 内部测试：G3 r2 和 后 G4 r3（2026-10-21 至 2026-10-22，亚洲/上海）

| Tree | baseline → r1 → r2 → **r3** |
|------|------------------------------|
| **框架** | 65 → 59 → 48 → **25** (ph-array-merge-rebind:21 ph-echo-hot:4) |
| **symfony** | 796 → 636 → 393 → **47** (ph-array-merge-rebind:34 ph-echo-hot:13) |
| **作曲家** | 107 → 103 → 47 → **17** (ph-array-merge-rebind:17) |

**语料库就绪：是** — 在 ph-string-dot-hot 降级后，r3 n=89：TP 79.8%，FP+DOC+SKIP 0%；在 ph-array-merge-rebind 上的真实 TP；ph-array-merge-rebind 错误包含 G4（`evidence/ph-array-merge-rebind.md`+`jsonl`）。

### 反向优化

- 路径跳过：`test(s)/` `Tests/` `Fixtures/` `views/` `vendor/` `Tui/` `.github/` + 资源/bin 代码生成文件跳过
- **ph-string-dot-hot 默认 `off`** — 框架 `.=` 主要是冷构建器/解析器；使用 `--severity ph-string-dot-hot=hint` 进行审查
- ph-array-merge-rebind：仅 `$a = array_merge($a, …)` 增长重新绑定
- ph-echo-hot：掩码字符串；类似语句的 echo/print

不要将语料来源提交到 `packages/phpperf`。
