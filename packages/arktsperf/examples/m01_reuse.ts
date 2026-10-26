export function fill(n: number, buf: number[]): number[] {
  buf.length = 0;
  for (let i = 0; i < n; i++) {
    buf.push(i);
  }
  return buf;
}
