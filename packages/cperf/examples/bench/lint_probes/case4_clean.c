#include <stdlib.h>
void *grow(void *p, int cap) {
    return realloc(p, (size_t)cap * 2u * sizeof(int));
}
