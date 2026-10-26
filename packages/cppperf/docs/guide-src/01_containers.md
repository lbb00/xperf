## 1. Containers and strings

Repeated `push_back` without `reserve` reallocates when growth copies dominate (large N / many builders). Prefer sizing capacity once when the final size is known.

`std::string` `+=` / `append` of **multi-byte chunks** or a known final size benefits from `reserve`. Single-character `+=` under `-O2` is often already amortized (~1×) — do not treat every `+=` as a speed bug.

A `const std::string` or `const std::vector` parameter, and those types copied in a range-for, copies on every call or element. Out of line, a 64-byte string parameter was about 15× a const reference, and one `int` in a vector was about 17×. A range-for of 128-byte strings was about 21×, and a range-for of 64-int vectors was about 21×. A 4-character string stayed about 1.01×, an empty vector about 1.2×, and summing every byte of a 4096-byte string about 1.3×. The lint leaves non-const by-value parameters alone, because that is also how a function takes ownership.

Walking the packed bool specialization (`vector<bool>`) was about 12× a `vector<unsigned char>` over 2,000,000 elements. Indexed reads were about 4.2× and reserved `push_back` about 6.9×, under the bar. Eight million elements occupied 1,000,000 bytes in the packed container and 8,000,000 bytes in the byte container. The hint is the walk. It is not a reason to pack other bool fields, and keeping the packed layout is reasonable when the smaller size is the point.

Companion lint: **cx-const-by-value**, **cx-vector-bool** (default **hint**; measure before escalating). `push_back` of 500000 ints was about 2.0× without `reserve` on two runs, and a one-character `string::push_back` was slower with `reserve` (about 0.82× and 0.79×). CX001 stays retired: one matcher cannot tell those apart. The 2026-10-22 corpus verdict does not cover `cx-const-by-value` or `cx-vector-bool`.

