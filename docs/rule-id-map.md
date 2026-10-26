# Rule ID map (historical — numeric → slug)

**Aliases are not implemented.** Canonical ids are **semantic slugs only**. This file is a one-time migration reference from the 2026-10-22 rename; CLIs do **not** accept the left-hand numeric codes.

Removed ids (jitter 2026-10-22) have **no slug** and must not be reused: `CX001`, `CX003`, `CX004`, `BE002`, `KT004`, `OC001`, `OC004`, `PP004`.


## arktsperf

| Old | Slug |
|-----|------|
| `AT001` | `at-alloc-in-loop` |
| `AT002` | `at-object-delete` |
| `AT003` | `at-console-in-loop` |
| `AT004` | `at-includes-in-loop` |
| `AT005` | `at-json-in-loop` |

## beamperf

| Old | Slug |
|-----|------|
| `BE001` | `be-list-concat-reduce` |
| `BE003` | `be-io-puts-in-loop` |
| `BE004` | `be-map-merge-in-loop` |
| `BE005` | `be-enum-map-filter-chain` |

Removed (tombstone only):
- `BE002`

## cperf

| Old | Slug |
|-----|------|
| `CP001` | `cp-alloc-in-loop` |
| `CP002` | `cp-realloc-grow-one` |
| `CP003` | `cp-printf-in-loop` |
| `CP004` | `cp-strlen-in-cond` |
| `CP005` | `cp-strcat-in-loop` |

## cppperf

| Old | Slug |
|-----|------|
| `CX002` | `cx-string-append-unreserved` |

Removed (tombstone only):
- `CX001`
- `CX003`
- `CX004`

## csharpperf

| Old | Slug |
|-----|------|
| `CS001` | `cs-list-add-no-capacity` |
| `CS002` | `cs-string-plus-in-loop` |
| `CS003` | `cs-console-in-loop` |
| `CS004` | `cs-regex-in-loop` |

## dartperf

| Old | Slug |
|-----|------|
| `DT001` | `dt-list-add-empty` |
| `DT002` | `dt-string-plus-in-loop` |
| `DT003` | `dt-print-in-loop` |
| `DT004` | `dt-growable-add-empty` |

## goperf

| Old | Slug |
|-----|------|
| `GP001` | `gp-make-in-loop` |
| `GP002` | `gp-string-plus-in-loop` |
| `GP003` | `gp-fmt-in-loop` |
| `GP004` | `gp-append-nil-slice` |
| `GP005` | `gp-defer-in-loop` |

## jsperf

| Old | Slug |
|-----|------|
| `JP001` | `jp-alloc-in-loop` |
| `JP002` | `jp-console-in-loop` |
| `JP003` | `jp-delete-shape` |
| `JP004` | `jp-delete-array-hole` |
| `JP005` | `jp-string-plus-in-loop` |
| `JP006` | `jp-map-filter-chain` |

## jvmperf

| Old | Slug |
|-----|------|
| `JP001` | `jp-boxed-primitive-collection` |
| `JP002` | `jp-string-concat-in-loop` |
| `JP003` | `jp-regex-in-loop` |
| `JP004` | `jp-format-in-loop` |
| `JP005` | `jp-unpresized-collection` |
| `JP006` | `jp-boxed-stream` |
| `JP007` | `jp-exception-control-flow` |
| `JP008` | `jp-legacy-synchronized-type` |
| `JP009` | `jp-many-boolean-fields` |
| `JP010` | `jp-enum-key-hash-collection` |
| `JP011` | `jp-collection-chain` |
| `JP012` | `jp-value-class-boxing` |
| `JP013` | `jp-lambda-to-non-inline-in-loop` |
| `JP014` | `jp-lazy-default-mode` |
| `JP015` | `jp-data-copy-in-loop` |
| `JP016` | `jp-android-sparse-array` |
| `JP017` | `jp-log-in-loop` |
| `JP018` | `jp-sleep-polling` |
| `JP019` | `jp-finalize` |
| `JP020` | `jp-expensive-alloc-in-loop` |
| `JP021` | `jp-hot-heavy-alloc` |
| `JP022` | `jp-hot-format-log` |
| `JP023` | `jp-hot-system-call` |
| `JP024` | `jp-bitmap-decode-no-reuse` |
| `JP025` | `jp-hot-post-lambda` |
| `JP026` | `jp-ui-text-append` |
| `JP027` | `jp-baos-tobytearray-copy` |
| `JP028` | `jp-hot-payload-copy` |
| `JP030` | `jp-client-factory-recreate` |
| `JP031` | `jp-string-intern-in-loop` |
| `JP032` | `jp-non-static-field-updater` |

