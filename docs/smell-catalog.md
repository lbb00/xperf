# XPerf cross-language smell catalog

**XPerf** umbrella map: the same *performance smell* across kits. Rule IDs are **per-kit** (not shared). A YES / measured ratio on one runtime does **not** transfer to another — re-bench before porting advice.

| Kit | Language | Lint IDs |
|-----|----------|----------|
| [zperf](../packages/zperf/) | Zig | zp-alloc-hot–zp-alloc-print-hot |
| [cperf](../packages/cperf/) | C | cp-alloc-hot–cp-struct-by-value |
| [jsperf](../packages/jsperf/) | JS/TS (V8) | jp-alloc-hot–jp-clone-per-event |
| [jvmperf](../packages/jvmperf/) | Java/Kotlin | 29 active `jp-*` slugs, `jp-boxed-primitive-collection`…`jp-non-static-field-updater` (see its `docs/rule-ids.md`; **≠** jsperf) |
| [goperf](../packages/goperf/) | Go | gp-make-hot–gp-time-now-hot |
| [pyperf](../packages/pyperf/) | Python | pp-str-plus-hot–pp-open-hot |
| [swiftperf](../packages/swiftperf/) | Swift | sp-array-no-reserve, sp-print-hot, plus sp-dateformatter-hot / sp-json-decode-hot / sp-regex-hot / sp-file-read-hot / sp-clock-hot / sp-value-for-key-hot |
| [arktsperf](../packages/arktsperf/) | ArkTS | at-alloc-hot–at-json-hot |
| [cppperf](../packages/cppperf/) | C++17 | `cx-regex-ctor-hot`, `cx-endl-hot`, `cx-clock-hot`, `cx-ifstream-hot`, `cx-const-by-value`, `cx-vector-bool` (string append and string-stream removed) |
| [csharpperf](../packages/csharpperf/) | C# | cs-list-add-no-capacity–cs-field-by-name-hot |
| [phpperf](../packages/phpperf/) | PHP | ph-string-dot-hot–ph-echo-hot |
| [rubyperf](../packages/rubyperf/) | Ruby | rb-string-plus-hot–rb-file-read-hot |
| [rustperf](../packages/rustperf/) | Rust | rs-alloc-hot–rs-clock-hot (`rs-map-new-hot` restored, about 1.5×) |
| [kotlinperf](../packages/kotlinperf/) | Kotlin | `kt-list-add-hot`–`kt-println-hot` (empty-add removed) |
| [objcperf](../packages/objcperf/) | Objective-C | `oc-nsstring-append-hot` / `oc-nslog-hot` (both off), plus `oc-dateformatter-hot` / `oc-json-hot` / `oc-regex-hot` / `oc-file-read-hot` / `oc-clock-hot` / `oc-value-for-key-hot` (array-add removed) |
| [dartperf](../packages/dartperf/) | Dart | dt-list-add-empty–dt-growable-add-empty |
| [luaperf](../packages/luaperf/) | Lua | lu-table-insert-hot–lu-print-hot |
| [beamperf](../packages/beamperf/) | Elixir + Erlang | be-list-concat-reduce–be-enum-map-filter-chain |
| [nimperf](../packages/nimperf/) | Nim | nm-seq-add-hot–nm-seq-no-capacity |

**Prefix overlap:** jsperf and jvmperf both use the `jp-` prefix, with disjoint slug sets. For example `jp-boxed-primitive-collection` (~5.96×) exists only in jvmperf, and `jp-alloc-hot` (~19×, off under the app preset) only in jsperf. Always name the kit when citing a `jp-*` rule.

---

## How to read

1. Pick a **smell** → open each kit’s rule + `packages/<kit>/evidence/<ID>.md` before treating a finding as a speed claim.
2. **Evidence** column cites ratios already in evidence-policy / JSONL / STATIC-VS-* — **not invented here**.
3. Cells:
   - rule id + short note = shipped lint (or guide example)
   - **n/a** = runtime physics differ; do not force a mapping
   - **pending** = rule or stub exists; no honest wall-clock JSONL yet
   - **guide** = chapter / example only (no lint yet)
4. Porting across languages must **re-bench** ([roadmap-next.md](roadmap-next.md) §5).
5. Fixture fire ≠ speed; deopt / PrintCompilation line counts ≠ escalate ([rule-regression.md](rule-regression.md)).

---

## Catalog

