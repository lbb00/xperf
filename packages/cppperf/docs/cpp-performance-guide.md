# C++ performance guide (v0)

Fewer reallocating containers, quieter hot paths.

> **Scope: C++17.** Claims that assert speedups name a local example or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.
>
> **cppperf vs cperf:** this kit is dedicated C++. Sibling **cperf** covers C11/C17 (+ light C++). Prefer this package for `std::vector` / `std::string` / iostream smells.

## How to read this

1. **Measure first** (`perf`, Tracy, `std::chrono`).
2. Treat each chapter as a checklist.
3. libstdc++ and libc++ differ — re-bench.

## Contents

- [How to read this](#how-to-read-this)
- [1. Containers and strings](#1-containers-and-strings)
- [2. Hot I/O](#2-hot-io)
- [Lint map](#lint-map)

## 1. Containers and strings

Repeated `push_back` without `reserve` reallocates when growth copies dominate (large N / many builders). Prefer sizing capacity once when the final size is known.

`std::string` `+=` / `append` of **multi-byte chunks** or a known final size benefits from `reserve`. Single-character `+=` under `-O2` is often already amortized (~1×) — do not treat every `+=` as a speed bug.

A `const std::string` or `const std::vector` parameter, and those types copied in a range-for, copies on every call or element. Out of line, a 64-byte string parameter was about 15× a const reference, and one `int` in a vector was about 17×. A range-for of 128-byte strings was about 21×, and a range-for of 64-int vectors was about 21×. A 4-character string stayed about 1.01×, an empty vector about 1.2×, and summing every byte of a 4096-byte string about 1.3×. The lint leaves non-const by-value parameters alone, because that is also how a function takes ownership.

Walking the packed bool specialization (`vector<bool>`) was about 12× a `vector<unsigned char>` over 2,000,000 elements. Indexed reads were about 4.2× and reserved `push_back` about 6.9×, under the bar. Eight million elements occupied 1,000,000 bytes in the packed container and 8,000,000 bytes in the byte container. The hint is the walk. It is not a reason to pack other bool fields, and keeping the packed layout is reasonable when the smaller size is the point.

Companion lint: **cx-const-by-value**, **cx-vector-bool** (default **hint**; measure before escalating). `push_back` of 500000 ints was about 2.0× without `reserve` on two runs, and a one-character `string::push_back` was slower with `reserve` (about 0.82× and 0.79×). CX001 stays retired: one matcher cannot tell those apart. The 2026-10-22 corpus verdict does not cover `cx-const-by-value` or `cx-vector-bool`.

## 2. Hot I/O

`std::cout << ...` in a tight loop flushes and formats. Prefer buffered writers or `{fmt}` / `printf` outside the loop when profiles show pressure.

No lint rule covers this smell (CX003 was retired).

## 3. Regex, flush, and the clock

Constructing `std::regex` inside a loop compiles every iteration. On a short haystack that was about 7.7× versus constructing it once. `std::endl` on an external stream flushes every insertion (about 23× versus a newline and one flush). The same manipulator on a string stream was about 0.87×, so that shape is not the finding. Sampling `steady_clock::now` every pass was about 147× versus sampling once; a loop that needs a fresh timestamp has nothing to hoist. Building a string stream every iteration was about 1.2× at `-O2` and that rule was removed. These lints stay **hint**. They are not part of the 2026-10-22 corpus verdict.

`ifstream` of one path was about 2025× versus opening once. A path that changes every iteration cannot be hoisted. This does not revive the removed CX003 id.

Companion lint: **cx-regex-ctor-hot**, **cx-endl-hot**, **cx-clock-hot**, **cx-ifstream-hot**.
## Lint map

| ID | Smell | Default |
|----|-------|---------|
| CX001 | removed (jitter) | — |
| cx-regex-ctor-hot | `std::regex` constructed in loop | **hint** (JSONL present; not corpus-triaged) |
| cx-endl-hot | `endl` flush in loop | **hint** (JSONL present; not corpus-triaged) |
| cx-clock-hot | clock sample in a loop | **hint** (JSONL; about 147× vs one sample; not corpus-triaged) |
| cx-ifstream-hot | file stream opened in a loop | **hint** (JSONL; about 2025× on one one-byte file; not corpus-triaged) |
| cx-const-by-value | `const` string or vector copied by value | **hint** (JSONL; about 15–21× when the copy allocates; not corpus-triaged) |
| cx-vector-bool | packed bool element container | **hint** (JSONL; walk about 12× vs a byte vector; not corpus-triaged) |
| CX003 | removed (jitter) | — |
| CX004 | removed (jitter) | — |

Escalate only with `evidence/cx-*.jsonl` — see [evidence-policy.md](evidence-policy.md). The retired CX004 showed that `-O2` can erase the effect; measure at `-O0` / sanitizers if claiming speed.

## References

- [XPerf playbook](../../../docs/playbook.md)
