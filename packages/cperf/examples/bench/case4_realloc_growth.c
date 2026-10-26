#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
/* cp-realloc-grow-one: realloc(+1) vs capacity doubling. cc -O2
 * Usage: ./case4 smell|clean [N]
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static volatile uint64_t sink;

static uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static uint64_t run_smell(int n) {
    int *p = NULL;
    int len = 0;
    uint64_t s = 0;
    for (int i = 0; i < n; i++) {
        int *np = (int *)realloc(p, (size_t)(len + 1) * sizeof(int));
        if (!np) abort();
        p = np;
        p[len++] = i;
        s += (uint64_t)(unsigned)p[len - 1];
    }
    free(p);
    return s;
}

static uint64_t run_clean(int n) {
    int *p = NULL;
    int len = 0;
    int cap = 0;
    uint64_t s = 0;
    for (int i = 0; i < n; i++) {
        if (len + 1 > cap) {
            int ncap = cap ? cap * 2 : 8;
            if (ncap < len + 1) ncap = len + 1;
            int *np = (int *)realloc(p, (size_t)ncap * sizeof(int));
            if (!np) abort();
            p = np;
            cap = ncap;
        }
        p[len++] = i;
        s += (uint64_t)(unsigned)p[len - 1];
    }
    free(p);
    return s;
}

int main(int argc, char **argv) {
    const char *mode = argc > 1 ? argv[1] : "smell";
    int n = argc > 2 ? atoi(argv[2]) : 100000;
    if (n < 1) n = 1;
    uint64_t (*fn)(int) = (strcmp(mode, "clean") == 0) ? run_clean : run_smell;
    sink = fn(n / 10 > 0 ? n / 10 : 1);
    uint64_t t0 = now_ns();
    sink = fn(n);
    uint64_t t1 = now_ns();
    printf("%.6f\n", (t1 - t0) / 1e6);
    if (sink == UINT64_MAX) return 2;
    return 0;
}
