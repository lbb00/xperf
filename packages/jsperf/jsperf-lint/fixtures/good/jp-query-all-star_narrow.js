function good(root) {
  /* Narrow walk — not querySelectorAll('*'), and no DOM query API. */
  return root.children;
}
module.exports = { good };
