# jvmperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `jp-boxed-primitive-collection` |
| `jp-string-concat-in-loop` |
| `jp-regex-in-loop` |
| `jp-format-in-loop` |
| `jp-unpresized-collection` |
| `jp-boxed-stream` |
| `jp-exception-control-flow` |
| `jp-enum-key-hash-collection` |
| `jp-collection-chain` |
| `jp-value-class-boxing` |
| `jp-lambda-to-non-inline-in-loop` |
| `jp-lazy-default-mode` |
| `jp-data-copy-in-loop` |
| `jp-android-sparse-array` |
| `jp-log-in-loop` |
| `jp-sleep-polling` |
| `jp-finalize` |
| `jp-expensive-alloc-in-loop` |
| `jp-hot-heavy-alloc` |
| `jp-hot-format-log` |
| `jp-hot-system-call` |
| `jp-bitmap-decode-no-reuse` |
| `jp-hot-post-lambda` |
| `jp-ui-text-append` |
| `jp-baos-tobytearray-copy` |
| `jp-hot-payload-copy` |
| `jp-client-factory-recreate` |
| `jp-string-intern-in-loop` |
| `jp-non-static-field-updater` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Removed (tombstone; never reuse)

- `jp-legacy-synchronized-type` — see `evidence/_removed/`
- `jp-many-boolean-fields` — see `evidence/_removed/`
