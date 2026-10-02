// Génère ../index.html à partir de source.html : le contenu est écrit en dur
// pour que le site s'affiche aussi lorsque JavaScript est bloqué.
// Utilisation : npm install playwright && node build.js
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto("file://" + path.join(__dirname, "source.html") + "?prerender=1");
  const html = await page.evaluate(() => {
    document.documentElement.className = "no-js";
    return "<!doctype html>\n" + document.documentElement.outerHTML;
  });
  fs.writeFileSync(path.join(__dirname, "..", "index.html"), html);
  await browser.close();
})();
