function good(n) {
  const t = Date.now();
  const p = performance.now();
  let s = 0;
  for (let i = 0; i < n; i++) {
    s = t + p;
  }
  return s;
}
