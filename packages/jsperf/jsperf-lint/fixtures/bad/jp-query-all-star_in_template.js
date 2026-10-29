function bad(page) {
  return page.executeJavaScript(`
    const nodes = document.querySelectorAll('*');
    return nodes.length;
  `);
}
module.exports = { bad };
