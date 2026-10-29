# Rule regression coverage

As of **2026-10-22** (Asia/Shanghai). Null/reverse deep-dive **landed** (rb-hash-merge-in-loop fixture/msg; cx-string-append-unreserved / at-includes-hot docs; measured-useless tombstones; no severity escalate). Evidence fill batch A: goperf/pyperf/cppperf/phpperf/rustperf/luaperf/rubyperf; nim blocked. Contract: [playbook.md § Rule regression](playbook.md). Per-kit gates: `packages/*/docs/evidence-policy.md`. Smells: [smell-catalog.md](smell-catalog.md).

**Columns**

- **bad / good**: lint fixtures under `packages/<kit>/*-lint/fixtures/`
- **evidence**: both `.md` + `.jsonl` under `packages/<kit>/evidence/` (speed gate)
- **severity**: package default / policy (cperf·jsperf `--preset app`; jvmperf policy map; zperf historically all findings fail CI)
- **pending measure**: needs before/after JSONL before keep/escalate to `error` (siblings own benches — this matrix does not invent ratios)

Fixture pass proves the rule still **fires**; evidence proves it still **means speed**. Corpus residual counts ≠ either.

---


**Scope (2026-10-27):** default matching is `--scope all` (or kit-equivalent) across kits; opt in to `--scope loop` for the former loop-only behavior. Slugs formerly containing `in-loop` were renamed to `*-hot` and tombstoned; see each kit `docs/rule-ids.md` Renamed table.

## cperf (cp-alloc-hot–cp-printf-hot / cp-strlen-in-cond / cp-strcat-hot)

Fixtures use descriptive names (not `cp-alloc-hot.c`). Defaults from `docs/evidence-policy.md` / `--preset app`.

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| cp-alloc-hot | `bad/cp-alloc-hot_malloc_loop.c` | yes (`arena_hoisted.c`, …) | **yes** `evidence/cp-alloc-hot.*` | **error** | Measured gate present |
| cp-realloc-grow-one | `bad/cp-realloc-grow-one_realloc_grow.c` | yes (`capacity_doubling.c`, `realloc_wrapper.c`) | **yes** | **error** | Measured ~12.6× realloc-grow vs doubling |
| cp-printf-hot | `bad/cp-printf-hot_printf_loop.c` | yes (`dump_*`, `ifdef_dump_*`, `treeview_*`, …) | **yes** | **off** | Hot ~4.8× unbuf/buf; `#if 0` ~1× → stays off |
| cp-strlen-in-cond | `bad/cp-strlen-in-cond_strlen_cond.c` | yes (`cp-strlen-in-cond_strlen_hoisted.c`, …) | none yet | hint | No wall-clock bench; corpus TPs only |
| cp-strcat-hot | `bad/cp-strcat-hot_strcat_loop.c` | yes (`cp-strcat-hot_strcat_once.c`) | none yet | **off** | G3 demote (CLI/path OK-idiom); no wall-clock bench |
| cp-sprintf-hot | `bad/cp-sprintf-hot_sprintf_loop.c` | yes | jsonl | **hint** | microbench ~13.9× on one shape; stay hint; not corpus-triaged |
| cp-fopen-hot | `bad/cp-fopen-hot_fopen_loop.c` | yes | jsonl | **hint** | microbench ~423.4× on one shape; stay hint; not corpus-triaged |
| cp-gettime-hot | `bad/cp-gettime-hot_gettime_loop.c` | yes | jsonl | **hint** | microbench ~33.2× on one shape; stay hint; not corpus-triaged |
| cp-wide-bool-flags | `bad/cp-wide-bool-flags_ints.c` | yes (`cp-wide-bool-flags_bits.c`) | jsonl | **hint** | microbench ~19.1× on one shape; stay hint; not corpus-triaged |

---

## jsperf (slug ids)

