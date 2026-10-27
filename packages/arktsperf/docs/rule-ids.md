# arktsperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `at-alloc-hot` |
| `at-console-hot` |
| `at-includes-hot` |
| `at-json-hot` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `at-alloc-in-loop` | `at-alloc-hot` |
| `at-console-in-loop` | `at-console-hot` |
| `at-includes-in-loop` | `at-includes-hot` |
| `at-json-in-loop` | `at-json-hot` |

## Removed

- `at-object-delete` — Node proxy about 1.01×; see `evidence/_removed/`
