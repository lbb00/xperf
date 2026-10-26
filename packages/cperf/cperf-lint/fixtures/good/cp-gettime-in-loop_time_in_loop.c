#include <sys/time.h>
#include <time.h>
void good(int n, time_t *out) {
    struct timeval tv;
    struct timespec ts;
    gettimeofday(&tv, 0);
    clock_gettime(CLOCK_MONOTONIC, &ts);
    for (int i = 0; i < n; i++) {
        out[i] = time(NULL);
    }
    (void)tv;
    (void)ts;
}
