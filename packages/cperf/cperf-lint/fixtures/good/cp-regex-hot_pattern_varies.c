#include <regex.h>

void good(char **pats, int n, const char *text) {
    for (int i = 0; i < n; i++) {
        regex_t re;
        if (regcomp(&re, pats[i], REG_EXTENDED) != 0) continue;
        regexec(&re, text, 0, 0, 0);
        regfree(&re);
    }
}
