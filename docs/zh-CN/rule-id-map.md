# 规则 ID 映射（历史 — 数字 → 标识名）

**别名尚未实现。** 规范 ID 仅为 **语义标识符**。此文件是 2026-10-22 重命名的一次性迁移参考；CLI **不**接受左侧的数字代码。

已移除的 ID（jitter 2026-10-22）**没有 slug**，不得重复使用：`CX001`、`CX003`、`CX004`、`BE002`、`KT004`、`OC001`、`OC004`、`PP004`。


## arktsperf

| Old | Slug |
|-----|------|
| `AT001` | `at-alloc-hot` |
| `AT002` | `at-object-delete` |
| `AT003` | `at-console-hot` |
| `AT004` | `at-includes-hot` |
| `AT005` | `at-json-hot` |

## 光束性能

| Old | Slug |
|-----|------|
| `BE001` | `be-list-concat-reduce` |
| `BE003` | `be-io-puts-hot` |
| `BE004` | `be-map-merge-hot` |
| `BE005` | `be-enum-map-filter-chain` |

已移除（仅碑文）：
- `BE002`

## cperf

| Old | Slug |
|-----|------|
| `CP001` | `cp-alloc-hot` |
| `CP002` | `cp-realloc-grow-one` |
| `CP003` | `cp-printf-hot` |
| `CP004` | `cp-strlen-in-cond` |
| `CP005` | `cp-strcat-hot` |

## cppperf

| Old | Slug |
|-----|------|
| `CX002` | `cx-string-append-unreserved` |

已移除（仅墓碑）：
- `CX001`
- `CX003`
- `CX004`

## csharp性能

| Old | Slug |
|-----|------|
| `CS001` | `cs-list-add-no-capacity` |
| `CS002` | `cs-字符串-加-热` |
| `CS003` | `cs-console-hot` |
| `CS004` | `cs-regex-hot` |

## dartperf

| Old | Slug |
|-----|------|
| `DT001` | `dt-list-add-empty` |
| `DT002` | `dt-字符串-加-热` |
| `DT003` | `dt-print-hot` |
| `DT004` | `dt-growable-add-empty` |

## goperf

| Old | Slug |
|-----|------|
| `GP001` | `gp-make-hot` |
| `GP002` | `gp-字符串-加-热` |
| `GP003` | `gp-fmt-hot` |
| `GP004` | `gp-append-nil-slice` |
| `GP005` | `gp-defer-hot` |

## jsperf

| Old | Slug |
|-----|------|
| `JP001` | `jp-alloc-hot` |
| `JP002` | `jp-console-hot` |
| `JP003` | `jp-delete-shape` |
| `JP004` | `jp-删除数组空洞` |
| `JP005` | `jp-string-plus-in-loop` |
| `JP006` | `jp-地图-过滤-链` |

## jvm性能

| Old | Slug |
|-----|------|
| `JP001` | `jp-封装原始集合` |
| `JP002` | `jp-string-concat-hot` |
| `JP003` | `jp-regex-hot` |
| `JP004` | `jp-format-hot` |
| `JP005` | `jp-unpresized-collection` |
| `JP006` | `jp-boxed-stream` |
| `JP007` | `jp-异常控制流` |
| `JP008` | `jp-legacy-synchronized-type` |
| `JP009` | `jp-多布尔字段` |
| `JP010` | `jp-枚举-键-哈希-集合` |
| `JP011` | `jp-collection-chain` |
| `JP012` | `jp-value-class-boxing` |
| `JP013` | `jp-lambda-to-non-inline-hot` |
| `JP014` | `jp-lazy-default-mode` |
| `JP015` | `jp-数据-复制-热` |
| `JP016` | `jp-android-sparse-array` |
| `JP017` | `jp-log-hot` |
| `JP018` | `jp-sleep-polling` |
| `JP019` | `jp-finalize` |
| `JP020` | `jp-昂贵-分配-热点` |
| `JP021` | `jp-hot-heavy-alloc` |
| `JP022` | `jp-hot-format-log` |
| `JP023` | `jp-热点系统调用` |
| `JP024` | `jp-位图解码-禁止重用` |
| `JP025` | `jp-hot-post-lambda` |
| `JP026` | `jp-ui-text-append` |
| `JP027` | `jp-baos-tobytearray-copy` |
| `JP028` | `jp-hot-payload-copy` |
| `JP030` | `jp-客户端-工厂-重建` |
| `JP031` | `jp-string-intern-hot` |
| `JP032` | `jp-非静态字段更新器` |

## kotlin性能

| Old | Slug |
|-----|------|
| `KT001` | `kt-list-add-hot` |
| `KT002` | `kt-字符串-加-热` |
| `KT003` | `kt-println-hot` |

