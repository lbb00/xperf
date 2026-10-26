#include <string.h>
size_t good(const char *s) {
    for (;;) {
        size_t n = strlen(s);
        if (n == 0) return 0;
        return n;
    }
}