Descriptive fixture names. Defaults: `--preset app` (jp-console-hot=off).

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| jp-alloc-hot | `bad/jp-alloc-hot_new_in_loop.js`, `jp-alloc-hot_push_object.js` | yes (`prealloc.js`, `jp-alloc-hot_reuse_buffer.js`, …) | **yes** | **off** (app) | ~19× / ~6.4× wall-clock (alloc/GC); G3 OK-idiom demote |
| jp-console-hot | `bad/jp-console-hot_console_loop.js` | yes (`jp-console-hot_console_outside_loop.js`) | **yes** | **off** (app) / hint | ~1328× if stdout discarded; env-dependent → not CI error |
| jp-delete-shape | `bad/jp-delete-shape_delete.js` | yes (`no_delete.js`, …) | **yes** `evidence/jp-delete-shape.*` | **off** (app) | G3 OK-idiom demote |
| jp-delete-array-hole | `bad/jp-delete-array-hole_holey_delete.js` | yes (`no_holey_delete.js`, …) | **yes** `evidence/jp-delete-array-hole.*` | **error** | Measured |
| jp-string-plus-in-loop | removed (fixtures under `evidence/_removed/fixtures/`) | tombstone | jsonl under `_removed/` | **removed** | `push`+`join` was not ~2× on matched shapes |
| jp-map-filter-chain | `bad/jp-map-filter-chain_map_filter_chain.js` | yes (`jp-map-filter-chain_single_map.js`, comment fixture) | **yes** | hint | 35000 rows ~4.6×/9.8×; 3-row filter+map 1.28×; stay hint |
| jp-regex-ctor-hot | `bad/jp-regex-ctor-hot_ctor_loop.js` | `good/jp-regex-ctor-hot_ctor_once.js`, pattern-varies | jsonl | hint | Node 26 fixed pattern ~4.4×; loop binding not reported |
| jp-json-hot | `bad/jp-json-hot_json_loop.js` | `good/jp-json-hot_json_once.js`, text-varies | jsonl | hint | Node 26 unchanged text ~140×; `rows[i]` not reported |
| jp-dom-query-hot | `bad/jp-dom-query-hot_query_loop.js` | `good/jp-dom-query-hot_query_once.js`, selector-varies | jsonl | hint | Node 26 tiny linkedom document ~16×; loop binding not reported |
| jp-intl-datetimeformat-hot | `bad/jp-intl-datetimeformat-hot_format_loop.js` | `good/jp-intl-datetimeformat-hot_format_once.js`, locale-varies | jsonl | hint | Node 26 ~36×; loop binding not reported |
| jp-readfile-sync-hot | `bad/jp-readfile-sync-hot_read_loop.js` | `good/jp-readfile-sync-hot_read_once.js`, for-of header, path-varies | jsonl | hint | body only; Node 26 ~114× when the path stays the same |
| jp-clock-hot | `bad/jp-clock-hot_clock_loop.js` | `good/jp-clock-hot_clock_once.js`, await loop, nested fn/arrow | jsonl | hint | tight loop ~26×/~19×; `await` loops not reported; nested fn bodies skipped |
| jp-query-all-star | `bad/jp-query-all-star_star_query.js`, `jp-query-all-star_in_template.js` | `good/jp-query-all-star_narrow.js`, template narrow | none yet | hint | full-tree `*`; message does not say cache that node; sees template scripts |
| jp-execjs-in-timer | `bad/jp-execjs-in-timer_interval.js` | `good/jp-execjs-in-timer_once.js` | none yet | hint | built script in setInterval/setTimeout; install once + short drain is clean |
| jp-clone-per-event | `bad/jp-clone-per-event_structured.js`, `jp-clone-per-event_json_roundtrip.js` | `good/jp-clone-per-event_field.js`, unrelated clone | none yet | hint | only event-like args (`e`/`event`/…) |

---

## zperf (zp-alloc-hot–zp-fixed-size-alloc-hot)

Paired fixtures for all 28. Evidence under `packages/zperf/evidence/` (Zig **0.17.0** `-Ofast`, 2026-10-21). Policy: `packages/zperf/docs/evidence-policy.md`. CLI still fails on any finding; **candidate error** = policy escalate when presets land.

| rule | bad | good | evidence | rules.zig sev | notes |
|------|-----|------|----------|---------------|-------|
| zp-alloc-hot | yes | yes | **yes** | warning | ~**1.4×** GPA vs arena — modest; keep warning |
| zp-append-without-reserve | yes | yes | **yes** | info | ~**2.1×** append reserve |
| zp-page-allocator-small | yes | yes | **yes** | warning | ~**341×** page vs GPA — **candidate error** |
| zp-debug-allocator | yes | yes | **N/A** | warning | static-only (mode switch) |
| zp-large-struct-by-value | yes | yes | **inconclusive** | info | ReleaseFast elided microbench |
| zp-print-hot | yes | yes | **yes** | warning | ~**6e4×** print vs quiet — env I/O, not escalate |
| zp-unbuffered-io | yes | yes | **yes** | warning | ~**49×** empty vs 4KiB — **candidate error** |
| zp-missing-free | yes | yes | **N/A** | warning | correctness (leak) |
| zp-extern-struct-padding | yes | yes | **yes** | warning | ~**1.2×** padded walk — modest |
| zp-broad-runtime-safety | yes | yes | **pending** | warning | need ReleaseSafe measure |
| zp-packable-bools | yes | yes | **pending** | info | density |
| zp-usize-index-field | yes | yes | **pending** | info | density |
| zp-aos-single-field | yes | yes | **yes** | hint | ~**6.6×** AoS vs SoA |
| zp-catch-unreachable-alloc | yes | yes | **N/A** | warning | correctness (UB) |
| zp-oversized-enum-tag | yes | yes | **N/A** | info | static size/ABI |
| zp-optional-scalar-field | yes | yes | **pending** | info | density |
| zp-bool-array | yes | yes | **yes** | info | ~**30×** bool[] vs bitset |
| zp-static-string-map | yes | yes | **yes** | info | ~**2.5×** StaticStringMap |
| zp-runtime-div-hot | yes | yes | **yes** | hint | ~**12×** mod vs mask |
| zp-queue-ordered-remove | yes | yes | **yes** | warning | ~**466×** orderedRemove vs ring — **candidate error** |
| zp-shift-on-read | yes | yes | **yes** | warning | ~**17×** copyForwards vs cursor — **candidate error** |
| zp-per-packet-alloc | yes | yes | **yes** (shares zp-alloc-hot) | warning | hot-path alloc; same ~1.4× |
| zp-invariant-float-div | yes | yes | **yes** | hint | ~**2.0×** float div vs recip |
| zp-map-put-without-ensure | yes | yes | **yes** | info | ~**2.8×** map ensure |
| zp-catch-unreachable-io | yes | yes | **N/A** | warning | correctness |
| zp-arena-reset-free-all | yes | yes | **yes** | warning | ~**3.2×** free_all vs retain |
| zp-create-destroy-hot | yes | yes | **yes** | warning | ~**11×** create/destroy vs pool — **candidate error** |
| zp-fixed-size-alloc-hot | yes | yes | **yes** | warning | ~**8.5×** fixed alloc vs pool — **candidate error** |

