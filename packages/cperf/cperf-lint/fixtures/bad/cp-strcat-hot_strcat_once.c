#include <string.h>
void good(char *dst, const char *a, const char *b) {
    dst[0] = '\0';
    strcat(dst, a);
    strcat(dst, b);
}
