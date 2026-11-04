# jp-客户端-工厂-重建

## 主张

重新创建一个 HTTP 客户端工厂（`HttpClient.newHttpClient()`，类似于 OkHttpClient 等）相比重复使用代价非常高。

## 如何测量

- 来源：`J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**，JVM 参数 `-XX:+UseCompactObjectHeaders`
- 循环前调用了 `close()`，所以每个客户端都会释放其选择器。否则，JDK 27 会在迭代完成前达到进程文件描述符限制。
- **之前:** `HttpClient_newEach`
- **之后:** `HttpClient_reuse`

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海 |
| before | **81763.736** ns_per_op, **32558.095** B/op |
| after | **0.416** ns_per_op, **0.000** B/op |
| **前后比例** | **~1.97e5×** |

## Lint 映射 / 策略

策略 **错误** (~1.97e5× 对比重用，包括 `close()`；创建时约 32.6 KB/操作)。测试固定装置名称 OkHttp；使用 JDK HttpClient 作为真实的昂贵工厂进行测量。

## 限制

在这台机器上进行微基准测试；请参见 `scripts/run-static-vs-hotspot.sh`。不要随意编造比率。语料残差 ≠ 加速比。