---

## jvmperf (jp-boxed-primitive-collection–jp-non-static-field-updater) — summary

IDs are **jvmperf** `jp-*` slugs, not jsperf. Fixtures: mostly `bad/<slug>.*` + `.kt` with matching `good/`; Kotlin-only for several collection/boxing rules; jp-boxed-stream / jp-non-static-field-updater Java-only. **vt-unsafe-threadlocal-pool** is guide-only under `jvmperf-lint/fixtures/guide/` (not shipped).

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| jp-boxed-primitive-collection | yes (java+kt) | yes | **yes** | **error** | ~5.96× STATIC-VS-HOTSPOT |
| jp-string-concat-hot | yes (java+kt) | yes | **yes** | **error** | J23 ~14.2× |
| jp-regex-hot | yes (java+kt) | yes | **yes** | hint | J26 ~1.36× |
| jp-format-hot | yes (java+kt) | yes | **yes** | **error** | ~17× |
| jp-unpresized-collection | yes (java+kt) | yes | **yes** | hint | PARTIAL ~1.6× |
| jp-boxed-stream | yes (java) | yes | **yes** | **error** | J32 ~149× |
| jp-exception-control-flow | yes (java+kt) | yes | **yes** | **error** | J32 ~64× |
| jp-legacy-synchronized-type (**removed**) | yes (java+kt, archived) | yes | **yes** (~1.08×) | — | measured-no-win; tombstone `_removed/` |
| jp-many-boolean-fields (**removed**) | yes (java+kt, archived) | yes | **yes** (1.0×) | — | COH no footprint win; tombstone `_removed/` |
| cx-sstream-in-loop (**removed**) | archived | archived | 1.24× at -O2 | — | string-stream reuse; tombstone |
| pp-regex-compile-in-loop (**removed**) | archived | archived | under 3× | — | CPython caches `re.compile`; tombstone |
| rs-map-new-in-loop | `bad/rs-map-new-in-loop_map_loop.rs` | yes | **yes** | hint | two quiet rustc 1.99 runs about 1.51× and 1.53×; restored |
| pp-datetime-format-in-loop (**removed**) | archived | archived | no hoist | — | changing input cannot skip the call |
| gp-time-parse-in-loop (**removed**) | archived | archived | no hoist | — | changing input cannot skip the call |
| rb-date-parse-in-loop (**removed**) | archived | archived | no hoist | — | changing input cannot skip the call |
| jp-enum-key-hash-collection | yes (java+kt) | yes | **yes** | **error** | EnumMap ~2.1× |
| jp-collection-chain | yes (kt) | yes | **yes** | **error** | JDK 27 / Kotlin 2.4.21 ~265× |
| jp-value-class-boxing | yes (kt) | yes | **yes** | **error** | JDK 27 ~4.0× time, ~5× B/op |
| jp-lambda-to-non-inline-hot | yes (kt) | yes | **yes** | **error** | JDK 27 alloc ~244×; time ~0.47× |
| jp-lazy-default-mode | yes (kt) | yes | md stub only | hint | pending — situational lazy |
| jp-data-copy-hot | yes (kt) | yes | **yes** | **error** | JDK 27 ~208× time, alloc still ~10001× |
| jp-android-sparse-array | yes | yes | md stub | hint | pending ART |
| jp-log-hot | yes | yes | **yes** | **error** | J32 ~28× (debug off) |
| jp-sleep-polling | yes | yes | md stub | hint | pending sleep design |
| jp-finalize | yes | yes | md stub | hint | pending finalize/Cleaner |
| jp-expensive-alloc-hot | yes | yes | **yes** | hint | negative tiny-pool |
| jp-hot-heavy-alloc–jp-ui-text-append | yes | yes | md stubs | hint | pending ART/device |
| jp-baos-tobytearray-copy | yes | yes | **yes** | **error** | J32 ~12.8× |
| jp-hot-payload-copy | yes | yes | **yes** | **error** | J32 ~15.8× |
| vt-unsafe-threadlocal-pool | guide only | guide | **md stub** ([vt-unsafe-threadlocal-pool.md](../packages/jvmperf/evidence/vt-unsafe-threadlocal-pool.md)) | — | not shipped / guide-first |
| jp-client-factory-recreate | yes | yes | **yes** | **error** | J32 HttpClient ~5e5× |
| jp-string-intern-hot | yes | yes | **yes** | **error** | J32 intern ~6.6× |
| jp-non-static-field-updater | yes (java) | yes | **yes** | hint | create ~165×; inc ~1.0× |

