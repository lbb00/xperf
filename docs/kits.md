# Kit status

Lint entry points, default severities, and corpus notes for each package. Rule IDs are **slugs only**. Counts match each kit’s `docs/rule-ids.md` (tombstones excluded). Heuristic hits are review prompts, not speedups.

All **19** kits are **corpus-ready** under the AGENT.md G3 gate for the rule set triaged on 2026-10-22 (Asia/Shanghai). Hint rules added 2026-10-23 are **not** part of that verdict. Several now have a microbench and stay **hint**. Rules whose fair rerun stayed near 1× were removed. No corpus triage on the new slugs.

| Package | Lint | Active | Notes |
|---------|------|-------:|-------|
| [zperf](../packages/zperf/) | `zperf-lint` | 31 | Zig 0.17+. G3/r4 demoted OK-idiom mass rules; several defaults remain on (e.g. `zp-page-allocator-small`, `zp-broad-runtime-safety`). `zp-alloc-print-hot` is a hint for an unchanged format string. |
| [cperf](../packages/cperf/) | `cperf-lint` | 12 | C11 checker + presets. `cp-alloc-hot` / `cp-realloc-grow-one` error; strlen, sprintf, fopen, clock, wide-bool-flag, `regcomp`, `alloca`-in-loop, and large by-value struct hints; `cp-printf-hot` / `cp-strcat-hot` off under default app preset. The 2026-10-23 hints have a microbench and are not part of the corpus verdict. |
| [jsperf](../packages/jsperf/) | `jsperf-lint` | 11 | Pure Node ≥18, zero npm deps. `jp-delete-array-hole` error; map-filter / regex-ctor / JSON / DOM-query / `Intl.DateTimeFormat` / `readFileSync` / clock hints; alloc / console defaults off under app preset. `jp-string-plus-in-loop` removed (`push` + `join` was not ~2×). |
| [jvmperf](../packages/jvmperf/) | `jvmperf-lint` | 29 | Java (Gradle). Pin JDK **21** for tests. Mix of error / hint / off after G3/G4; see kit evidence policy. |
| [goperf](../packages/goperf/) | `goperf-lint` | 10 | `gp-append-nil-slice` / `gp-defer-hot` plus regexp / JSON / reflect-name-lookup hints; `gp-make-hot`–`gp-fmt-hot` off. `time.Parse` was removed. |
| [pyperf](../packages/pyperf/) | `pyperf-lint` | 6 | `pp-list-plus-rebind` plus JSON / deepcopy hints; `pp-str-plus-hot` / `pp-print-hot` off. `re.compile` and `datetime.strptime` were removed. |
| [swiftperf](../packages/swiftperf/) | `swiftperf-lint` | 8 | `sp-array-no-reserve` hint (small builders about 5×; one large fill about 1.6×). Print in a loop stays off (about 10× to /dev/null). Force-unwrap, string `+=`, and `map`/`joined` were removed. Date-formatter / JSON-decode / `NSRegularExpression` hints remain. The 2026-10-23 hints are not part of the corpus verdict. Text-lint path if Swift SDK absent. |
| [arktsperf](../packages/arktsperf/) | `arktsperf-lint` | 4 | Node lint over `.ets`/`.ts`/`.js`. `at-includes-hot` / `at-json-hot` hint; alloc / console defaults off. |
| [cppperf](../packages/cppperf/) | `cppperf-lint` | 6 | Dedicated C++17 (≠ cperf). regex, endl, clock, ifstream, const-by-value, and vector-bool hints. String append, string-stream, and several jitter ids **removed**. Short `const` strings stay near 1× and are still hinted. |
| [csharpperf](../packages/csharpperf/) | `csharpperf-lint` | 10 | Needs `dotnet`. `cs-regex-hot`, LINQ materialize, `string.Format`, and JSON hints; list-add / string-plus / console off. |
| [phpperf](../packages/phpperf/) | `phpperf-lint` | 3 | `ph-array-merge-rebind` error (G4); `ph-string-dot-hot` off; `ph-echo-hot` hint. |
| [rubyperf](../packages/rubyperf/) | `rubyperf-lint` | 6 | regexp / JSON / file-read hints; string-plus / array-plus / puts off. `Date.parse` and `Hash#merge` were removed. |
| [rustperf](../packages/rustperf/) | `rustperf-lint` | 7 | `rs-format-rebind-hot` error; println / collect / regex hint; `rs-alloc-hot` off. Amortized `+=`, `Vec::new` plus push, and `HashMap::new` in a loop were removed. |
| [kotlinperf](../packages/kotlinperf/) | `kotlinperf-lint` | 3 | Kotlin-first (≠ jvmperf JMH). All three rules off by default; one jitter id **removed**. |
| [objcperf](../packages/objcperf/) | `objcperf-lint` | 8 | Objective-C (≠ swiftperf). `oc-nsstring-append-hot` / `oc-nslog-hot` off; date-formatter, JSON, and regular-expression hints. Two jitter ids **removed**. |
| [dartperf](../packages/dartperf/) | `dartperf-lint` | 4 | `dt-growable-add-empty` hint; list-add / string-plus / print defaults off. |
| [luaperf](../packages/luaperf/) | `luaperf-lint` | 3 | `lu-string-concat-hot` error (G4); `lu-table-insert-hot` off; `lu-print-hot` hint. |
| [beamperf](../packages/beamperf/) | `beamperf-lint` | 4 | Elixir + Erlang. list-concat / map-merge / enum-chain hint; `be-io-puts-hot` off. One jitter id **removed**. |
| [nimperf](../packages/nimperf/) | `nimperf-lint` | 4 | Needs `nim`. `nm-seq-no-capacity` hint; seq-add / string / echo defaults off. |

No fabricated publish URL.

Historical numeric → slug map (CLI does **not** accept numerics): [rule-id-map.md](rule-id-map.md).
