#include <stdio.h>
/* Never called from hot path in the timed binary; still a cp-printf-hot-shaped loop. */
void dump_never_hot(int n) {
    for (int i = 0; i < n; i++) {
        printf("%d\n", i);
    }
}
void hot(int n) {
    int s = 0;
    for (int i = 0; i < n; i++) s += i;
    (void)s;
}
