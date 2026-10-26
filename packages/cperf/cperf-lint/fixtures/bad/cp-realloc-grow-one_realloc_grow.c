#include <stdlib.h>
void *grow(void *p, int n) {
    return realloc(p, n + 1);
}
