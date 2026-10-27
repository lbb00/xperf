function good(page) {
  const script = "(() => { return window.__cachedCount || 0; })()";
  page.executeJavaScript(script);
  setInterval(() => {
    page.executeJavaScript("window.__drain && window.__drain()");
  }, 100);
}
module.exports = { good };
