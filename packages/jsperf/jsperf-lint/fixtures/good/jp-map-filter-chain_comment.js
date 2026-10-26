function good(items) {
  // set. filter().map() is a comment, not a call
  /*
  items.filter(Boolean).map((x) => x)
  */
  return items.map((x) => x);
}
module.exports = { good };
