# cppperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `cx-regex-ctor-hot` |
| `cx-endl-hot` |
| `cx-clock-hot` |
| `cx-ifstream-hot` |
| `cx-const-by-value` |
| `cx-vector-bool` |

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `cx-clock-in-loop` | `cx-clock-hot` |
| `cx-endl-in-loop` | `cx-endl-hot` |
| `cx-ifstream-in-loop` | `cx-ifstream-hot` |
| `cx-regex-ctor-in-loop` | `cx-regex-ctor-hot` |

## Removed

- `cx-string-append-unreserved` — about 1.09× at `-O2`; see `evidence/_removed/`

## Removed (no slug)

- `CX001` — see `evidence/_removed/`
- `CX003` — see `evidence/_removed/`
- `CX004` — see `evidence/_removed/`

See also [root rule-id-map](../../../docs/rule-id-map.md).
