/* cp-realloc-grow-one evidence: realloc(+1) vs capacity doubling.
 *   cc -std=c11 -O2 -o cp002_realloc_growth cp002_realloc_growth.c
 *   ./cp002_realloc_growth [N] [rounds]
 * Prints JSONL to stdout (rule cp-realloc-grow-one).
 */
#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

static volatile uint64_t sink;

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

/* Smell: realloc grow-by-one each push (cp-realloc-grow-one). */
static double run_smell(size_t n) {
    int *p = NULL;
    int len = 0;
    uint64_t s = 0;
    double t0 = now_ms();
    for (size_t i = 0; i < n; i++) {
        int *np = (int *)realloc(p, (size_t)(len + 1) * sizeof(int));
        if (!np) abort();
        p = np;
        p[len++] = (int)i;
        s += (uint64_t)(unsigned)p[len - 1];
    }
    sink = s;
    double dt = now_ms() - t0;
    free(p);
    return dt;
}

/* Fix: capacity doubling. */
static double run_clean(size_t n) {
    int *p = NULL;
    int len = 0;
    int cap = 0;
    uint64_t s = 0;
    double t0 = now_ms();
    for (size_t i = 0; i < n; i++) {
        if (len + 1 > cap) {
            int ncap = cap ? cap * 2 : 8;
            if (ncap < len + 1) ncap = len + 1;
            int *np = (int *)realloc(p, (size_t)ncap * sizeof(int));
            if (!np) abort();
            p = np;
            cap = ncap;
        }
        p[len++] = (int)i;
        s += (uint64_t)(unsigned)p[len - 1];
    }
    sink = s;
    double dt = now_ms() - t0;
    free(p);
    return dt;
}

static void iso_ts(char *buf, size_t n) {
    time_t t = time(NULL);
    struct tm tm;
    gmtime_r(&t, &tm);
    strftime(buf, n, "%Y-%m-%dT%H:%M:%SZ", &tm);
}

int main(int argc, char **argv) {
    size_t N = 100000;
    int rounds = 9;
    int warm = 3;
    if (argc > 1) N = (size_t)strtoull(argv[1], NULL, 10);
    if (argc > 2) rounds = atoi(argv[2]);
    if (N < 1000) N = 1000;
    if (rounds < 3) rounds = 3;

    for (int i = 0; i < warm; i++) {
        (void)run_smell(N / 10);
        (void)run_clean(N / 10);
    }

    double *sm = (double *)calloc((size_t)rounds, sizeof(double));
    double *sa = (double *)calloc((size_t)rounds, sizeof(double));
    if (!sm || !sa) return 1;
    for (int r = 0; r < rounds; r++) {
        sm[r] = run_smell(N);
        sa[r] = run_clean(N);
    }
    double med_m = median(sm, rounds);
    double med_a = median(sa, rounds);
    double ratio = med_m / med_a;

    char ts[40];
    iso_ts(ts, sizeof(ts));
    const char *cc = "cc -std=c11 -O2";

    printf(
        "{\"rule\":\"cp-realloc-grow-one\",\"case\":\"capacity_doubling\",\"role\":\"after\","
        "\"node\":null,\"v8\":null,\"cc\":\"%s\",\"median_ms\":%.6f,"
        "\"ops\":%zu,\"ratio\":1,\"ts\":\"%s\"}\n",
        cc, med_a, N, ts);
    printf(
        "{\"rule\":\"cp-realloc-grow-one\",\"case\":\"realloc_plus_one\",\"role\":\"before\","
        "\"node\":null,\"v8\":null,\"cc\":\"%s\",\"median_ms\":%.6f,"
        "\"ops\":%zu,\"ratio\":%.6f,\"ts\":\"%s\"}\n",
        cc, med_m, N, ratio, ts);

    fprintf(stderr, "cp-realloc-grow-one N=%zu smell_ms=%.3f clean_ms=%.3f ratio=%.3f\n",
            N, med_m, med_a, ratio);
    free(sm);
    free(sa);
    return 0;
}
