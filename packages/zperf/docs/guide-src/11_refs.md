## References

### Official sources

- [Zig downloads and release dates](https://ziglang.org/download/)
- Release notes: [0.17.0](https://ziglang.org/download/0.17.0/release-notes.html) · [0.16.0](https://ziglang.org/download/0.16.0/release-notes.html) · [0.15.1](https://ziglang.org/download/0.15.1/release-notes.html) · [0.14.0](https://ziglang.org/download/0.14.0/release-notes.html)
- [Zig 0.17.0 language reference](https://ziglang.org/documentation/0.17.0/)
- Zig 0.17.0 standard library sources: `lib/std/heap.zig`, `heap/SmpAllocator.zig`, `heap/SafeAllocator.zig`, `heap/ArenaAllocator.zig`, `heap/BufferFirstAllocator.zig`, `heap/memory_pool.zig`, `multi_array_list.zig`, `mem.zig`, `hash_map.zig`, `deque.zig`, `sort.zig`, `bit_set.zig`, `enums.zig`, `static_string_map.zig`, `simd.zig`, `crypto/aes.zig`, `Io.zig`, `Io/Writer.zig`, `Io/File/MemoryMap.zig`, `os/linux/IoUring.zig`, `start.zig`, `debug.zig`, `zig/Ast.zig`, `zig/Zir.zig`, `zig/tokenizer.zig`
- [PR #7920: AST memory layout redesign](https://github.com/ziglang/zig/pull/7920) · [PR #15569: InternPool](https://github.com/ziglang/zig/pull/15569)
- [Issue #15137: PGO (not planned)](https://github.com/ziglang/zig/issues/15137) · [Issue #237](https://github.com/ziglang/zig/issues/237) · [Issue #1018: function multiversioning](https://github.com/ziglang/zig/issues/1018)

### Community sources

- Andrew Kelley: [A Practical Guide to Applying Data-Oriented Design (Handmade Seattle 2021)](https://handmade-seattle.com/media-sub/practical-data-oriented-design) · [transcript](https://josherich.me/podcast/andrew-kelley-practical-data-oriented-design-dod)
- TigerBeetle: [TIGER_STYLE.md](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md)
- matklad: [Reserve First](https://matklad.github.io/2025/08/16/reserve-first.html) · [Zig defer Patterns](https://matklad.github.io/2024/03/21/defer-patterns.html) · [Push Ifs Up And Fors Down](https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html)
- Mitchell Hashimoto: [Zig Parser](https://mitchellh.com/zig/parser) · [Ghostty's runtime SIMD dispatch with Highway](https://whnex.com/items/49012420)
- Bun: [PR #19134: Use Highway SIMD](https://github.com/oven-sh/bun/pull/19134)
- [oma: runtime SIMD dispatch for Zig](https://github.com/ATTron/oma) · [ziggit discussion](https://ziggit.dev/t/oma-runtime-simd-dispatch-for-zig/14438)
- [poop](https://github.com/andrewrk/poop)
- Video inspiration: Liu Yanpeng, “Write Code to Save Memory”: <https://v.douyin.com/KoVqTHbb9L0/>

### Corpus / upstream performance case studies

- TigerBeetle: [`static_allocator.zig`](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/static_allocator.zig) · [`message_pool.zig`](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/message_pool.zig) · [performance concepts](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/concepts/performance.md)
- http.zig: [issue #176 RSS / retain](https://github.com/karlseguin/http.zig/issues/176) · [issue #199 buffer pool](https://github.com/karlseguin/http.zig/issues/199)
- Ghostty: terminal `Offset` / page mmap · [PR #13264 scrollback compression](https://github.com/ghostty-org/ghostty/pull/13264) · [PR #13537 resize/reflow](https://github.com/ghostty-org/ghostty/pull/13537)
- Zig language corpus (sparse clone): `zig-corpus/zig` @ `8f0c6ce4` (Codeberg `ziglang/zig`); compiler `src/InternPool.zig` cited for sharding
