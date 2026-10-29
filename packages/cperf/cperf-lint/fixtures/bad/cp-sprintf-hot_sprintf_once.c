#include <stdio.h>
void good(char *buf, size_t cap, int n) {
    sprintf(buf, "%d", n);
    snprintf(buf, cap, "%d", n);
    for (int i = 0; i < n; i++) {
        buf[i] = 'a';
    }
}