| Smell | zperf | cperf | jsperf | jvmperf | Evidence | Notes |
|-------|-------|-------|--------|---------|----------|-------|
| **alloc-in-loop / arena / pool** | **zp-alloc-hot** ~1.4× GPA vs arena; **zp-per-packet-alloc** (hot-path, shares zp-alloc-hot); **zp-create-destroy-hot** ~11× create/destroy vs pool; **zp-fixed-size-alloc-hot** ~8.5× fixed `alloc(u8,N)` vs pool | **cp-alloc-hot** ~10.8× malloc-loop vs arena (**error**) | **jp-alloc-hot** ~19× / ~6.4× `new`/push vs once (**off** under app preset — alloc/GC, not deopt) | **jp-expensive-alloc-hot** expensive factory in loop (hint; tiny-pool **negative**); **jp-hot-heavy-alloc** hot heavy alloc (**pending ART**); **jp-hot-payload-copy** ~15.8× frame buffer reuse (**error**) | z: zp-alloc-hot, zp-create-destroy-hot, zp-fixed-size-alloc-hot JSONL; c: cp-alloc-hot; js: jp-alloc-hot; jvm: jp-expensive-alloc-hot, jp-hot-payload-copy (+ jp-hot-heavy-alloc stub) | Same *idea* (hoist / reuse); Zig smp already cheap → prefer pool for fixed size. jvm jp-expensive-alloc-hot ≠ “always pool”. |
| **buffer grow / capacity / builder** | **zp-append-without-reserve** ~2.1× append reserve; **zp-map-put-without-ensure** ~2.8× map ensure; **zp-shift-on-read** ~17× shift-on-read vs cursor (**candidate error**) | **cp-realloc-grow-one** ~12.6× realloc+1 vs doubling (**error**) | **jp-string-plus-in-loop** (**removed** 2026-10-23; `push`+`join` was not ~2×); V8 arrays grow differently; prealloc appears under jp-alloc-hot good fixtures | **jp-string-concat-hot** ~14.2× string `+=` vs builder (**error**); **jp-unpresized-collection** ~1.6× unpresized fill (**hint** PARTIAL); **jp-baos-tobytearray-copy** ~12.8× BAOS `toByteArray` vs `writeTo` (**error**) | z: zp-append-without-reserve, zp-shift-on-read, zp-map-put-without-ensure; c: cp-realloc-grow-one; jvm: jp-string-concat-hot, jp-unpresized-collection, jp-baos-tobytearray-copy | Closest cross-kit pair: cp-realloc-grow-one ↔ zp-append-without-reserve ↔ jvm jp-string-concat-hot. Not the same as JS holey. |
| **hot IO / print / log / format** | **zp-print-hot** ~6e4× print vs quiet (**env I/O**, not escalate); **zp-unbuffered-io** ~49× empty Writer vs 4KiB (**candidate error**) | **cp-printf-hot** ~4.8× unbuf/buf hot; `#if 0` ~1× → **off** (default app preset) | **jp-console-hot** ~1328× console vs quiet (**off** app / hint engine — env) | **jp-format-hot** ~17× `String.format` hot (**error**); **jp-log-hot** ~28× unguarded log concat (**error**); **jp-hot-format-log** hot format/log (**pending ART**) | z: zp-print-hot, zp-unbuffered-io; c: cp-printf-hot; js: jp-console-hot; jvm: jp-format-hot, jp-log-hot (+ jp-hot-format-log stub) | Prefer buffered Io / level guards. Do not escalate env-bound print alone. |
| **shape / layout / SoA / density** | **zp-aos-single-field** ~6.6× AoS→SoA; **zp-packable-bools** / related density stubs (**pending**); **zp-large-struct-by-value** by-value (**inconclusive** `-Ofast`); **zp-bool-array** ~30× bool[] vs bitset | **guide** SoA examples (`p01_soa.c`); **no CP rule** | guide **§04** maps / IC / polymorphic (~12× in STATIC-VS-V8); **no layout JP** | **jp-many-boolean-fields** (**removed** 2026-10-22; COH 16=16 no win); Kotlin layout smells elsewhere | z: zp-aos-single-field, zp-bool-array JSONL + pending stubs; extern padding removed (~1.2×); js: STATIC-VS-V8; jvm: jp-many-boolean-fields | V8 hidden classes ≠ C padding ≠ Zig `extern` ≠ HotSpot object header. |
| **holey / sparse elements** | **n/a** — Zig slices ≠ V8 elements kinds | **n/a** — C “sparse” is CSR/hash, different problem | **jp-delete-array-hole** ~3.2× holey `delete a[i]` vs packed (**error**); STATIC case2 ~5.5× | **jp-android-sparse-array** Android SparseArray (**pending ART**) — **not** V8 holey | js: jp-delete-array-hole (+ STATIC-VS-V8); jvm: jp-android-sparse-array stub only | Do **not** map jp-delete-array-hole → CP or ZP. Android Sparse* ≠ V8 holey. |
| **delete / remove / tombstone** | **zp-queue-ordered-remove** ~466× `orderedRemove` vs ring (**candidate error**) | **n/a** | **jp-delete-shape** ~474× `delete` prop (**off** under app preset — G3 OK-idiom demote) | **n/a** as V8/Zig remove; closest reuse smells are buffer/pool | js: jp-delete-shape; z: zp-queue-ordered-remove | Related *cost of mid-structure delete*, not the same smell (JS tombstone ≠ Zig memmove). |
| **sync / lock / contested types** | **n/a** (no ZP sync rule) | **n/a** | **n/a** | **jp-legacy-synchronized-type** (**removed** 2026-10-22; ~1.08× / HT negative) | jvm: `_removed/` tombstone | Contended lock cost is workload-dependent; micro alone does not escalate. |
| **boxed / value boxing / stream box** | **n/a** (no managed boxing) | **n/a** | **n/a** (numbers are values; objects under alloc jp-alloc-hot) | **jp-boxed-primitive-collection** ~5.96× boxed collections (**error**); **jp-boxed-stream** ~149× boxed Stream (**error**); **jp-value-class-boxing** ~5× B/op value-class box (**error**) | jvm: jp-boxed-primitive-collection, jp-boxed-stream, jp-value-class-boxing; STATIC-VS-HOTSPOT | JVM-specific; jsperf has no boxing rule. |
| **string / intern / concat family** | **n/a** as JVM intern; Zig has zp-static-string-map StaticStringMap ~2.5× | **n/a** | **n/a** as intern (jp-string-plus-in-loop **removed** 2026-10-23; alloc cost under jp-alloc-hot) | **jp-string-concat-hot** concat (**error**); **jp-string-intern-hot** ~6.6× `intern()` in loop (**error**); **jp-format-hot** format (**error**) | jvm: jp-string-concat-hot, jp-format-hot, jp-string-intern-hot; z: zp-static-string-map | Overlaps hot-IO/format row for jp-format-hot; listed here for string-table / builder family. |
| **regex / parse control-flow** | **n/a** | **n/a** | **jp-map-filter-chain** (**hint**; 35000 rows ~4.6×–9.8×, 3-row filter+map ~1.3×) | **jp-regex-hot** ~1.36× regex compile in loop (**hint**); **jp-exception-control-flow** ~64× exception-as-control (**error**) | jvm: jp-regex-hot, jp-exception-control-flow | Weak wall for regex → stays hint; exceptions-as-flow is strong. |
| **collection chain / copy / lambda alloc (Kotlin)** | **n/a** | **n/a** | **n/a** | **jp-collection-chain** ~265× eager chain (**off**); **jp-lambda-to-non-inline-hot** ~244× B/op non-inline lambda (**off**); **jp-data-copy-hot** ~208× `copy` in loop (**error**); **jp-lazy-default-mode** lazy mode (**pending**) | jvm: jp-collection-chain, jp-lambda-to-non-inline-hot, jp-data-copy-hot (+ jp-lazy-default-mode stub) | Kotlin-centric; B/op often clearer than ns/op. |
| **enum / map specialization** | **zp-static-string-map** StaticStringMap ~2.5× (literal keys) | **n/a** | **n/a** | **jp-enum-key-hash-collection** ~2.1× EnumMap vs HashMap enum keys (**error**) | z: zp-static-string-map; jvm: jp-enum-key-hash-collection | Compile-time / ordinal maps — similar *idea*, different APIs. |
| **client / updater / factory recreate** | **n/a** | **n/a** | **n/a** | **jp-client-factory-recreate** ~5e5× HttpClient new vs reuse (**error**); **jp-non-static-field-updater** create ~165× / steady inc ~1.0× (**hint**) | jvm: jp-client-factory-recreate, jp-non-static-field-updater | Factory reuse; steady-state may be flat (jp-non-static-field-updater). |
| **Android / ART device smells** | **n/a** | **n/a** | **n/a** | **jp-android-sparse-array**, **jp-hot-heavy-alloc–jp-ui-text-append** stubs only (**pending ART/device**): SparseArray, hot alloc, format/log, system call, Bitmap, Handler post, UI text | jvm evidence stubs jp-android-sparse-array … jp-ui-text-append | No box JSONL until ART/device harness. |
| **correctness / static-only (not speed gates)** | **zp-debug-allocator** mode switch; **zp-missing-free** leak; **zp-catch-unreachable-alloc** `catch unreachable`; **zp-oversized-enum-tag** enum tag size — all **N/A** wall | — | — | **jp-finalize** finalize (**pending** design/correctness); **vt-unsafe-threadlocal-pool** guide-only VT/pool myth (**not shipped**) | z: stubs zp-debug-allocator / zp-missing-free / zp-catch-unreachable-* / zp-oversized-enum-tag; jvm: jp-finalize + vt-unsafe-threadlocal-pool | Do not invent speed JSONL for these. |

