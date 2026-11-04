# zp-static-string-map — 静态字符串映射

## 主张

在这台 Linux 机器上，Zig **0.17.0** 使用 `-Ofast` 时，StringHashMap.get 与 StaticStringMap.get（字面键）显示出明显的前后实时时钟差距。

## 如何测量

- 测试套件：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-static-string-map` 的用例）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9 轮的中位数**
- **之前：** `string_hashmap_get`
- **之后：** `static_string_map_get`
- 操作次数=200000
- 原始数据：[ `zp-static-string-map.jsonl`](../zp-static-string-map.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~1.515 ms |
| Median after | ~0.5995 ms |
| **前/后比例** | **~2.53×** |

## 与 lint 的对应

`zperf-lint` `zp-static-string-map` / `static-string-map`。`rules.zig` 中的默认严重性为 **信息**；有关保留/升级，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在且在方向上 **一致**。

## 结论

同意 ~2.53× 查找；静态也没有运行时分配/初始化。

## 限制

仅当一个函数中有≥3个字面量的 put 时才触发。
