# cppperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `cx-regex-ctor-in-loop` |
| `cx-endl-in-loop` |
| `cx-clock-in-loop` |
| `cx-ifstream-in-loop` |
| `cx-const-by-value` |
| `cx-vector-bool` |

## Removed

- `cx-string-append-unreserved` — about 1.09× at `-O2`; see `evidence/_removed/`

## Removed (no slug)

- `CX001` — see `evidence/_removed/`
- `CX003` — see `evidence/_removed/`
- `CX004` — see `evidence/_removed/`

See also [root rule-id-map](../../../docs/rule-id-map.md).