---

**Catalog rows:** 15 smell families (z/c/js/jvm) + sections for go/py/swift/arkts/cpp/csharp/php/ruby/rust/kotlin/objc/dart/lua/beam/nim. **All 19 kits corpus-ready** (AGENT.md G3, 2026-10-22 Asia/Shanghai) — findings remain heuristics, not guaranteed speedups.

**jvmperf policy snapshot:** see `packages/jvmperf/docs/evidence-policy.md` for current error/hint/off/pending maps (slug IDs). Guide-only: `vt-unsafe-threadlocal-pool` (not shipped). Removed measured-useless: `jp-legacy-synchronized-type`, `jp-many-boolean-fields`.

---

## Newer kits

Defaults are mostly **off** or **hint**. All kits below are **corpus-ready** under G3. Measured JSONL exists for most rules (see [rule-regression.md](rule-regression.md)); nimperf has none because G4 was blocked (no toolchain). Re-bench before escalating severity.

| Smell | goperf | pyperf | swiftperf | arktsperf | Notes |
|-------|--------|--------|-----------|-----------|-------|
| **alloc-in-loop / arena / pool** | **gp-make-hot** `make`/`new` in loop (**off**) | **n/a** as make; closest pp-list-plus-rebind list growth | **n/a** (ARC) | **at-alloc-hot** object/`new`/push`{` in loop (**off**) | Same *idea* as cp-alloc-hot / js jp-alloc-hot; ratios in each kit's evidence-policy (swift: none, G4 blocked) |
| **buffer grow / string builder** | **gp-string-plus-hot** string `+=` (**off**); **gp-append-nil-slice** append on nil slice (**hint**) | **pp-str-plus-hot** string `+=` (**off**); **pp-list-plus-rebind** list `+` rebinding (**hint**) | **sp-array-no-reserve** append without `reserveCapacity` (**hint**); string `+=` removed (~1×, reserve slower) | *(folds into at-alloc-hot)* | Closest to jvm jp-string-concat-hot / cp-realloc-grow-one family |
| **hot IO / print / log** | **gp-fmt-hot** `fmt.*printf` in loop (**off**) | **pp-print-hot** `print(` (**off**) | **sp-print-hot** `print(` (**off**) | **at-console-hot** `console.*` (**off**) | Env-bound; not escalated |
| **delete / shape** | **n/a** | **n/a** | **n/a** | no ArkTS delete rule (removed; Node proxy ~1×) | Aligns with jsperf jp-delete-shape idea; ArkTS VM may differ |
| **force-unwrap / unsafe optional** | **n/a** | **n/a** | no force-unwrap rule (removed; same time as `if let`) | **n/a** | Swift-specific |
| **defer / chains / lookups in loop** | **gp-defer-hot** `defer` in loop (**hint**) | **n/a** | no `map`/`joined` rule (removed; about 1.2×) | **at-includes-hot** `includes` lookup (**hint**); **at-json-hot** `JSON.parse`/`stringify` (**hint**) | Kit-specific; no cross-kit mapping implied |

