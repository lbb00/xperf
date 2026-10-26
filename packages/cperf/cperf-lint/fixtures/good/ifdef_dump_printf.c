#include <stdio.h>
#ifdef DUMP
static void hot(int n) {
    for (int i = 0; i < n; i++) {
        printf("%d\n", i);
    }
}
#endif
void real_hot(int n) {
    int s = 0;
    for (int i = 0; i < n; i++) s += i;
    (void)s;
}
