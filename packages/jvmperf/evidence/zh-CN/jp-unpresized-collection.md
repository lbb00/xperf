# jp-unpresized-collection — 无预设大小的集合填充

## 主张

在没有初始容量的情况下填充 `ArrayList`（或类似的集合）会分配更多内存，并且通常比已知 `n` 时的 `new ArrayList(n)` 略慢。在这台机器上，**时间**陡峭下降 **较为轻微**；而 **B/op** 的差异更为明显。

## 如何测量

- 测试框架：`J25_Presize.java` / `scripts/run_jmh.sh J25_Presize`
- **之前：** `growFromDefault[n=10000]`
- **之后：** `presized[n=10000]`
- 原始数据：`J25_Presize.jsonl`
- 相关性：STATIC-VS-HOTSPOT 案例 2 **部分**

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海 |
| JDK | **27 (27+35)** |
| JVM 参数 | `-XX:+UseCompactObjectHeaders` |
| before n=10k | **117725.103 ns/op**, **326832.742 B/op** |
| after n=10k | **82357.177 ns/op**, **197992.522 B/op** |
| **ratio** | **~1.43×** time, **~1.65×** B/op |
| n=100k（相同 JSONL） | ~**1.37×** 时间，~**1.44×** 每操作字节 |

## 与 lint 的对应

默认严重性 **关闭**（使用 `--enable` 运行；部分实际时间）。证据文件存在，因此该声明是可审计的；不要将每一个 jp-unpresized-collection 语料库的命中都视为必须修复的速度漏洞。

## 限制

- 最终大小未知 → 无法总是预先确定尺寸；构建器上常见 FP。
- 在 lint 反向优化轮之后，语料残余仍然升高 — 在升级为 `error` 之前进行分类处理。
