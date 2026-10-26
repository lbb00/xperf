#include <regex.h>

void bad(const char *text, int n) {
    for (int i = 0; i < n; i++) {
        regex_t re;
        if (regcomp(&re, "a+", REG_EXTENDED) != 0) continue;
        regexec(&re, text, 0, 0, 0);
        regfree(&re);
    }
}
