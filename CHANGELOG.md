# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Versions apply to the whole repository and are git tags (see [docs/release.md](docs/release.md)).
Kits are not released separately and carry no version of their own.

## [Unreleased]
- **Docs site:** page links no longer keep a trailing `.md` (that 404s on GitHub Pages). Assemble rewrites them to trailing-slash directory URLs relative to the page directory, fails the build if any `.md` hrefs remain, emits static files as root-absolute paths so the `/zh/` locale works, and publishes `LICENSE` / `NOTICE` as directories so `trailingSlash` can open them.

- **All kits:** default matching is **`--scope all`** where the kit CLI supports it (opt in to **`--scope loop`** for the former in-loop-only match). Finding messages no longer imply non-loop sites are out of scope. Rule slugs containing `in-loop` were **renamed** to `*-hot` (including leftover `rs-map-new-in-loop` → `rs-map-new-hot`; see per-kit Renamed tables); old slugs are tombstoned under each kit `evidence/_removed/*.REMOVED.md` and must never be reused. See each kit `docs/rule-ids.md` Renamed table. jsperf also keeps adopter FP cuts + new hints from earlier commits on this branch. No severity escalations.

- jsperf-lint: default **`--scope all`** reports former in-loop smells everywhere (extreme-perf default); opt in to **`--scope loop`** for the old in-loop-only match. Finding messages and docs no longer imply non-loop sites are out of scope. Still includes loop-header / nested-function FP cuts; path skips for `e2e/`, `playwright-report/`, and `*.test.*` / `*.spec.*`; new hints `jp-query-all-star`, `jp-execjs-in-timer`, and `jp-clone-per-event` (stay hint); scanner reads JS inside `executeJavaScript` / `evaluate` templates. No severity escalations; `jp-string-plus-in-loop` stays tombstoned.

- Documentation site uses a Fumadocs layout: sidebar, command search, and Geist. The pages are assembled with Node.



- GitHub Pages site for the guides and kit docs, built from the Markdown already in the tree.

- Removed the checked-in C# bench executable and its .NET build outputs.

- Restored `rs-map-new-in-loop` as hint. Two quiet rustc 1.99 runs of 20000 one-key inserts were about 1.53× and 1.51× versus clearing one map. The same two runs left the large `Vec` fill at about 1.00× and the large `String` fill at about 1.03×, so those removals stay.

- Quiet reruns on current toolchains. Rust 1.99: `Instant::now` about 20× (the old 439× after-side was 0.008 ms), `File::open` about 416×, `Regex::new` on `regex` 1.13.1 about 963×. All stay hint. Nim 2.2.12 `&=` versus `join` was about 0.79×; `nm-string-amp-in-loop` is removed and the slug is not reused.

- Hint text for compile, parse, open, and clock rules now states the bench premise: hoist only when the pattern, text, path, or timestamp stays the same. A call whose argument is the loop binding is not reported. `Date` / `Stopwatch` / `Instant::now` inside a loop that `await`s is not reported in C#, Swift, and Rust. ArkTS no longer reports `JSON.parse` on a `for` / `forEach` / `map` head. Elixir `Enum.map`/`filter` says the cost grows with length.

- JavaScript `jp-string-plus-in-loop` is removed. `push` then `join` was not about 2× versus `+=` on a short literal, `String.fromCharCode`, or a 64-character literal (at 22000 characters `join` was slower). `jp-map-filter-chain` now has JSONL and stays hint: 35000 rows about 4.6× and 9.8×, a 3-row filter+map 1.28×. Hint lines state the bench premise. `readFileSync` in a `for` iterable, `Date.now` in a loop that `await`s, and `new RegExp` / `JSON.parse` / a DOM selector / `Intl.DateTimeFormat` whose argument is the loop binding are not reported.

