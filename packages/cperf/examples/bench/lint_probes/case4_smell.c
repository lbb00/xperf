#include <stdlib.h>
void *grow(void *p, int n) {
    return realloc(p, (size_t)(n + 1) * sizeof(int));
}
