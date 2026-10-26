# Static-check source collection

Public sources for performance and memory shapes a linter can see. A row here is not a measurement on this tree. Numbers below are the source's numbers. A new slug still needs a local before/after, and the default stays hint.

Dispositions:

- **already-ruled** — a slug in that kit already covers the shape.
- **measure-first** — the source describes a shape a scanner can see, and this tree has no slug for it yet.
- **rejected** — the source's own result is small, reversed, or not a stable rule.
- **no-compiler** — this machine cannot run that language, so the shape stays unmeasured.

## cperf

- `alloca` inside a loop keeps each chunk until the function returns. [Stack Overflow](https://stackoverflow.com/questions/5407546/memory-allocated-with-alloca-gets-freed-at-end-of-function-or-at-end-of-scope). **already-ruled** (`cp-alloca-in-loop`). Local stack cover was 1280000 bytes versus 64. The touch time was about 1×.
- `fgetc` / `fputc` one byte at a time. The question reports about 10× against a 4096-byte `fread`. [Stack Overflow](https://stackoverflow.com/questions/13225014/why-fgetc-too-slow). **rejected**. A local block read was faster, and a line matcher cannot tell a byte parser from a bulk read.
- `malloc` in a loop, `realloc` by one, `strcat`, `sprintf`, `fopen`, `gettimeofday`, and a wide run of boolean fields are **already-ruled**.

## cppperf

- Constructing `std::function` in a loop heap-allocates once the capture misses the small buffer. [The cost of captures](https://zvxryb.github.io/blog/2018/02/18/the-cost-of-captures/). **rejected**. A local sink rerun made the hoisted `std::function` slower (about 0.6×).
- Copying `shared_ptr` by value bumps an atomic count. [GotW #91](https://herbsutter.com/2013/06/05/gotw-91-solution-smart-pointer-parameters/) and [a pass-by-value writeup](https://ddanilov.me/shared-ptr-is-evil/). **rejected**. A local copy was about 4.8×, and `make_shared` of a changing value cannot be hoisted.
- `const std::string` / `const std::vector` by value was about 15–21× versus a const reference when the copy allocates. **already-ruled** (`cx-const-by-value`). A 4-character string was about 1× and the hint still fires.
- Walking `vector<bool>` was about 12× a byte vector, and the packed container used fewer bytes. **already-ruled** (`cx-vector-bool`).
- `std::string` append without reserve, `endl`, regex construction, clocks, and `ifstream` are **already-ruled**. String streams were removed after a fair rerun.

## csharpperf

- Building a string with `+` inside a loop allocates. [Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/strings/common-tasks/concatenate). **already-ruled** (`cs-string-plus-in-loop`).
- C# 10 interpolation no longer lowers to the old boxing `string.Format` path. [Microsoft .NET blog](https://devblogs.microsoft.com/dotnet/string-interpolation-in-c-10-and-net-6/). **rejected** as a "interpolation is slow" rule until a local .NET 8 run says otherwise.
- `File` reads, `Stopwatch.GetTimestamp`, `GetField`, JSON, regex, and `ToList` are **already-ruled**.

## goperf

- `s += part` in a loop copies the whole string. A pre-grown `strings.Builder` does one allocation. [String concatenation vs strings.Builder](https://vvivid.dev/posts/go_string_concat_vs_string_builder/). **already-ruled** (`gp-string-plus-in-loop`).
- `bytes.Buffer` vs `strings.Builder` on a short fragment list was about 1.5× on that machine. [brandur.org](https://brandur.org/fragments/bytes-buffer-vs-strings-builder). **rejected**.
- `fmt` in a loop, `json` of one payload, `os.Open`, `time.Now`, `regexp` compile, and `FieldByName` are **already-ruled**.

## jsperf

- `delete` on an object moves it to dictionary properties. [V8 fast properties](https://v8.dev/blog/fast-properties). **already-ruled** (`jp-delete-shape`).
- Deleting array elements, or reading a hole, flips element storage. [web.dev V8 tips](https://web.dev/articles/speed-v8). **already-ruled** (`jp-delete-array-hole`).
- Pre-allocating a huge array (the page cites more than 64K) is called out on that page. **measure-first** only for a literal huge `new Array(n)` a scanner can see without flagging normal arrays.
- Regex construction, `JSON.parse` of one payload, `readFileSync`, and `Date.now` / `performance.now` are **already-ruled**.

## pyperf

- CPython can make `+=` on `str` faster than `''.join` for some shapes. [String concatenation in Python](https://blog.ganssle.io/articles/2019/11/string-concat.html). **already-ruled** for `str` (`pp-str-plus-in-loop`). Do not add a second join rule from the old quadratic story alone.
- `[None] * n` versus `append` was about 1.3× in the posted timing. [Stack Overflow](https://stackoverflow.com/questions/63599687/is-it-better-to-pre-allocate-array-in-python-or-use-arr-append). **rejected**.
- `bytes` built with `+=` versus `b''.join` was reported far apart. [Fast bytes concatenation](https://www.guyrutenberg.com/2020/04/04/fast-bytes-concatenation-in-python/). **measure-first**.
- `open` and `json.loads` of one payload are **already-ruled**. `perf_counter_ns` and `getattr` were measured locally and not added.

## rubyperf

- Repeated `+` allocates. A buffer wants `<<`. [fast-ruby concatenation](https://github.com/fastruby/fast-ruby/blob/main/code/string/concatenation.rb). **already-ruled** (`rb-string-plus-in-loop`).
- `# frozen_string_literal: true` was about 1.2–1.3× on a tiny literal loop in that post. [FastRuby.io](https://www.fastruby.io/blog/ruby-3-4-new-defaults.html). **rejected** until a local run on a real file shows more.
- `File.read`, `Regexp.new`, and `JSON.parse` of one payload are **already-ruled**. `Process.clock_gettime` and `send` were measured locally and not added.

## rustperf

- `collect` allocates. Return the iterator, or `extend` an existing `Vec`. [The Rust Performance Book](https://nnethercote.github.io/perf-book/iterators.html). **already-ruled** in part (`rs-collect-vec-in-loop`).
- `iter().cloned().collect()` on a slice should be `to_vec()`. [Clippy `iter_cloned_collect`](https://github.com/rust-lang/rust-clippy/blob/master/clippy_lints/src/methods/iter_cloned_collect.rs). **measure-first**. The published claim is "faster", not a ratio.
- `.clone()` of a heap value inside a loop deep-copies. [Clones and allocations](https://rs4ts.dev/21-performance/03-optimization/). **measure-first**. Clippy's `redundant_clone` has historically skipped loop bodies ([rust-clippy#17495](https://github.com/rust-lang/rust-clippy/pull/17495)).
- `File::open`, `Instant::now`, and `Regex::new` are **already-ruled**. There is no JSON parser in the standard library.

## swiftperf

- `reserveCapacity` once on an empty array avoids geometric growth. Calling it every iteration with `count + k` copies repeatedly. [Hacking with Swift](https://www.hackingwithswift.com/articles/128/array-performance-append-vs-reservecapacity). Missing reserve is **already-ruled** (`sp-array-no-reserve`). Reserve-inside-the-loop is **measure-first**.
- `DateFormatter`, `JSONDecoder`, `NSRegularExpression`, `contentsOfFile`, `Date()`, and `value(forKey:)` are **already-ruled**.

## objcperf

- A long loop of convenience constructors (`[NSMutableString string]`) can pile up autoreleased objects. Apple documents an `@autoreleasepool` inside the loop to cut the peak. [Autorelease pool blocks](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmAutoreleasePools.html) and [Stack Overflow](https://stackoverflow.com/questions/16162878/autorelease-pool-blocks). **measure-first** for the missing pool. Creating the pool every iteration is cheap ([mikeash.com](https://www.mikeash.com/pyblog/autorelease-is-fast.html)), so the rule must not flag a pool that is already there.
- `stringByAppendingString`, `NSLog`, date formatters, JSON, regex, file reads, `NSDate`, and `valueForKey:` are **already-ruled**.

## zperf

- Building a new `ArrayList` on every iteration allocates. Reusing one list and calling `clearRetainingCapacity` matched a stack buffer in that thread. [ziglang/zig#16982](https://github.com/ziglang/zig/issues/16982). Heap allocation in a loop is **already-ruled** (`zp-alloc-in-loop`, `zp-create-destroy-in-loop`). Do not add a second slug for the same shape.
- `std.fmt.allocPrint` allocates a fresh slice. [lib/std/fmt.zig](https://github.com/ziglang/zig/blob/master/lib/std/fmt.zig). **already-ruled** (`zp-alloc-print-in-loop`) when the format string and arguments do not change. Local ReleaseFast medians: about 50× on the general-purpose allocator, about 12× on an arena, about 14× for a constant string. `bufPrint` and byte copies stayed at or under about 7× and were not added.
- File open, `Io.Clock`, and `json.parseFromSlice` of one payload are **already-ruled**. The 0.17 standard library has no regular-expression compiler.

## jvmperf

- `StringBuilder` instead of `+` in a loop is the classic shape. [byroot's comparison](https://byroot.github.io/ruby/performance/2025/10/28/string-literals.html) restates it. **already-ruled** (`jp-string-concat-in-loop`).
- `SparseArray` avoids boxing integer keys and is meant for a few hundred entries. [Android SparseArray](https://developer.android.com/reference/kotlin/android/util/SparseArray). **already-ruled** (`jp-android-sparse-array`).
- Boxed streams, regex, format, and the other JVM slugs stay as they are. This machine has no JDK that can run a new bench, so new JVM shapes are **no-compiler**.

## kotlinperf

- A lambda passed to a non-inline function allocates a closure. `inline` removes that object. [Kotlin inline functions](https://kotlinlang.org/docs/inline-functions.html). **no-compiler** (no `kotlinc` here). JVM already has `jp-lambda-to-non-inline-in-loop`.
- `SparseArray` on Android is the same note as jvmperf. **already-ruled** on the JVM side, not re-measured for Kotlin.
- String `+`, `println`, and `List` growth are **already-ruled** in this kit.

## phpperf

- PHP strings are mutable. `echo` of several arguments avoids a concatenate. [Stack Overflow](https://stackoverflow.com/questions/124067/php-string-concatenation-performance). `.` in a loop is **already-ruled** (`ph-string-dot-in-loop`).
- `implode` of a large array can use more peak memory than appending, in that SitePoint note. [SitePoint](https://www.sitepoint.com/high-performance-string-concatenation-in-php/). **no-compiler**.

## dartperf

- A cross-language string-build repo includes Dart and names `StringBuffer` as the builder. [langs_string_build_test](https://github.com/shagrouni/langs_string_build_test). That repo is not a controlled bench for this tree. String `+` in a loop is **already-ruled** (`dt-string-plus-in-loop`). Further Dart shapes are **no-compiler**.

## luaperf

- Collecting lines and calling `table.concat` cut a 350 KB read from 40 seconds to 0.5 seconds in Programming in Lua. [PIL 11.6](https://www.lua.org/pil/11.6.html). **already-ruled** (`lu-string-concat-in-loop`). This machine has no `lua`, so the book figure is not re-run. **no-compiler** for anything beyond that slug.

## beamperf

- Binary `<>` copies. An iolist is a list of chunks, and IO functions write it without building one binary. [Elixir IO data](https://hexdocs.pm/elixir/1.18.4/IO.html) and [iolist notes](https://www.openmymind.net/Elixir-A-Little-Beyond-The-Basics-Part-2-iolist/). List concatenation in a loop is **already-ruled** (`be-list-concat-reduce`). This machine has no Erlang or Elixir, so a new iolist slug is **no-compiler**.

## nimperf

- The same cross-language repo times Nim string building and does not isolate `setLen`. [langs_string_build_test](https://github.com/shagrouni/langs_string_build_test). String `&` and seq growth are **already-ruled**. Further Nim shapes are **no-compiler**.

## arktsperf

- If either operand of `+` is a string, the spec says a new string object is created when the expression is not constant. [ArkTS spec, additive expressions](https://yoyocat.github.io/ArkTSSpec/7_expressions.html). There is no string-plus slug in this kit yet. **no-compiler**. Do not copy JavaScript timings onto ArkTS.
- Allocation in a loop, `delete`, `console`, `includes`, and JSON are **already-ruled**.
