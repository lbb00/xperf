#include <stdio.h>
/* dump_* helpers: cp-printf-in-loop suppressed */
static void dump_items(int n) {
    for (int i = 0; i < n; i++) {
        printf("%d\n", i);
    }
}