CLI today may still fail on any finding; policy severity is the keep/escalate contract until presets land.

---



---


**Scaffold evidence contract:** until JSONL exists, each scaffold rule MUST have a named pending stub `packages/<kit>/evidence/<ID>.md` (not only a folder README). That satisfies registry parity without inventing ratios.

## goperf (gp-make-hot–gp-defer-hot) — corpus-ready

| Rule | Bad fixture | Good fixture | Evidence | Default | Notes |
|------|-------------|--------------|----------|---------|-------|
| gp-make-hot | `bad/gp-make-hot_make_loop.go` | yes | **yes** | **off** | G4 ~265× make-each; stay off (G3 OK-idiom) |
| gp-string-plus-hot | `bad/gp-string-plus-hot_string_plus.go` | yes | **yes** | **off** | G4 ~2919× += vs Builder; stay off |
| gp-fmt-hot | `bad/gp-fmt-hot_fmt_loop.go` | yes | **yes** | **off** | G4 ~1.8–2.8× fmt vs strconv; stay off |
| gp-append-nil-slice | `bad/gp-append-nil-slice_append_grow.go` | `good/gp-append-nil-slice_presize.go` | **yes** | hint | G4 ~12.2× append grow vs presize |
| gp-defer-hot | `bad/gp-defer-hot_defer_loop.go` | `good/gp-defer-hot_close_each.go` + closure | **yes** | hint | G4 ~33× defer-in-loop vs close-each |
| gp-regexp-compile-hot | `bad/gp-regexp-compile-hot_compile_loop.go` | `good/gp-regexp-compile-hot_compile_once.go` | jsonl | hint | microbench ~7.1× on one shape; stay hint; not corpus-triaged |
| gp-json-marshal-hot | `bad/gp-json-marshal-hot_marshal_loop.go` | `good/gp-json-marshal-hot_marshal_once.go` | jsonl | hint | microbench ~368.4× on one shape; stay hint; not corpus-triaged |
| gp-reflect-hot | `bad/gp-reflect-hot_reflect_loop.go` | `good/gp-reflect-hot_reflect_once.go` | jsonl | hint | microbench ~1×, no meaningful cost; stay hint |


## pyperf (pp-str-plus-hot–pp-print-hot) — corpus-ready

| Rule | Bad fixture | Good fixture | Evidence | Default | Notes |
|------|-------------|--------------|----------|---------|-------|
| pp-str-plus-hot | `bad/pp-str-plus-hot_str_plus.py` | yes | **yes** | **off** | G4 ~5.5× += vs join; stay off |
| pp-list-plus-rebind | `bad/pp-list-plus-rebind_list_plus.py` | yes | **yes** | hint | G4 ~1117× list+ rebind; stay hint |
| pp-print-hot | `bad/pp-print-hot_print_loop.py` | yes | **yes** | **off** | G4 ~3.4× print loop; stay off |
| pp-json-hot | `bad/pp-json-hot_json_loop.py` | `good/pp-json-hot_json_once.py` | jsonl | hint | microbench ~81.6× on one shape; stay hint; not corpus-triaged |
| pp-deepcopy-hot | `bad/pp-deepcopy-hot_deepcopy_loop.py` | `good/pp-deepcopy-hot_deepcopy_once.py` | jsonl | hint | microbench ~21.8× on one shape; stay hint; not corpus-triaged |
| *(removed — no slug)* re-adhoc in loop | `bad/pp004_re_adhoc.py` (archived) | `good/pp004_re_compiled.py` | **yes** | — | tombstone; G4 ~1.35× / warm may reverse |


## swiftperf (sp-force-unwrap-in-loop–sp-map-joined-chain) — corpus-ready

| ID | Bad fixture | Good | Evidence | Default | Notes |
|----|-------------|------|----------|---------|-------|
| sp-force-unwrap-in-loop | force_loop | yes | **blocked** | **off** | G4 blocked — no `swiftc` on Linux |
| sp-string-plus-in-loop | string_plus | yes | **blocked** | **off** | G4 blocked — no Swift toolchain |
| sp-print-hot | print_loop | yes | **blocked** | **off** | G4 blocked — no Swift toolchain |
| sp-array-no-reserve | append_no_reserve | yes | **blocked** | hint | G4 blocked — no Swift toolchain |
| sp-map-joined-chain | map_joined | yes | **blocked** | hint | G4 blocked — no Swift toolchain |
| sp-dateformatter-hot | `sp-dateformatter-hot_formatter_loop.swift` | yes | jsonl | hint | microbench ~29.8× on one shape; stay hint; not corpus-triaged |
| sp-json-decode-hot | `sp-json-decode-hot_decode_loop.swift` | yes | jsonl | hint | microbench ~1958.0× on one shape; stay hint; not corpus-triaged |
| sp-regex-hot | `sp-regex-hot_regex_loop.swift` | yes | jsonl | hint | microbench ~16.4× on one shape; stay hint; not corpus-triaged |

r4 n=32 TP 65.6% FP+DOC+SKIP 0% → **corpus-ready: yes** (text-lint fallback; SPM when Swift present). G4 2026-10-22: **blocked** (no fake JSONL). The three 2026-10-23 hints are outside that verdict.


