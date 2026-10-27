# beamperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `be-list-concat-reduce` |
| `be-io-puts-hot` |
| `be-map-merge-hot` |
| `be-enum-map-filter-chain` |

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `be-io-puts-in-loop` | `be-io-puts-hot` |
| `be-map-merge-in-loop` | `be-map-merge-hot` |

## Removed (no slug)

- `BE002` — see `evidence/_removed/`

See also [root rule-id-map](../../../docs/rule-id-map.md).
