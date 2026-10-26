// Number[] vs Float64Array sum — illustrative.
const N = 4096;
const a = new Array(N);
const t = new Float64Array(N);
for (let i = 0; i < N; i++) {
  a[i] = i;
  t[i] = i;
}
let sa = 0;
let st = 0;
for (let i = 0; i < N; i++) sa += a[i];
for (let i = 0; i < N; i++) st += t[i];
console.log(sa, st);
