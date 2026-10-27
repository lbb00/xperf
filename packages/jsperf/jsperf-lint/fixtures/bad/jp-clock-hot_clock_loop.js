function bad(n) {
  let s = 0;
  for (let i = 0; i < n; i++) {
    s = Date.now();
    s = performance.now();
  }
  return s;
}
