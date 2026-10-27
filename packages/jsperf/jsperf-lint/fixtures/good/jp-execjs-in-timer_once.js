function good(page) {
  const script =
    "(() => { const n = document.querySelectorAll('.x'); return n.length; })()";
  page.executeJavaScript(script);
  setInterval(() => {
    page.executeJavaScript("window.__drain && window.__drain()");
  }, 100);
}
module.exports = { good };
