#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
/* cp-alloc-hot: malloc-in-loop vs arena bump. cc -O2
 * Usage: ./case1 smell|clean [N]
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
    uint8_t *base;
    size_t len;
    size_t cap;
} Arena;

static void arena_init(Arena *a, size_t cap) {
    a->base = (uint8_t *)malloc(cap);
    a->len = 0;
    a->cap = a->base ? cap : 0;
}
static void *arena_alloc(Arena *a, size_t n) {
    size_t p = (a->len + 7u) & ~((size_t)7u);
    if (p + n > a->cap) return NULL;
    a->len = p + n;
    return a->base + p;
}
static void arena_reset(Arena *a) { a->len = 0; }
static void arena_free(Arena *a) {
    free(a->base);
    a->base = NULL;
    a->len = a->cap = 0;
}

static volatile uint64_t sink;

static uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static uint64_t run_smell(int n) {
    uint64_t s = 0;
    for (int i = 0; i < n; i++) {
        int *p = (int *)malloc(sizeof(int));
        if (!p) abort();
        *p = i;
        s += (uint64_t)(unsigned)*p;
        free(p);
    }
    return s;
}

static uint64_t run_clean(int n) {
    Arena a;
    arena_init(&a, (size_t)n * 16u + 4096u);
    if (!a.base) abort();
    uint64_t s = 0;
    for (int i = 0; i < n; i++) {
        int *p = (int *)arena_alloc(&a, sizeof(int));
        if (!p) {
            arena_reset(&a);
            p = (int *)arena_alloc(&a, sizeof(int));
            if (!p) abort();
        }
        *p = i;
        s += (uint64_t)(unsigned)*p;
    }
    arena_free(&a);
    return s;
}

int main(int argc, char **argv) {
    const char *mode = argc > 1 ? argv[1] : "smell";
    int n = argc > 2 ? atoi(argv[2]) : 200000;
    if (n < 1) n = 1;
    uint64_t (*fn)(int) = (strcmp(mode, "clean") == 0) ? run_clean : run_smell;
    /* warm */
    sink = fn(n / 10 > 0 ? n / 10 : 1);
    uint64_t t0 = now_ns();
    sink = fn(n);
    uint64_t t1 = now_ns();
    printf("%.6f\n", (t1 - t0) / 1e6);
    if (sink == UINT64_MAX) return 2;
    return 0;
}
