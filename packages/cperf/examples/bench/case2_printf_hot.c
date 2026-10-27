#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
/* cp-printf-hot: printf in hot loop vs buffered / no-print. cc -O2
 * Usage: ./case2 smell|clean|silent [N]
 * smell  = setvbuf(_IONBF) + fprintf each iter
 * clean  = setvbuf large + fprintf each iter (same calls, buffered)
 * silent = compute only
 */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static volatile int sink;
static char io_buf[1 << 20];

static uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static int run_fprintf(int n, FILE *out) {
    int s = 0;
    for (int i = 0; i < n; i++) {
        fprintf(out, "%d\n", i & 1023);
        s += i & 1023;
    }
    return s;
}

static int run_silent(int n) {
    int s = 0;
    for (int i = 0; i < n; i++) s += i & 1023;
    return s;
}

int main(int argc, char **argv) {
    const char *mode = argc > 1 ? argv[1] : "smell";
    int n = argc > 2 ? atoi(argv[2]) : 80000;
    if (n < 1) n = 1;
    FILE *out = fopen("/dev/null", "w");
    if (!out) abort();

    if (strcmp(mode, "silent") == 0) {
        sink = run_silent(n / 10 > 0 ? n / 10 : 1);
        uint64_t t0 = now_ns();
        sink = run_silent(n);
        uint64_t t1 = now_ns();
        printf("%.6f\n", (t1 - t0) / 1e6);
    } else if (strcmp(mode, "clean") == 0) {
        setvbuf(out, io_buf, _IOFBF, sizeof io_buf);
        sink = run_fprintf(n / 10 > 0 ? n / 10 : 1, out);
        fflush(out);
        uint64_t t0 = now_ns();
        sink = run_fprintf(n, out);
        fflush(out);
        uint64_t t1 = now_ns();
        printf("%.6f\n", (t1 - t0) / 1e6);
    } else {
        setvbuf(out, NULL, _IONBF, 0);
        sink = run_fprintf(n / 10 > 0 ? n / 10 : 1, out);
        uint64_t t0 = now_ns();
        sink = run_fprintf(n, out);
        uint64_t t1 = now_ns();
        printf("%.6f\n", (t1 - t0) / 1e6);
    }
    fclose(out);
    if (sink == 0x7fffffff) return 2;
    return 0;
}
