#include <sys/time.h>
#include <time.h>
void bad(int n) {
    for (int i = 0; i < n; i++) {
        struct timeval tv;
        struct timespec ts;
        gettimeofday(&tv, 0);
        clock_gettime(CLOCK_MONOTONIC, &ts);
        (void)tv;
        (void)ts;
    }
}