已移除（仅保留墓碑）：
- `KT004`

## luaperf

| Old | Slug |
|-----|------|
| `LU001` | `lu-table-insert-hot` |
| `LU002` | `lu-string-concat-hot` |
| `LU003` | `lu-print-hot` |

## nimperf

| Old | Slug |
|-----|------|
| `NM001` | `nm-seq-add-hot` |
| `NM002` | `nm-string-amp-in-loop` (**已删除**, 墓碑) |
| `NM003` | `nm-echo-hot` |
| `NM004` | `nm-seq-no-capacity` |

## objcperf

| Old | Slug |
|-----|------|
| `OC002` | `oc-nsstring-append-热` |
| `OC003` | `oc-nslog-hot` |

已移除（仅墓碑）：
- `OC001`
- `OC004`

## phpperf

| Old | Slug |
|-----|------|
| `PH001` | `ph-字符串-点-热` |
| `PH002` | `ph-数组-合并-重新绑定` |
| `PH003` | `ph-echo-hot` |

## pyperf

| Old | Slug |
|-----|------|
| `PP001` | `pp-str-plus-hot` |
| `PP002` | `pp-list-plus-rebind` |
| `PP003` | `pp-print-hot` |

已移除（仅保留墓碑）：
- `PP004`

## rubyperf

| Old | Slug |
|-----|------|
| `RB001` | `rb-字符串-加-热` |
| `RB002` | `rb-array-plus-rebind` |
| `RB003` | `rb-puts-hot` |
| `RB004` | `rb-hash-merge-in-loop` (**已移除**, 墓碑) |

## rustperf

| Old | Slug |
|-----|------|
| `RS001` | `rs-alloc-hot` |
| `RS002` | `rs-string-plus-in-loop` |
| `RS003` | `rs-println-hot` |
| `RS004` | `rs-格式-重新绑定-热` |
| `RS005` | `rs-vec-no-capacity` |
| `RS006` | `rs-collect-vec-hot` |

## swiftperf

| Old | Slug |
|-----|------|
| `SP001` | `sp-force-unwrap-in-loop` |
| `SP002` | `sp-string-plus-in-loop` |
| `SP003` | `sp-print-hot` |
| `SP004` | `sp-array-no-reserve` |
| `SP005` | `sp-map-joined-chain` |

## zperf

| Old | Slug |
|-----|------|
| `ZP001` | `zp-alloc-hot` |
| `ZP002` | `zp-append-without-reserve` |
| `ZP003` | `zp-页面分配器-小` |
| `ZP004` | `zp-debug-allocator` |
| `ZP005` | `zp-大结构按值传递` |
| `ZP006` | `zp-print-hot` |
| `ZP007` | `zp-unbuffered-io` |
| `ZP008` | `zp-missing-free` |
| `ZP009` | `zp-extern-struct-填充` |
| `ZP010` | `zp-广义运行时安全` |
| `ZP011` | `zp-packable-bools` |
| `ZP012` | `zp-usize-索引-字段` |
| `ZP013` | `zp-aos-单字段` |
| `ZP014` | `zp-捕获-不可达-分配` |
| `ZP015` | `zp-超大枚举标签` |
| `ZP016` | `zp-可选标量字段` |
| `ZP017` | `zp-bool-array` |
| `ZP018` | `zp-静态字符串映射` |
| `ZP019` | `zp-runtime-div-hot` |
| `ZP020` | `zp-queue-ordered-remove` |
| `ZP021` | `zp-shift-on-read` |
| `ZP022` | `zp-每包分配` |
| `ZP023` | `zp-不变浮点除法` |
| `ZP024` | `zp-map-put-without-ensure` |
| `ZP025` | `zp-catch-unreachable-io` |
| `ZP026` | `zp-竞技场-重置-全部免费` |
| `ZP027` | `zp-创建-销毁-热` |
| `ZP028` | `zp-固定大小分配-热点` |


## 2026-10-27 作用域重命名（`*-in-loop` → `*-hot`）

默认匹配现在是 **`--scope all`**（也报告循环之外的情况）。包含 `in-loop` 的标识符已被 **重命名**，以使名称不再暗示仅循环作用域。旧的标识符已在每个工具包的 `evidence/_removed/*.REMOVED.md` 下作废，并且 **绝不能再次使用**。活动 ID 列在每个工具包的 `docs/rule-ids.md` 中。在工具包支持的情况下，可以选择 `--scope loop` 以匹配以前仅限循环的情形。

上面的数字 → slug 行保持了 **历史** 2026-10-22 的映射（许多目标在 2026-10-27 又被重新命名）。
