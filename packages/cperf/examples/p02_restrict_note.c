/* restrict: document intent; wrong aliasing is UB.
 * cc -std=c17 -O2 -c p02_restrict_note.c
 */
void add_f32(float *restrict dst, const float *restrict a, const float *restrict b, int n) {
    for (int i = 0; i < n; i++) dst[i] = a[i] + b[i];
}