### cpp / csharp / php / ruby

| Smell | cppperf | csharpperf | phpperf | rubyperf | Notes |
|-------|---------|------------|---------|----------|-------|
| **buffer grow / capacity** | **removed** (vector push without reserve — tombstone) | **cs-list-add-no-capacity** `List.Add` without Capacity (**off**) | **ph-array-merge-rebind** `array_merge` rebinding (**error**) | **rb-array-plus-rebind** Array `+` / concat (**off**). `Hash#merge` was removed (literal build slower and more allocating on Ruby 4.0.8) | Same *idea* as cp-realloc-grow-one / jvm jp-unpresized-collection; php is the only one with `error` (G4) |
| **string builder** | no C++ string-append rule (removed; ~1.1×) | **cs-string-plus-hot** string `+=` (**off**) | **ph-string-dot-hot** `.=` (**off**) | **rb-string-plus-hot** string `+=` (**off**) | Closest to jvm jp-string-concat-hot / gp-string-plus-hot |
| **hot IO / print** | **removed** (iostream in loop — tombstone) | **cs-console-hot** `Console.Write*` (**off**) | **ph-echo-hot** `echo`/`print` (**hint**) | **rb-puts-hot** `puts`/`print` (**off**) | Env-bound; not escalated |
| **regex in loop** | — | **cs-regex-hot** regex in loop (**hint**) | — | — | Closest to jvm jp-regex-hot; weak wall, stays hint |
| **bounds-checked index** | **removed** (`.at()` in loop — tombstone; reverse @-O2) | — | — | — | Prefer `operator[]` when index already validated; rule not shipped |

