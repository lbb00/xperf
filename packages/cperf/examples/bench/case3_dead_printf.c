#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
/* Control / NEGATIVE: printf in never-called dump or #if 0.
 * Hot path is identical for smell vs clean; only dead code differs.
 * Usage: ./case3 smell|clean [N]
 */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static volatile int sink;

static uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

/* Named dump_* — cp-printf-hot may still flag body depending on suppressions. */
static void dump_table(int n) {
    for (int i = 0; i < n; i++) {
        printf("%d\n", i);
    }
}

#if 0
static void dead_codegen_printf(int n) {
    for (int i = 0; i < n; i++) {
        printf("dead %d\n", i);
    }
}
#endif

static int hot_work(int n) {
    int s = 0;
    for (int i = 0; i < n; i++) s += (i * 3) ^ (i >> 2);
    return s;
}

int main(int argc, char **argv) {
    const char *mode = argc > 1 ? argv[1] : "smell";
    int n = argc > 2 ? atoi(argv[2]) : 2000000;
    if (n < 1) n = 1;
    /* Never call dump_table in either mode — smell binary still contains it. */
    if (strcmp(mode, "clean") == 0) {
        /* clean: no dump_table reference so linker may drop it if static —
         * keep a volatile pointer only in smell build via #ifdef. */
    }
#ifdef INCLUDE_DEAD_DUMP
    if (argc > 1000) dump_table(n); /* unreachable */
#else
    (void)dump_table;
#endif
    sink = hot_work(n / 10 > 0 ? n / 10 : 1);
    uint64_t t0 = now_ns();
    sink = hot_work(n);
    uint64_t t1 = now_ns();
    printf("%.6f\n", (t1 - t0) / 1e6);
    if (sink == 0x7fffffff) return 2;
    return 0;
}
