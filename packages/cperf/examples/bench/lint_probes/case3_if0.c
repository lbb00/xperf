#include <stdio.h>
#if 0
void dead(int n) {
    for (int i = 0; i < n; i++) {
        printf("%d\n", i);
    }
}
#endif
void hot(int n) {
    int s = 0;
    for (int i = 0; i < n; i++) s += i;
    (void)s;
}
