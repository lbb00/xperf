#include <string.h>
int good(const char *s) {
    int n = 0;
    size_t len = strlen(s);
    for (size_t i = 0; i < len; i++)
        n += s[i];
    return n;
}
