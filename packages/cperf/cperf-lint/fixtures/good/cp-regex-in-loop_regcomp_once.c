#include <regex.h>

void good(const char *text, int n) {
    regex_t re;
    if (regcomp(&re, "a+", REG_EXTENDED) != 0) return;
    for (int i = 0; i < n; i++) {
        regexec(&re, text, 0, 0, 0);
    }
    regfree(&re);
}
