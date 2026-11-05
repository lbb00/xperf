# jp-string-concat-hot — 循环中的字符串拼接 (`+=` / `s = s + …`)

## 主张

在循环中使用 `+=`（或 `s = s + x`）进行热 `String` 拼接比在 HotSpot 上使用 `StringBuilder`（特别是预设大小的）要慢得多且分配更多。原因是重复的不变 `String` 分配/复制——而不是 C2 “失败”。

## 如何测量

- Harness:`jmh-benches/./J23 StringConcat.java ' 通过`scripts/run jmh.sh J23 StringConcat'
- 工作:装配`零件 ' 固定碎片;JMH 1.37 avgt +`-prof gc ' ;`-XX:+ 使用对象头 '
- ** 在:** " 附加量 " 之前
- ** 之后:** " 钢筋建造厂 " (也记录为 " 钢筋建造厂 " )
- 原始研究线:`研究/成果/J23-StringConcat.jsonl'
- 兄妹关系:延长STATIC-VS-HOTSPOT与这对阅读(空间/时间是)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海 |
| JDK | **27 (27+35)** |
| JVM 参数 | `-XX:+UseCompactObjectHeaders` |
| 在 `plusEquals[parts=256]` 之前 | **69754.657 纳秒/操作**, **141296.445 字节/操作** |
| 在 `stringBuilderPresized[parts=256]` 之后 | **3278.274 ns/次操作**, **2104.021 B/次操作** |
| **前/后比率** | **约 21.3×** 时间，**约 67×** 每操作字节 |
| parts=64（相同的 JSONL）| plusEquals **1043.665** → SB 预置 **628.989** → **~1.66×** 时间 |

## 与 lint 的对应

`jvmperf-lint` jp-string-concat-hot (`string-concat-in-loop`)。根据 [evidence-policy](../../docs/zh-CN/evidence-policy.md) 政策，严重性为 **错误**。

## 限制

- 一次性/罕见路径：墙上时钟通常无关紧要。
- Java 9+ `invokedynamic` 拼接有助于 **表达式** 树；**循环携带** 的 `+=` 仍然会重建。
- 不要将其等同于 HotSpot 的去优化。
