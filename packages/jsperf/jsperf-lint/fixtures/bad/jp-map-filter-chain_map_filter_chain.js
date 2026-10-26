function bad(items) {
  return items.map((x) => x * 2).filter((x) => x > 0);
}
module.exports = { bad };
