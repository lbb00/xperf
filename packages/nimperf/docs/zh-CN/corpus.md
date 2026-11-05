# nimperf 语料库目标

大型树木**不会**被供应，语料库也不会随仓库一起分发：将它克隆到仓库之外的任何本地目录，并将该路径传递给代码检查工具。
使用以下命令进行代码检查：

```sh
packages/nimperf/nimperf-lint/nimperf-lint \
  <corpus-dir>/<name> --format json --no-fail
```

检查器是 **Nim**（`nimperf-lint`），同语言。需要在 PATH 上有 `nim`（choosenim）。**nm-seq-add-hot–nm-echo-hot 默认 `off`**；**nm-seq-no-capacity 提示**。

## 固定目标

| 树 | URL | 提交 | 备注 |
|------|-----|--------|-------|
| Nim | https://github.com/nim-lang/Nim | `58130d2` | 浅拷贝; 41M |
| Arraymancer | https://github.com/mratsim/Arraymancer | `dcc220c` | 浅拷贝; 7.0M |
| nimbus-eth2 | https://github.com/status-im/nimbus-eth2 | `963756c` | 浅克隆；25M |

## 克隆的（2026-10-22）+ G3 重新设计

| Tree | r2 → r3 (defaults) |
|------|---------------------|
| **Nim** | 112 → **39** |
| **Arraymancer** | 17 → **2** |
| **nimbus-eth2** | 41 → **171** |

### 重新设计

- nm-seq-no-capacity：在有大小提示的循环中对空序列使用 `.add`；推荐使用 `newSeqOfCap`
- 跳过 `compiler/`；在 OK-idiom 占主导后，将 nm-seq-add-hot–nm-echo-hot 降级

不要将语料库来源提交到 `packages/nimperf`。
