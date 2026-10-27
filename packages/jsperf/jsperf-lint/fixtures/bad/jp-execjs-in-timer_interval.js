function bad(page) {
  const script =
    "(() => { const n = document.querySelectorAll('.x'); return n.length; })()";
  setInterval(() => {
    page.executeJavaScript(script + "; /* drain */");
  }, 100);
}
module.exports = { bad };
