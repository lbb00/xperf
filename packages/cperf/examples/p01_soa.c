/* AoS vs SoA sum — illustrative sizes only; time with your own harness.
 * cc -std=c17 -O2 -o p01 p01_soa.c && ./p01
 */
#include <stdio.h>
#include <stdint.h>

#define N 1024

typedef struct { float x, y, z, pad; } PointAoS;

int main(void) {
    static PointAoS aos[N];
    static float xs[N], ys[N], zs[N];
    float sum_aos = 0.f, sum_soa = 0.f;
    for (int i = 0; i < N; i++) {
        aos[i].x = (float)i;
        xs[i] = (float)i;
        ys[i] = 1.f;
        zs[i] = 2.f;
    }
    for (int i = 0; i < N; i++) sum_aos += aos[i].x;
    for (int i = 0; i < N; i++) sum_soa += xs[i];
    printf("sum_aos=%.0f sum_soa=%.0f\n", sum_aos, sum_soa);
    return 0;
}
