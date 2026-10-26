#include <stdlib.h>
void bad(int n) {
    for (int i = 0; i < n; i++) {
        void *p = malloc(64);
        (void)p;
    }
}
