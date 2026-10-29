/* cp-printf-hot evidence: unbuffered fprintf loop vs buffered vs silent.
 *   cc -std=c11 -O2 -o cp003_printf_hot cp003_printf_hot.c
 *   ./cp003_printf_hot [N] [rounds]
 * Prints JSONL to stdout (rule cp-printf-hot). Primary before/after is
 * unbuffered vs _IOFBF (same call sites); silent is a ceiling ref.
 */
#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

static volatile int sink;
static char io_buf[1 << 20];

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

static int run_fprintf(size_t n, FILE *out) {
    int s = 0;
    for (size_t i = 0; i < n; i++) {
        fprintf(out, "%d\n", (int)(i & 1023));
        s += (int)(i & 1023);
    }
    return s;
}

static int run_silent(size_t n) {
    int s = 0;
    for (size_t i = 0; i < n; i++) s += (int)(i & 1023);
    return s;
}

static double time_unbuf(size_t n, FILE *out) {
    setvbuf(out, NULL, _IONBF, 0);
    sink = run_fprintf(n / 10 > 0 ? n / 10 : 1, out);
    double t0 = now_ms();
    sink = run_fprintf(n, out);
    return now_ms() - t0;
}

static double time_buf(size_t n, FILE *out) {
    setvbuf(out, io_buf, _IOFBF, sizeof io_buf);
    sink = run_fprintf(n / 10 > 0 ? n / 10 : 1, out);
    fflush(out);
    double t0 = now_ms();
    sink = run_fprintf(n, out);
    fflush(out);
    return now_ms() - t0;
}

static double time_silent(size_t n) {
    sink = run_silent(n / 10 > 0 ? n / 10 : 1);
    double t0 = now_ms();
    sink = run_silent(n);
    return now_ms() - t0;
}

static void iso_ts(char *buf, size_t n) {
    time_t t = time(NULL);
    struct tm tm;
    gmtime_r(&t, &tm);
    strftime(buf, n, "%Y-%m-%dT%H:%M:%SZ", &tm);
}

int main(int argc, char **argv) {
    size_t N = 80000;
    int rounds = 9;
    int warm = 2;
    if (argc > 1) N = (size_t)strtoull(argv[1], NULL, 10);
    if (argc > 2) rounds = atoi(argv[2]);
    if (N < 1000) N = 1000;
    if (rounds < 3) rounds = 3;

    FILE *out = fopen("/dev/null", "w");
    if (!out) return 1;

    for (int i = 0; i < warm; i++) {
        (void)time_unbuf(N / 20, out);
        (void)time_buf(N / 20, out);
        (void)time_silent(N / 20);
    }

    double *su = (double *)calloc((size_t)rounds, sizeof(double));
    double *sb = (double *)calloc((size_t)rounds, sizeof(double));
    double *ss = (double *)calloc((size_t)rounds, sizeof(double));
    if (!su || !sb || !ss) return 1;
    for (int r = 0; r < rounds; r++) {
        su[r] = time_unbuf(N, out);
        sb[r] = time_buf(N, out);
        ss[r] = time_silent(N);
    }
    double med_u = median(su, rounds);
    double med_b = median(sb, rounds);
    double med_s = median(ss, rounds);
    double ratio_buf = med_u / med_b;
    double ratio_silent = med_u / med_s;

    char ts[40];
    iso_ts(ts, sizeof(ts));
    const char *cc = "cc -std=c11 -O2";

    /* Primary after = buffered same-call fix; before = unbuffered smell */
    printf(
        "{\"rule\":\"cp-printf-hot\",\"case\":\"buffered_fprintf\",\"role\":\"after\","
        "\"node\":null,\"v8\":null,\"cc\":\"%s\",\"median_ms\":%.6f,"
        "\"ops\":%zu,\"ratio\":1,\"ts\":\"%s\"}\n",
        cc, med_b, N, ts);
    printf(
        "{\"rule\":\"cp-printf-hot\",\"case\":\"unbuffered_fprintf\",\"role\":\"before\","
        "\"node\":null,\"v8\":null,\"cc\":\"%s\",\"median_ms\":%.6f,"
        "\"ops\":%zu,\"ratio\":%.6f,\"ts\":\"%s\"}\n",
        cc, med_u, N, ratio_buf, ts);
    printf(
        "{\"rule\":\"cp-printf-hot\",\"case\":\"silent_compute_ref\",\"role\":\"ref\","
        "\"node\":null,\"v8\":null,\"cc\":\"%s\",\"median_ms\":%.6f,"
        "\"ops\":%zu,\"ratio\":%.6f,\"ts\":\"%s\"}\n",
        cc, med_s, N, ratio_silent, ts);

    fprintf(stderr,
            "cp-printf-hot N=%zu unbuf_ms=%.3f buf_ms=%.3f silent_ms=%.3f "
            "ratio_unbuf/buf=%.3f ratio_unbuf/silent=%.3f\n",
            N, med_u, med_b, med_s, ratio_buf, ratio_silent);
    fclose(out);
    free(su);
    free(sb);
    free(ss);
    return 0;
}
