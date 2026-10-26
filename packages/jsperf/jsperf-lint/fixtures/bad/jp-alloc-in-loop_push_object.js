function bad(n) {
  const a = [];
  for (let i = 0; i < n; i++) {
    a.push({ i });
  }
  return a;
}
module.exports = { bad };
