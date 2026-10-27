# jvmperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `jp-boxed-primitive-collection` |
| `jp-string-concat-hot` |
| `jp-regex-hot` |
| `jp-format-hot` |
| `jp-unpresized-collection` |
| `jp-boxed-stream` |
| `jp-exception-control-flow` |
| `jp-enum-key-hash-collection` |
| `jp-collection-chain` |
| `jp-value-class-boxing` |
| `jp-lambda-to-non-inline-hot` |
| `jp-lazy-default-mode` |
| `jp-data-copy-hot` |
| `jp-android-sparse-array` |
| `jp-log-hot` |
| `jp-sleep-polling` |
| `jp-finalize` |
| `jp-expensive-alloc-hot` |
| `jp-hot-heavy-alloc` |
| `jp-hot-format-log` |
| `jp-hot-system-call` |
| `jp-bitmap-decode-no-reuse` |
| `jp-hot-post-lambda` |
| `jp-ui-text-append` |
| `jp-baos-tobytearray-copy` |
| `jp-hot-payload-copy` |
| `jp-client-factory-recreate` |
| `jp-string-intern-hot` |
| `jp-non-static-field-updater` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `jp-data-copy-in-loop` | `jp-data-copy-hot` |
| `jp-expensive-alloc-in-loop` | `jp-expensive-alloc-hot` |
| `jp-format-in-loop` | `jp-format-hot` |
| `jp-lambda-to-non-inline-in-loop` | `jp-lambda-to-non-inline-hot` |
| `jp-log-in-loop` | `jp-log-hot` |
| `jp-regex-in-loop` | `jp-regex-hot` |
| `jp-string-concat-in-loop` | `jp-string-concat-hot` |
| `jp-string-intern-in-loop` | `jp-string-intern-hot` |

## Removed (tombstone; never reuse)

- `jp-legacy-synchronized-type` — see `evidence/_removed/`
- `jp-many-boolean-fields` — see `evidence/_removed/`