**cppperf vs cperf:** cppperf is dedicated C++17; cperf remains C11 (+ light C++).

### rust / kotlin / objc / dart / lua / beam

| Smell | rustperf | kotlinperf | objcperf | dartperf | luaperf | beamperf | Notes |
|-------|----------|------------|----------|----------|---------|----------|-------|
| **buffer grow / capacity** | **rs-alloc-hot** alloc/clone (**off**); **rs-collect-vec-hot** collect-in-loop (**hint**); sized `Vec::new` plus push removed (~1× large fill) | **kt-list-add-hot** list alloc (**off**) | **removed** (NSMutableArray add — tombstone) | **dt-list-add-empty** List.add (**off**); **dt-growable-add-empty** empty growable + add (**hint**) | **lu-table-insert-hot** table.insert (**off**) | **be-list-concat-reduce** list `++` (**hint**); **be-map-merge-hot** `Map.merge` (**hint**); **be-enum-map-filter-chain** map-then-filter (**hint**) | Same *idea* as cp-realloc-grow-one |
| **string builder** | **rs-format-rebind-hot** `format!` rebind (**error**, ~99×); amortized `+=` removed (~1×) | **kt-string-plus-hot** string `+=` (**off**) | **oc-nsstring-append-hot** stringByAppendingString (**off**) | **dt-string-plus-hot** string `+` (**off**) | **lu-string-concat-hot** `..` (**error**) | **removed** (`<>` append — tombstone; mixed/reverse) | Closest to jvm jp-string-concat-hot; Rust splits amortized vs format! |
| **hot IO / print** | **rs-println-hot** println! (**hint**) | **kt-println-hot** println (**off**) | **oc-nslog-hot** NSLog (**off**) | **dt-print-hot** print (**off**) | **lu-print-hot** print (**hint**) | **be-io-puts-hot** IO.puts / io:format (**off**) | Env-bound; not escalated |

**kotlinperf** is Kotlin-first heuristics; measured JVM/JMH evidence stays in **jvmperf** (do not duplicate). **objcperf** ≠ **swiftperf**. **beamperf** covers `.ex`/`.exs`/`.erl`.

### nim

| Smell | nimperf | Notes |
|-------|---------|-------|
| **buffer grow / capacity** | **nm-seq-add-hot** seq `.add` in loop (**off** after G3); **nm-seq-no-capacity** empty seq + `.add` (**hint**) | OK-idiom on Nim/Arraymancer/nimbus; opt-in. No JSONL (G4 blocked, no `nim`) |
| **string builder** | **removed** (`&=` / `s = s & x` — tombstone; `join` was slower) | Closest to jvm jp-string-concat-hot / rb-string-plus-hot |
| **hot IO / print** | **nm-echo-hot** `echo` in loop (**off**) | Env-bound; not escalated |

## Empty / thin cells (honest)