## arktsperf (at-alloc-hot–at-json-hot) — corpus-ready

| ID | Bad fixture | Good | Evidence | Default | Notes |
|----|-------------|------|----------|---------|-------|
| at-alloc-hot | new_loop | yes | **yes** (Node proxy) | **off** | G4 ~33× new vs reuse; stay off |
| at-object-delete | delete | yes | **yes** (inconclusive) | **off** | G4 ~1.0× (fill-dominated); isolated delete modest; stay off |
| at-console-hot | console_loop | yes | **yes** (Node proxy) | **off** | G4 ~208×; stay off |
| at-includes-hot | includes_loop | yes (+ `at-includes-hot_string_lut`) | **yes** (Node proxy) | hint | G4 ~29× includes→Set; String.indexOf→LUT (Map~1×); stay hint |
| at-json-hot | json_loop | yes | **yes** (Node proxy) | hint | G4 ~2.2× parse / ~1.7× stringify; stay hint |

r3 n=56 TP 66.1% FP+DOC+SKIP 0% → **corpus-ready: yes**. G4 is **Node/V8 proxy**, not ArkTS VM — no escalate to error.


## cppperf (`cx-string-append-unreserved`) — corpus-ready

Active rule: **cx-string-append-unreserved** (default **hint**). Vector-push / iostream / `.at()` rules **removed** (tombstones). Dedicated C++17 (≠ cperf).

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| *(removed — no slug)* vector push without reserve | `bad/cx001_push_loop.cpp` (archived) | yes | **yes** | — | tombstone; G4 ~1.58× @-O2 |
| cx-string-append-unreserved | `bad/cx-string-append-unreserved_string_plus.cpp` | yes (`cx-string-append-unreserved_append_reserve.cpp`) | **yes** | **hint** | G4 ~1.09× char @-O2; chunk~1.8×; stay hint |
| cx-regex-ctor-hot | `bad/cx-regex-ctor-hot_regex_loop.cpp` | `good/cx-regex-ctor-hot_regex_once.cpp` | jsonl | **hint** | microbench ~1.55×, small; stay hint |
| cx-endl-hot | `bad/cx-endl-hot_endl_loop.cpp` | `good/cx-endl-hot_newline.cpp` | jsonl | **hint** | microbench ~1×, no meaningful cost; stay hint |
| *(removed — no slug)* iostream in loop | `bad/cx003_iostream_loop.cpp` (archived) | yes | **yes** | — | tombstone; G4 ~1.01× |
| *(removed — no slug)* `.at()` in loop | `bad/cx004_at_loop.cpp` (archived) | yes | **yes** | — | tombstone; G4 ~0.85× reverse @-O2 |

---

## csharpperf (cs-list-add-no-capacity–cs-regex-hot) — corpus-ready

cs-list-add-no-capacity–cs-console-hot default **off** after G3. **cs-regex-hot** default **hint**. G4 on .NET 8.0.426 (2026-10-22); **no severity escalate**.

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| cs-list-add-no-capacity | `bad/cs-list-add-no-capacity_add_loop.cs` | yes (`cs-list-add-no-capacity_capacity.cs`) | **yes** | **off** | G4 ~13× List capacity; stay off |
| cs-string-plus-hot | `bad/cs-string-plus-hot_string_plus.cs` | yes (`cs-string-plus-hot_builder.cs`) | **yes** | **off** | G4 ~3758× string+=; stay off |
| cs-console-hot | `bad/cs-console-hot_console_loop.cs` | yes (`cs-console-hot_console_outside.cs`) | **yes** | **off** | G4 ~6× Console null; stay off |
| cs-regex-hot | `bad/cs-regex-hot_regex_loop.cs` | yes (`cs-regex-hot_compiled_regex.cs`) | **yes** | **hint** | G4 ~2.6× IsMatch vs Compiled; stay hint |
| cs-linq-materialize-hot | `bad/cs-linq-materialize-hot_tolist_loop.cs` | `good/cs-linq-materialize-hot_tolist_once.cs` | jsonl | hint | .NET 10 ~38.9× on one shape; stay hint; not corpus-triaged |
| cs-format-hot | `bad/cs-format-hot_format_loop.cs` | `good/cs-format-hot_format_once.cs` | jsonl | hint | .NET 10 ~5.0× on one shape; stay hint; not corpus-triaged |

---

## phpperf (ph-string-dot-hot–ph-echo-hot) — corpus-ready

ph-array-merge-rebind default **error** after G4 (`ph-array-merge-rebind.md`+`jsonl`). ph-string-dot-hot default **off** (G3 OK-idiom-heavy) and ph-echo-hot **hint**; both have measured JSONL.

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| ph-string-dot-hot | `bad/ph-string-dot-hot_str_dot.php` | yes (`ph-string-dot-hot_implode.php`) | **yes** | **off** | G4 ~3.3× .= vs implode; stay off |
| ph-array-merge-rebind | `bad/ph-array-merge-rebind_array_merge.php` | yes (`ph-array-merge-rebind_push.php`) | **yes** | **error** | array_merge rebind; G4 2026-10-22 |
| ph-echo-hot | `bad/ph-echo-hot_echo_loop.php` | yes (`ph-echo-hot_echo_outside.php`) | **yes** | hint | G4 ~4.4× echo each; stay hint |

