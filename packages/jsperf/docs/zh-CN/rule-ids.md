# jsperf 规则 ID（slug）

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `jp-alloc-hot` |
| `jp-console-hot` |
| `jp-delete-shape` |
| `jp-delete-array-hole` |
| `jp-map-filter-chain` |
| `jp-regex-ctor-hot` |
| `jp-json-hot` |
| `jp-dom-query-hot` |
| `jp-intl-datetimeformat-hot` |
| `jp-readfile-sync-hot` |
| `jp-clock-hot` |
| `jp-query-all-star` |
| `jp-execjs-in-timer` |
| `jp-clone-per-event` |

Matching scope defaults to **`--scope all`** (report everywhere). Opt in to **`--scope loop`** for the former in-loop-only match. Former `*-in-loop` slugs were renamed to `*-hot` (see Renamed below).

## 已重命名 2026-10-27 （墓碑化旧 ID；永不复用）

Default **`--scope all`** (or kit-equivalent). 旧的 `*-in-loop` ID 会误导工具/模型；它们被墓碑化在 `evidence/_removed/` 下。

| 旧 slug | 新 slug |
|----------|----------|
| `jp-alloc-in-loop` | `jp-alloc-hot` |
| `jp-clock-in-loop` | `jp-clock-hot` |
| `jp-console-in-loop` | `jp-console-hot` |
| `jp-dom-query-in-loop` | `jp-dom-query-hot` |
| `jp-intl-datetimeformat-in-loop` | `jp-intl-datetimeformat-hot` |
| `jp-json-in-loop` | `jp-json-hot` |
| `jp-readfile-sync-in-loop` | `jp-readfile-sync-hot` |
| `jp-regex-ctor-in-loop` | `jp-regex-ctor-hot` |

## Removed (tombstone; never reuse)

- `jp-string-plus-in-loop` — `push` + `join` was not ~2× on the matched shapes. See `evidence/_removed/`.

另见 [根目录 rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。
