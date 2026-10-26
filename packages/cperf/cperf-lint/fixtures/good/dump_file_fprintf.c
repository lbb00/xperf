#include <stdio.h>
extern FILE *dump_file;
extern FILE *lra_dump_file;
void combine(int n) {
    for (int i = 0; i < n; i++) {
        if (dump_file)
            fprintf(dump_file, "i=%d\n", i);
        if (lra_dump_file != NULL)
            fprintf(lra_dump_file, "x\n");
    }
}
