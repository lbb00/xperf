/* cp-alloc-hot evidence: malloc-in-loop vs arena bump for N small ints.
 *   cc -std=c11 -O2 -o cp001_malloc_vs_arena cp001_malloc_vs_arena.c
 *   ./cp001_malloc_vs_arena [N] [rounds]
 * Prints JSONL lines to stdout (rule cp-alloc-hot).
 */
#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
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

static void *arena_alloc(Arena *a, size_t n, size_t align) {
    size_t p = (a->len + align - 1) & ~(align - 1);
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

static double now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1e3 + (double)ts.tv_nsec / 1e6;
}

static int cmp_d(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

static double median(double *xs, int n) {
    qsort(xs, (size_t)n, sizeof(double), cmp_d);
    if (n % 2) return xs[n / 2];
    return 0.5 * (xs[n / 2 - 1] + xs[n / 2]);
}

/* Smell: malloc + free every iteration (cp-alloc-hot). */
static volatile int sink;

static double run_malloc_loop(size_t n) {
    double t0 = now_ms();
    int s = 0;
    for (size_t i = 0; i < n; i++) {
        int *p = (int *)malloc(sizeof(int));
        if (!p) abort();
        *p = (int)(i & 1023);
        s += *p;
        free(p);
    }
    sink = s;
    return now_ms() - t0;
}

/* Fix: one arena, bump per iter, reset once. */
static double run_arena(size_t n) {
    Arena a;
    size_t need = n * (sizeof(int) + 8) + 64;
    arena_init(&a, need);
    if (!a.base) abort();
    double t0 = now_ms();
    int s = 0;
    for (size_t i = 0; i < n; i++) {
        int *p = (int *)arena_alloc(&a, sizeof(int), _Alignof(int));
        if (!p) abort();
        *p = (int)(i & 1023);
        s += *p;
    }
    sink = s;
    double dt = now_ms() - t0;
    arena_reset(&a);
    arena_free(&a);
    return dt;
}

static void iso_ts(char *buf, size_t n) {
    time_t t = time(NULL);
    struct tm tm;
    gmtime_r(&t, &tm);
    strftime(buf, n, "%Y-%m-%dT%H:%M:%SZ", &tm);
}

int main(int argc, char **argv) {
    size_t N = 200000;
    int rounds = 9;
    int warm = 3;
    if (argc > 1) N = (size_t)strtoull(argv[1], NULL, 10);
    if (argc > 2) rounds = atoi(argv[2]);
    if (N < 1000) N = 1000;
    if (rounds < 3) rounds = 3;

    for (int i = 0; i < warm; i++) {
        (void)run_malloc_loop(N / 10);
        (void)run_arena(N / 10);
    }

    double *sm = (double *)calloc((size_t)rounds, sizeof(double));
    double *sa = (double *)calloc((size_t)rounds, sizeof(double));
    if (!sm || !sa) return 1;
    for (int r = 0; r < rounds; r++) {
        sm[r] = run_malloc_loop(N);
        sa[r] = run_arena(N);
    }
    double med_m = median(sm, rounds);
    double med_a = median(sa, rounds);
    double ratio = med_m / med_a;

    char ts[40];
    iso_ts(ts, sizeof(ts));
    const char *cc = "cc -std=c11 -O2";

    /* after = arena (clean); before = malloc-in-loop (smell) */
    printf(
        "{\"rule\":\"cp-alloc-hot\",\"case\":\"arena_bump\",\"role\":\"after\","
        "\"node\":null,\"v8\":null,\"cc\":\"%s\",\"median_ms\":%.6f,"
        "\"ops\":%zu,\"ratio\":1,\"ts\":\"%s\"}\n",
        cc, med_a, N, ts);
    printf(
        "{\"rule\":\"cp-alloc-hot\",\"case\":\"malloc_free_in_loop\",\"role\":\"before\","
        "\"node\":null,\"v8\":null,\"cc\":\"%s\",\"median_ms\":%.6f,"
        "\"ops\":%zu,\"ratio\":%.6f,\"ts\":\"%s\"}\n",
        cc, med_m, N, ratio, ts);

    fprintf(stderr, "cp-alloc-hot N=%zu malloc_ms=%.3f arena_ms=%.3f ratio=%.3f\n",
            N, med_m, med_a, ratio);
    free(sm);
    free(sa);
    return 0;
}
