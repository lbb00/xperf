# nimperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `nm-seq-add-hot` |
| `nm-echo-hot` |
| `nm-seq-no-capacity` |

Removed: `nm-string-amp-in-loop` — see `evidence/_removed/`.

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `nm-echo-in-loop` | `nm-echo-hot` |
| `nm-seq-add-in-loop` | `nm-seq-add-hot` |
