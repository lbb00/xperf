#include <stdlib.h>
#include <string.h>
/* Mimic libgcc emutls: capacity doubles; (size+1)*sizeof is header slot, not n+1 grow. */
void *emutls_grow(void *arr, size_t orig_size, size_t offset) {
    size_t size = orig_size * 2;
    if (offset > size)
        size = offset + 32;
    void *p = realloc(arr, (size + 1) * sizeof(void *));
    return p;
}