| Gap | Why |
|-----|-----|
| cperf **SoA lint** | Guide examples only. **cp-wide-bool-flags** is a hint for four full-width boolean flags and is not a SoA rule |
| jsperf **print** mapped but severity **off** (app) | Measured, env-bound |
| jsperf **buffer-grow** dedicated rule | Covered loosely via jp-alloc-hot prealloc fixtures; jp-string-plus-in-loop was removed after the join bench missed ~2× |
| zperf **sync/lock** | No rule |
| Cross-kit **holey** outside js | Physics differ → **n/a** by design |
| jvm **jp-android-sparse-array** … **jp-ui-text-append** | Need ART/device |
| zperf **zp-packable-bools** / **zp-usize-index-field** / **zp-optional-scalar-field** density | Pending density harness |
| jvm **jp-sleep-polling** sleep-polling | pending — design/situational, not micro |
| **vt-unsafe-threadlocal-pool** | Guide-first; not in `Rule.RULES` |
| nimperf **evidence** | G4 blocked (no Nim toolchain on the measurement host); stubs only, no JSONL |
| arktsperf / objcperf **evidence** | Measured on proxies (Node/V8, GNUstep), not the target runtime |
| swiftperf **build on Linux CI** | Needs Swift toolchain; smoke skips when absent |
| csharpperf **build without SDK** | Needs `dotnet`; smoke skips when absent |
| arktsperf **device benches** | Prefer HarmonyOS device; Node proxy alone does not escalate |
| cppperf vs cperf overlap | Deliberate split: C++ kit separate from C11 kit |

---

## Evidence pointers

| Kit | Policy | Correlate / batch (out of repo) |
|-----|--------|----------------------------------|
| shared | [rule-regression.md](rule-regression.md) | this catalog |
| zperf | [packages/zperf/docs/evidence-policy.md](../packages/zperf/docs/evidence-policy.md) | `packages/zperf/evidence/` |
| cperf | [packages/cperf/docs/evidence-policy.md](../packages/cperf/docs/evidence-policy.md) | `STATIC-VS-O2` (not in repo) |
| jsperf | [packages/jsperf/docs/evidence-policy.md](../packages/jsperf/docs/evidence-policy.md) | `STATIC-VS-V8` (not in repo) |
| jvmperf | [packages/jvmperf/docs/evidence-policy.md](../packages/jvmperf/docs/evidence-policy.md) | `STATIC-VS-HOTSPOT`, `EVIDENCE-BATCH` (not in repo) |

The correlate and batch notes named above are **not** part of this git repository — they are listed as plain names so the GitHub UI does not 404.

---


## Hot compile / parse / query (2026-10-23)

These slugs are **hint**. Fixtures are paired. There is no JSONL, and they are not part of the 2026-10-22 corpus verdict.

| Kit | Slug | Smell |
|-----|------|-------|
| pyperf | pp-json-hot | `json.loads` / `dumps` in loop |
| pyperf | pp-deepcopy-hot | `deepcopy` in loop |
| jsperf | jp-regex-ctor-hot | `new RegExp` (stable pattern; default scope all) |
| jsperf | jp-json-hot | `JSON.parse` / `stringify` (stable text; default scope all) |
| jsperf | jp-dom-query-hot | `querySelector` / `getElementById` (stable selector; default scope all) |

| jsperf | jp-query-all-star | `querySelectorAll('*')` full-tree walk (templates too) |
| jsperf | jp-execjs-in-timer | built `executeJavaScript`/`evaluate` inside timers |
| jsperf | jp-clone-per-event | `structuredClone` / JSON round-trip of event-like args |
| goperf | gp-regexp-compile-hot | `regexp.Compile` in loop |
| goperf | gp-json-marshal-hot | `json.Marshal` / `Unmarshal` in loop |
| goperf | gp-reflect-hot | `reflect.TypeOf` / `ValueOf` in loop |
| cppperf | cx-regex-ctor-hot | `std::regex` constructed in loop |
| cppperf | cx-endl-hot | `endl` flush in loop |
| csharpperf | cs-linq-materialize-hot | `ToList` / `ToArray` / `ToDictionary` in loop |
| csharpperf | cs-format-hot | `string.Format` in loop |
| rubyperf | rb-regexp-new-hot | `Regexp.new` in loop |
| rubyperf | rb-json-hot | `JSON.parse` / `generate` in loop |
| rustperf | rs-regex-new-hot | `Regex::new` in loop |

## Related

- [overview.md](overview.md) — umbrella status
- [playbook.md](playbook.md) — shared loop + regression contract
- [roadmap-next.md](roadmap-next.md) — next fills for empty cells
- [docs/README.md](README.md) — docs index
