## Lint map

| ID | Topic | Severity / note |
|----|--------|-----------------|
| cp-alloc-in-loop | malloc/calloc/realloc in loop | **error** — evidence; rare on VMs; sqlite/gcc teens–tens |
| cp-realloc-grow-one | realloc grow without capacity | **error** — evidence; almost never on mature trees |
| cp-printf-in-loop | printf/fprintf/puts in loop | **off** by default — hot YES / dead NEGATIVE; dump suppressions required |
| cp-strlen-in-cond | strlen in loop condition | **hint** — about 125× if recomputed, about 1× if hoisted |
| cp-strcat-in-loop | strcat/strncat in loop | **off** by default — about 221×; cold CLI/path OK-idiom |
| cp-sprintf-in-loop | formatted buffer write in loop | **hint** — JSONL present; not corpus-triaged |
| cp-fopen-in-loop | file open in loop | **hint** — JSONL present; not corpus-triaged |
| cp-gettime-in-loop | clock sample in loop (not bare `time`) | **hint** — JSONL present; not corpus-triaged |
| cp-wide-bool-flags | four or more full-width boolean flags in one struct | **hint** — JSONL present; not corpus-triaged |
| cp-regex-in-loop | `regcomp` in a loop (`regexec` is not matched) | **hint** — JSONL about 9.7×; not corpus-triaged |
| cp-alloca-in-loop | `alloca` / `__builtin_alloca` in a loop (a VLA is not matched) | **hint** — stack cover measured; wall clock about 1×; not corpus-triaged |
| cp-struct-by-value | by-value parameter of a struct whose visible lower bound is at least 512 bytes and four fields | **hint** — JSONL about 12.3× cross-TU; not corpus-triaged |

## References

- [corpus.md](corpus.md) — clone pins and r2→r3 tables
- Shared method: [XPerf playbook](../../../docs/playbook.md)
- Layout demos: `examples/p01_soa.c`, `examples/p02_restrict_note.c`
