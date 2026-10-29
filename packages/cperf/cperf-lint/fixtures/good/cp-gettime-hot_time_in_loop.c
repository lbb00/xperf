#include <time.h>
void good(int n, time_t *out) {
    for (int i = 0; i < n; i++) {
        out[i] = time(NULL); /* fresh time required each iteration */
    }
}