## kotlinperf

| Old | Slug |
|-----|------|
| `KT001` | `kt-list-add-in-loop` |
| `KT002` | `kt-string-plus-in-loop` |
| `KT003` | `kt-println-in-loop` |

Removed (tombstone only):
- `KT004`

## luaperf

| Old | Slug |
|-----|------|
| `LU001` | `lu-table-insert-in-loop` |
| `LU002` | `lu-string-concat-in-loop` |
| `LU003` | `lu-print-in-loop` |

## nimperf

| Old | Slug |
|-----|------|
| `NM001` | `nm-seq-add-in-loop` |
| `NM002` | `nm-string-amp-in-loop` (**removed**, tombstone) |
| `NM003` | `nm-echo-in-loop` |
| `NM004` | `nm-seq-no-capacity` |

## objcperf

| Old | Slug |
|-----|------|
| `OC002` | `oc-nsstring-append-in-loop` |
| `OC003` | `oc-nslog-in-loop` |

Removed (tombstone only):
- `OC001`
- `OC004`

## phpperf

| Old | Slug |
|-----|------|
| `PH001` | `ph-string-dot-in-loop` |
| `PH002` | `ph-array-merge-rebind` |
| `PH003` | `ph-echo-in-loop` |

## pyperf

| Old | Slug |
|-----|------|
| `PP001` | `pp-str-plus-in-loop` |
| `PP002` | `pp-list-plus-rebind` |
| `PP003` | `pp-print-in-loop` |

Removed (tombstone only):
- `PP004`

## rubyperf

| Old | Slug |
|-----|------|
| `RB001` | `rb-string-plus-in-loop` |
| `RB002` | `rb-array-plus-rebind` |
| `RB003` | `rb-puts-in-loop` |
| `RB004` | `rb-hash-merge-in-loop` (**removed**, tombstone) |

## rustperf

| Old | Slug |
|-----|------|
| `RS001` | `rs-alloc-in-loop` |
| `RS002` | `rs-string-plus-in-loop` |
| `RS003` | `rs-println-in-loop` |
| `RS004` | `rs-format-rebind-in-loop` |
| `RS005` | `rs-vec-no-capacity` |
| `RS006` | `rs-collect-vec-in-loop` |

## swiftperf

| Old | Slug |
|-----|------|
| `SP001` | `sp-force-unwrap-in-loop` |
| `SP002` | `sp-string-plus-in-loop` |
| `SP003` | `sp-print-in-loop` |
| `SP004` | `sp-array-no-reserve` |
| `SP005` | `sp-map-joined-chain` |

## zperf

| Old | Slug |
|-----|------|
| `ZP001` | `zp-alloc-in-loop` |
| `ZP002` | `zp-append-without-reserve` |
| `ZP003` | `zp-page-allocator-small` |
| `ZP004` | `zp-debug-allocator` |
| `ZP005` | `zp-large-struct-by-value` |
| `ZP006` | `zp-print-in-loop` |
| `ZP007` | `zp-unbuffered-io` |
| `ZP008` | `zp-missing-free` |
| `ZP009` | `zp-extern-struct-padding` |
| `ZP010` | `zp-broad-runtime-safety` |
| `ZP011` | `zp-packable-bools` |
| `ZP012` | `zp-usize-index-field` |
| `ZP013` | `zp-aos-single-field` |
| `ZP014` | `zp-catch-unreachable-alloc` |
| `ZP015` | `zp-oversized-enum-tag` |
| `ZP016` | `zp-optional-scalar-field` |
| `ZP017` | `zp-bool-array` |
| `ZP018` | `zp-static-string-map` |
| `ZP019` | `zp-runtime-div-in-loop` |
| `ZP020` | `zp-queue-ordered-remove` |
| `ZP021` | `zp-shift-on-read` |
| `ZP022` | `zp-per-packet-alloc` |
| `ZP023` | `zp-invariant-float-div` |
| `ZP024` | `zp-map-put-without-ensure` |
| `ZP025` | `zp-catch-unreachable-io` |
| `ZP026` | `zp-arena-reset-free-all` |
| `ZP027` | `zp-create-destroy-in-loop` |
| `ZP028` | `zp-fixed-size-alloc-in-loop` |
