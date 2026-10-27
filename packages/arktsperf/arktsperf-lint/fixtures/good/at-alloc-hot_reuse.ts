export function build(n: number, out: number[]) {
  out.length = 0;
  for (let i = 0; i < n; i++) {
    out.push(i);
  }
  return out;
}