---

## rubyperf (rb-string-plus-hot–rb-file-read-hot) — corpus-ready

rb-string-plus-hot–rb-puts-hot default **off** after G3. **rb-hash-merge-in-loop** was removed on 2026-10-23: the literal build was slower than `merge` and allocated more.

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| rb-string-plus-hot | `bad/rb-string-plus-hot_str_plus.rb` | yes | **yes** | **off** | G4 ~32× += vs <<; stay off |
| rb-array-plus-rebind | `bad/rb-array-plus-rebind_array_plus.rb` | yes | **yes** | **off** | G4 ~181× array+ rebind; stay off |
| rb-puts-hot | `bad/rb-puts-hot_puts_loop.rb` | yes | **yes** | **off** | G4 ~5.1× puts each; stay off |
| rb-hash-merge-in-loop (**removed**) | archived | archived | tombstone | — | Ruby 4.0.8 literal slower than merge (~0.78×) and ~2× objects |
| rb-regexp-new-hot | `bad/rb-regexp-new-hot_regexp_loop.rb` | `good/rb-regexp-new-hot_regexp_once.rb` | jsonl | hint | microbench ~7.7× on one shape; stay hint; not corpus-triaged |
| rb-json-hot | `bad/rb-json-hot_json_loop.rb` | `good/rb-json-hot_json_once.rb` | jsonl | hint | microbench ~10.5× on one shape; stay hint; not corpus-triaged |

## rustperf (rs-alloc-hot–rs-collect-vec-hot) — corpus-ready (r4)

rs-vec-no-capacity/rs-collect-vec-hot redesign 2026-10-22. r4 clap residuals **6×TP** / FP+DOC+SKIP **0%** → **corpus-ready: yes**. rs-format-rebind-hot `format!` rebind → **error** (~99×); rs-string-plus-in-loop/rs-vec-no-capacity/rs-collect-vec-hot → **hint**; rs-alloc-hot → **off** (G4 measured, stayed off); rs-println-hot → **hint** (measured).

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| rs-alloc-hot | `bad/rs-alloc-hot_clone_loop.rs` | yes (`rs-alloc-hot_with_capacity.rs`) | **yes** | **off** | alloc/clone; G4 ~2.7× Vec / ~1.1× clone — stay off |
| rs-string-plus-in-loop | `bad/rs-string-plus-in-loop_string_plus.rs` | yes (`rs-string-plus-in-loop_write.rs`, `rs-string-plus-in-loop_tiny_sep.rs`) | **yes** | hint | `+=` / `push_str` only; ~1× amortized |
| rs-println-hot | `bad/rs-println-hot_println_loop.rs` | yes (`rs-println-hot_println_outside.rs`) | **yes** | hint | G4 ~12.6× writeln each vs buffer; stay hint |
| rs-format-rebind-hot | `bad/rs-format-rebind-hot_format_rebind.rs` | yes (`rs-format-rebind-hot_write.rs`, `rs-format-rebind-hot_let_format.rs`, `rs-format-rebind-hot_brace_wrap.rs`) | **yes** (aliased G4) | **error** | `format!` rebind reuse; ~99× vs `write!` |
| rs-vec-no-capacity | `bad/rs-vec-no-capacity_vec_new_push.rs` | yes (`rs-vec-no-capacity_with_capacity.rs`, `rs-vec-no-capacity_cfg_test.rs`) | **yes** | hint | G4 ~1.0× large / ~2.1× small builders; stay hint |
| rs-collect-vec-hot | `bad/rs-collect-vec-hot_collect_in_loop.rs` | yes (`rs-collect-vec-hot_count_no_collect.rs`) | **yes** | hint | G4 ~1.8× collect vs count; stay hint |
| rs-regex-new-hot | `bad/rs-regex-new-hot_regex_loop.rs` | `good/rs-regex-new-hot_regex_once.rs` | md only | hint | pending measure; not corpus-triaged |

---

## kotlinperf (kt-list-add-hot–kt-println-hot) — corpus-ready

kt-list-add-hot–kt-println-hot default **off** (G3 OK-idiom). Empty-collection-add rule **removed** (tombstone). G4 on kotlinc 2.0.21 / JRE 21 (2026-10-22); kit-local `kt-*` ≠ jvmperf JMH. **No escalate**.

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| kt-list-add-hot | `bad/kt-list-add-hot_list_loop.kt` | yes (`kt-list-add-hot_capacity.kt`) | **yes** | **off** | G4 ~2.1× empty vs capacity @2e6; stay off |
| kt-string-plus-hot | `bad/kt-string-plus-hot_string_plus.kt` | yes (`kt-string-plus-hot_buildString.kt`) | **yes** | **off** | G4 ~1170× += vs buildString; stay off |
| kt-println-hot | `bad/kt-println-hot_println_loop.kt` | yes (`kt-println-hot_println_outside.kt`) | **yes** | **off** | G4 ~99× println; stay off |
| *(removed — no slug)* empty list + add | `bad/kt004_empty_add.kt` (archived) | yes | **yes** (inconclusive) | — | tombstone; G4 ~0.84–1.26× |