- Measured the previously unbenched C and Swift shapes on this machine. `strlen` in a condition was about 125× a hoisted length when the string might change, and about 0.93× when `-O2` already hoists it (`cp-strlen-in-cond`, still hint). `strcat` of fixed chunks was about 221× an end pointer (`cp-strcat-hot`, stays off). Swift `reserveCapacity` was about 5× on many small arrays and about 1.6× on one large fill (`sp-array-no-reserve`, still hint). `print` to `/dev/null` was about 10× a `String` (`sp-print-hot`, stays off). Removed `sp-string-plus-in-loop` (reserve was slower), `sp-map-joined-chain` (about 1.2×), and `sp-force-unwrap-in-loop` (same time as `if let`).
- Removed measured-near-1× matchers: `at-object-delete` (~1.01× on a Node proxy), `cx-string-append-unreserved` (~1.09× time, capacity under 1.4×), `rs-string-plus-in-loop` (~1.00× on a large fill), `rs-vec-no-capacity` (~1.00× time and ~1.05× bytes on a large fill), and `zp-extern-struct-padding` (~1.21× walk, 24 bytes versus 16). Slugs are tombstoned and not reused. `format!` rebind, value-class allocation, and `alloca` stack growth stay.
- Zig hint: `allocPrint` / `Allocator.print` of an unchanged format string and arguments was about 50× on the general-purpose allocator, about 12× on an arena, and about 14× for a constant string (`zp-alloc-print-hot`). `bufPrint`, `Writer.print`, byte copies, and a 256-byte struct copy stayed at or under about 7× and were not added. Empty-buffer `writeByte` was about 130×, but the same call on a 4KiB buffer was about 1.2×, so it was not added. Default stays hint.
- C++ hints: `const std::string` / `const std::vector` by value was about 15–21× versus a const reference when the copy allocates (`cx-const-by-value`). A 4-character string was about 1× and is still hinted. Walking `vector<bool>` was about 12× a `vector<unsigned char>` (`cx-vector-bool`); the packed container is smaller. Hoisting `std::function` was slower (about 0.6×). Copying `shared_ptr` stayed under 7×. `map::operator[]` on missing keys was about 30× but the same spelling on existing keys was slower than `find`, so it was not added. Defaults stay hint.
- C hints: `alloca` in a loop covers the stack (20000 × 64 bytes versus one 64-byte buffer) while the touch time stays about 1× (`cp-alloca-hot`). A 512-byte struct passed by value across two translation units was about 12.3× versus a pointer (`cp-struct-by-value`). The same shape in one translation unit was about 1×. `fgetc` / `fputc` / `putc` were faster as a block read (about 24–120×) but were not added: a line matcher cannot tell a byte parser from a bulk read. Defaults stay hint.
- Cross-language check of file opens and clock samples. New hints, each with JSONL, where the same shape was costly and the standard library can reuse a handle or a sample: Python `open` (~409×), JavaScript `readFileSync` (~480×), `Date.now` (~26×), and `performance.now` (~19×), Go `os.Open` (~2300×) and `time.Now` (~104×), Ruby `File.read` (~346×), C# `File.ReadAllText` (~1560×) and `Stopwatch.GetTimestamp` (~15×), Rust `File::open` (~2750×) and `Instant::now` (~439×), Swift `contentsOfFile` (~414×), Objective-C `stringWithContentsOfFile` (~450×). C# `new Regex(` now matches `cs-regex-hot` (~7×, both sides still match). Python `perf_counter_ns` (~2.9×), Ruby `Process.clock_gettime` (~2.3×), `getattr` (~1.4×), `send` (~1.9×), and JavaScript `Reflect.get` (~8×) were checked and not added. Defaults stay hint.
- C++ `ifstream` of one one-byte file was about 2025× versus opening once (`cx-ifstream-hot`, hint). Zig 0.17 `openFileAbsolute` was about 2134× and `Clock.awake.now` about 42× (`zp-open-file-hot`, `zp-clock-hot`, hint). C# `GetField` plus `GetValue` each iteration was about 62× versus a direct field (`cs-field-by-name-hot`, hint). Zig `json.parseFromSlice` of one small object was about 2683× versus parsing once (`zp-json-hot`, hint). Objective-C `valueForKey:` was about 124× and Swift `value(forKey:)` about 35× versus a direct field (`oc-value-for-key-hot`, `sp-value-for-key-hot`, hint). Fair rerun of Swift `Date()` (~244×) and Objective-C `[NSDate date]` (~769×), with the after loop kept alive. Both are hints with JSONL. A discarded first run had deleted that loop.

- Fair reruns: removed `cx-sstream-in-loop`, `pp-regex-compile-in-loop`, `rs-map-new-in-loop`, `pp-datetime-format-in-loop`, `gp-time-parse-in-loop`, and `rb-date-parse-in-loop` (near 1×, or the only win was skipping the call). `cx-endl-hot` is about 23× on an external stream and about 0.9× on a string stream. `gp-reflect-hot` now matches name lookup and `reflect.New`; `TypeOf` was about 1.3× and is not matched. `cp-regex-hot`, `cx-clock-hot`, `cs-json-hot`, `rs-regex-new-hot`, `jp-dom-query-hot`, and `jp-intl-datetimeformat-hot` have JSONL and stay hint. A JSON or date value that changes every iteration cannot be hoisted. Java `SimpleDateFormat` was not added: no JDK in this environment.

- Hint rules for repeated compile, parse, query, format, and fresh-map work in Python, JavaScript, Go, C++, C#, Ruby, and Rust. Paired fixtures only. No JSONL, so none of them is `error`. The 2026-10-22 corpus verdict does not cover these slugs.
- C hints for `sprintf` / `fopen` / clock reads in a loop, and for four or more full-width boolean flags in one struct (`cp-wide-bool-flags`). Paired fixtures only. No JSONL. Not corpus-triaged.
- Swift hints for constructing a date formatter, a JSON decoder, or `NSRegularExpression` in a loop. Both the Swift scanner and the text fallback carry them. Paired fixtures only. No JSONL. Not corpus-triaged.
- Objective-C hints for allocating a date formatter, calling `NSJSONSerialization`, or building `NSRegularExpression` in a loop. Paired fixtures only. No JSONL. Not corpus-triaged.
- Microbench JSONL for the new hint rules that could be timed on one shape (compile/parse/format/copy). Defaults stay hint. `cx-endl-hot` and `gp-reflect-hot` were about 1×. `jp-dom-query-hot` and `rs-regex-new-hot` were not timed.

## [0.1.0] — 2026-10-22

Umbrella first public-shaped snapshot (Asia/Shanghai).

- 19 language kits under `packages/*`, corpus-ready under AGENT.md G3.
- Rule IDs are semantic slugs only (`{family}-{smell}`); numeric codes removed (no aliases).
- Measured-useless rules deleted (tombstones), not left as zombie `off`.
- Root README slimmed; kit status → `docs/kits.md`; run commands → `docs/quickstart.md`.
- ~124 active slugs at tag time; see each kit `docs/rule-ids.md`.
