// Render docs/wiring/*.svg to PNG (one per sheet) and one 3-page PDF.
// Usage: node tools/render_diagrams.js   (needs Playwright with Chromium)
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const dir = path.join(__dirname, '..', 'docs', 'wiring');
  const names = ['reflow-wiring-ac-mains', 'reflow-wiring-low-voltage', 'reflow-layout-clearances'];
  const browser = await chromium.launch();
  const svgs = names.map(n => fs.readFileSync(path.join(dir, n + '.svg'), 'utf8'));
  for (let i = 0; i < names.length; i++) {
    const m = svgs[i].match(/width="(\d+)" height="(\d+)"/);
    const page = await browser.newPage({ viewport: { width: +m[1], height: +m[2] }, deviceScaleFactor: 2 });
    await page.setContent(`<body style="margin:0">${svgs[i]}</body>`);
    await page.screenshot({ path: path.join(dir, names[i] + '.png') });
    await page.close();
  }
  const page = await browser.newPage();
  await page.setContent('<style>@page{size:17in 11in;margin:0.3in}body{margin:0}' +
    'div{page-break-after:always;height:10.3in;display:flex;align-items:center;justify-content:center}' +
    'svg{max-width:100%;max-height:100%;width:auto;height:100%}</style>' +
    svgs.map(s => `<div>${s}</div>`).join(''));
  await page.pdf({ path: path.join(dir, 'reflow-wiring-all-sheets.pdf'), width: '17in', height: '11in', printBackground: true });
  await browser.close();
  console.log('wrote PNGs and PDF to', dir);
})();
