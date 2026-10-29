# jsperf rule ids (slugs)

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

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
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

See also [root rule-id-map](../../../docs/rule-id-map.md).
