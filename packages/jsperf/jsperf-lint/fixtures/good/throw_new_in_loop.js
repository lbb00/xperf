function check(items) {
  for (const x of items) {
    if (!x) throw new TypeError("missing");
    if (x.bad) throw new Error("bad");
  }
}
module.exports = { check };