---

## objcperf (oc-nsstring-append-hot–oc-nslog-hot) — corpus-ready

Active: oc-nsstring-append-hot / oc-nslog-hot (default **off**). Date-formatter, JSON, and regular-expression rules are **hint** and are not part of the 2026-10-22 corpus verdict. Array-add rules **removed** (tombstones). G4 on **GNUstep** (not Apple runtime) 2026-10-22. Distinct from swiftperf. **No escalate**.

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| *(removed — no slug)* NSMutableArray add | `bad/oc001_add_loop.m` (archived) | yes | **yes** (gnustep-proxy) | — | tombstone; G4 ~1.18× / dive ~1× |
| oc-nsstring-append-hot | `bad/oc-nsstring-append-hot_append_loop.m` | yes (`oc-nsstring-append-hot_mutable.m`) | **yes** (gnustep) | **off** | G4 ~569× append; stay off |
| oc-nslog-hot | `bad/oc-nslog-hot_nslog_loop.m` | yes (`oc-nslog-hot_nslog_outside.m`) | **yes** (fprintf proxy) | **off** | G4 ~191×; stay off |
| oc-dateformatter-hot | `bad/oc-dateformatter-hot_alloc_loop.m` | yes | jsonl | hint | microbench ~30.4× on one shape; stay hint; not corpus-triaged |
| oc-json-hot | `bad/oc-json-hot_json_loop.m` | yes | jsonl | hint | microbench ~15.8× on one shape; stay hint; not corpus-triaged |
| oc-regex-hot | `bad/oc-regex-hot_regex_loop.m` | yes | jsonl | hint | microbench ~14.9× on one shape; stay hint; not corpus-triaged |
| *(removed — no slug)* empty array + add | `bad/oc004_empty_add.m` (archived) | yes | **yes** (gnustep-proxy) | — | tombstone; G4 ~1.18× / dive ~1× |

---

## dartperf (dt-list-add-empty–dt-growable-add-empty) — corpus-ready

dt-list-add-empty–dt-print-hot default **off**. **dt-growable-add-empty** default **hint**. G4 on Dart 3.13.6 (2026-10-22). **No escalate**.

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| dt-list-add-empty | `bad/dt-list-add-empty_add_loop.dart` | yes (`dt-list-add-empty_filled.dart`) | **yes** | **off** | G4 ~3.1× filled vs empty add; stay off |
| dt-string-plus-hot | `bad/dt-string-plus-hot_string_plus.dart` | yes (`dt-string-plus-hot_buffer.dart`) | **yes** | **off** | G4 ~247× string+; stay off |
| dt-print-hot | `bad/dt-print-hot_print_loop.dart` | yes (`dt-print-hot_print_outside.dart`) | **yes** | **off** | G4 ~128× write; stay off |
| dt-growable-add-empty | `bad/dt-growable-add-empty_empty_add.dart` | yes (`dt-growable-add-empty_filled.dart`) | **yes** | **hint** | G4 ~2.4×; stay hint |

---

## luaperf (lu-table-insert-hot–lu-print-hot) — corpus-ready

lu-table-insert-hot default **off** (G3 OK-idiom). lu-string-concat-hot default **error** after G4 (`lu-string-concat-hot.md`+`jsonl`). lu-print-hot G4 evidence present; default stays **hint** (I/O env-dependent).

| rule | bad fixture | good / negative | evidence md+jsonl | severity default | notes |
|------|-------------|-----------------|-------------------|------------------|-------|
| lu-table-insert-hot | `bad/lu-table-insert-hot_insert_loop.lua` | yes (`lu-table-insert-hot_index.lua`) | **yes** | **off** | G4 ~4.7× insert vs index; stay off |
| lu-string-concat-hot | `bad/lu-string-concat-hot_concat_loop.lua` | yes (`lu-string-concat-hot_concat.lua`) | **yes** | **error** | string ..; G4 2026-10-22 |
| lu-print-hot | `bad/lu-print-hot_print_loop.lua` | yes (`lu-print-hot_print_outside.lua`) | **yes** | hint | print in loop; G4 2026-10-22 stays hint |

---

## beamperf (be-list-concat-reduce–be-enum-map-filter-chain) — corpus-ready

| ID | Bad fixture | Good | Evidence | Default | Notes |
|----|-------------|------|----------|---------|-------|
| be-list-concat-reduce | `bad/be-list-concat-reduce_list_plus.exs` (+ `.erl`) | yes | **yes** | hint | G4 ~453× ++ vs cons; stay hint |
| *(removed — no slug)* `<>` string append | `bad/be002_string_append.exs` (archived) | yes | **yes** (mixed) | — | tombstone; chunk<> wins; tiny/digits may reverse |
| be-io-puts-hot | `bad/be-io-puts-hot_io_loop.exs` | yes | **yes** | **off** | G4 ~3810× IO.puts; stay off |
| be-map-merge-hot | `bad/be-map-merge-hot_merge_in_loop.exs` | yes | **yes** | hint | G4 ~6.9× Map.merge vs put; KW ~2×; stay hint |
| be-enum-map-filter-chain | `bad/be-enum-map-filter-chain_enum_chain.exs` | yes | **yes** | hint | G4 ~4.5× map|>filter one-pass; stay hint |

