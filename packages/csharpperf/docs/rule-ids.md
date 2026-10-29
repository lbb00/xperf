# csharpperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `cs-list-add-no-capacity` |
| `cs-string-plus-hot` |
| `cs-console-hot` |
| `cs-regex-hot` |
| `cs-linq-materialize-hot` |
| `cs-format-hot` |
| `cs-json-hot` |
| `cs-file-read-hot` |
| `cs-clock-hot` |
| `cs-field-by-name-hot` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `cs-clock-in-loop` | `cs-clock-hot` |
| `cs-console-in-loop` | `cs-console-hot` |
| `cs-field-by-name-in-loop` | `cs-field-by-name-hot` |
| `cs-file-read-in-loop` | `cs-file-read-hot` |
| `cs-format-in-loop` | `cs-format-hot` |
| `cs-json-in-loop` | `cs-json-hot` |
| `cs-linq-materialize-in-loop` | `cs-linq-materialize-hot` |
| `cs-regex-in-loop` | `cs-regex-hot` |
| `cs-string-plus-in-loop` | `cs-string-plus-hot` |
