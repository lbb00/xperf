export function build(n: number) {
  const out = [];
  for (let i = 0; i < n; i++) {
    out.push({ id: i, v: Math.random() });
  }
  return out;
}
