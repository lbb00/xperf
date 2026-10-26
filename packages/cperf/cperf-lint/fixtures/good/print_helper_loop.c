#include <stdio.h>
/* print_* pretty-printer: cp-printf-in-loop suppressed */
static void print_vn_ops(int n) {
    for (int i = 0; i < n; i++) {
        fprintf(stdout, "%d,", i);
    }
}