r3 n=4 TP 75% FP+DOC+SKIP 0% → **corpus-ready: yes**. G4 be-list-concat-reduce–be-enum-map-filter-chain on OTP 27 / Elixir 1.18 (2026-10-22); no escalate.


## nimperf (nm-seq-add-hot–nm-seq-no-capacity) — corpus-ready

| Rule | Bad fixture | Good fixture | Evidence | Default | Notes |
|------|-------------|--------------|----------|---------|-------|
| nm-seq-add-hot | `bad/nm-seq-add-hot_add_loop.nim` | yes | pending | **off** | G3 OK-idiom; **G4 blocked** — no `nim` in Debian apt |
| nm-string-amp-in-loop (**removed**) | archived | archived | tombstone | — | Nim 2.2.12 `join` slower than `&=` (~0.79×, earlier ~0.69×) |
| nm-echo-hot | `bad/nm-echo-hot_echo_loop.nim` | yes | pending | **off** | G4 blocked (no nim toolchain) |
| nm-seq-no-capacity | `bad/nm-seq-no-capacity_empty_add.nim` | `good/nm-seq-no-capacity_ofcap.nim` | pending | hint | G4 blocked (no nim toolchain) |


## Batch notes

**Batch B G4 (2026-10-22):** arkts Node-proxy JSONL; beam/csharp/dart/kotlin measured; objc **GNUstep** (not Apple); swift **blocked** (no swiftc). Defaults unchanged — no escalate to `error` this pass.

## Gaps called out (honest)

**Disk audit 2026-10-21 ~19:31 Asia/Shanghai** — every skip / pending / N/A / inconclusive rule now has a named `evidence/<ID>.md` stub (no invented JSONL).

1. **cperf**: bad + good + `evidence/cp-*.{md,jsonl}` for shipped rules — **complete**.
2. **jsperf**: bad + good + `evidence/jp-*.{md,jsonl}` for shipped rules — **complete**.
3. **zperf**: paired fixtures for all active rules. Measured JSONL + registered stubs (pending/N/A/inconclusive) — see `packages/zperf/docs/evidence-policy.md` and `packages/zperf/evidence/`.
4. **jvmperf fixtures**: shipped `jp-*` bad+good (lang-scoped). **vt-unsafe-threadlocal-pool** guide-only under `fixtures/guide/` + [`vt-unsafe-threadlocal-pool.md`](../packages/jvmperf/evidence/vt-unsafe-threadlocal-pool.md) — not shipped.
5. **jvmperf evidence**: measured error/hint JSONL for shipped rules with numbers; **pending stubs** for ART/device and situational rules. See `packages/jvmperf/docs/evidence-policy.md`.
6. **Still pending measure** (honest — need harness/env): zperf density/safety stubs; jvm Android ART device rules.
7. **Naming**: c/js good fixtures are descriptive — tests assert suite cleanliness, not one-file-per-rule.
8. **Do not** treat corpus dumps or deopt/compilation line counts as regression of *meaning*.

## Cross-language check (2026-10-23)

File-open and clock-sample shapes that already had a cost in C or C++ were timed on the other runnable toolchains. A hint was added only when the ratio was large and the standard library has a reusable handle or a sample that can sit outside the loop. A changing path cannot be hoisted. A loop that needs a fresh timestamp has nothing to hoist. Defaults stay hint.

Checked and not added:

| shape | ratio | why no slug |
| --- | ---: | --- |
| Python `time.perf_counter_ns` | 2.866 | small next to the loop |
| Ruby `Process.clock_gettime` | 2.332 | small next to the loop |
| Python `getattr` | 1.442 | no meaningful cost |
| Ruby `send` | 1.938 | no meaningful cost |
| JavaScript `Reflect.get` | 8.168 | a few nanoseconds; not the Go `FieldByName` shape |

Name lookup that did clear the bar, still hint: C# `GetField` plus `GetValue` about 53× on .NET 10 versus a direct field (`cs-field-by-name-hot`; a cached `FieldInfo.GetValue` was still about 42×), Objective-C `valueForKey:` about 124× (`oc-value-for-key-hot`), Swift `value(forKey:)` about 35× (`sp-value-for-key-hot`).

Zig 0.17 `Io.Dir.openFileAbsolute` was about 2134× and `Io.Clock.awake.now` about 42×; both are hints with JSONL. Zig `json.parseFromSlice` of one unchanged object was about 2683× versus parsing once (`zp-json-hot`, hint). A first Swift `Date()` run and a first Objective-C `NSDate` run were discarded because the after loop was removed by the compiler. A rerun that keeps the result was about 244× and about 769×, and those two hints now have JSONL.

No standard-library object, so no slug and no number: C, C++, and Rust have no JSON parser in the standard library. Zig 0.17's standard library has no regular-expression compiler.

Not measured on this host, so no number and no new slug: JVM and Kotlin (no JDK / kotlinc), PHP, Dart, Lua, Nim, Elixir, ArkTS (do not copy the Node numbers).
