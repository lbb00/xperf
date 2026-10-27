function good(page) {
  return page.executeJavaScript(`
    const nodes = document.querySelectorAll('.row');
    return nodes.length;
  `);
}
module.exports = { good };
