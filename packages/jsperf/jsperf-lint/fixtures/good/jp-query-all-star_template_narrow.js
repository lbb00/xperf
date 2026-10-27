function good(page) {
  return page.executeJavaScript(`
    return document.body ? document.body.children.length : 0;
  `);
}
module.exports = { good };
