function bad() {
  const m = new Map();
  m.set("a", 1);
  return m;
}
module.exports = { bad };
