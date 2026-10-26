#include <string.h>
int bad(const char *s) {
    int n = 0;
    for (int i = 0; i < (int)strlen(s); i++)
        n += s[i];
    return n;
}
