# cperf static ↔ `-O2` benches

```sh
bash packages/cperf/scripts/run-static-vs-o2.sh
```

Builds `case1`…`case4`, lints `lint_probes/`, writes TSV/JSONL under `examples/bench/build/static-vs-o2/` (override with `CPERF_BENCH_OUT`).

## Evidence JSONL harnesses (package gate)

```sh
bash packages/cperf/scripts/regen-evidence-cp001.sh
bash packages/cperf/scripts/regen-evidence-cp002.sh
bash packages/cperf/scripts/regen-evidence-cp003.sh
```

| File | Rule |
|------|------|
| `cp001_malloc_vs_arena.c` | cp-alloc-hot |
| `cp002_realloc_growth.c` | cp-realloc-grow-one |
| `cp003_printf_hot.c` | cp-printf-hot |
| `case{1,2,3,4}_*.c` | correlation suite (smell\|clean modes) |
