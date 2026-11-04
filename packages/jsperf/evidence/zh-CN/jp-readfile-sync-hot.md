# jp-readfile-sync-hot — 已测量，仍然提示

## 状态
**提示**. 实时时钟 JSONL： [jp-readfile-sync-hot.jsonl](../jp-readfile-sync-hot.jsonl)。未进行语料库分流。2026-10-22 的语料库裁定不涵盖此标识。

## 测量
`fs.readFileSync` 对一个一字节文件进行 2000 次读取，与一次读取的比较。Node **v26.12.1** 在 Linux x64 上，负载 0.26。测试工具：`examples/bench/evidence_jp_readfile.js`。之前的 Node 24 对比约为 480×。

| 角色 | 情况 | 中位数毫秒 | 操作次数 | 比率 |
| --- | --- | ---: | ---: | ---: |
| 之后 | `read_once` | 0.041 | 2000 | 1 |
| 之前 | `read_each_iter` | 4.647 | 2000 | 114.417 |

该基准重新打开一个单字节文件。每次迭代都会变化的路径无法提升；测量的开销是打开和读取。默认保持 **hint**。这个比例不是普遍的加速。

## 匹配器

默认情况下，`--scope all` 会在路径看起来稳定的地方报告 `readFileSync`。在 `--scope loop` 下，只有 `{` 之后的循环体会匹配，因此 `for (const line of readFileSync(path).split("\n"))`（作为可迭代对象只读一次）不会被报告。作为循环绑定的路径（`files[i]`）也不会被报告。这个提示建议在路径稳定时只读取一次。

## 解除阻塞
不要仅仅从这个文件中将默认设置为 `error`。变化的输入、冷路径或其他 ABI 都可能抹去差异。在任何默认更改之前，仍然需要进行语料库分类处理。
