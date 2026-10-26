#include <stdio.h>
void bad(int n) {
    char buf[64];
    for (int i = 0; i < n; i++) {
        sprintf(buf, "%d", i);
        snprintf(buf, sizeof buf, "%d", i);
    }
}
