// Optional visual/accessibility QA: node scripts/check-svg-browser.cjs
// Requires Playwright and its Chromium browser. No network is used by the page.
const { chromium } = require('playwright');
const fs = require('node:fs');
(async () => {
  const browser = await chromium.launch({headless: true});
  try {
  console.log('Chromium ' + browser.version());
  const page = await browser.newPage({viewport: {width: 900, height: 650}, deviceScaleFactor: 1});
  const accessible = fs.readFileSync('output/accessible-calibration.svg', 'utf8');
  await page.setContent(accessible);
  const cdp = await page.context().newCDPSession(page);
  const tree = await cdp.send('Accessibility.getFullAXTree');
  const plot = tree.nodes.find(n => n.role?.value === 'image');
  if (plot?.name?.value !== 'Calibration' || !plot?.description?.value?.includes('A line shows the fitted series')) {
    throw new Error('SVG title/description missing from Chromium accessibility tree: ' + JSON.stringify(plot));
  }
  fs.writeFileSync('output/accessibility-inspection.json', JSON.stringify(plot, null, 2) + '\n');
  console.log('Chromium exposes image name and author-written description.');
  for (const variant of ['metrics-layout', 'metrics-deep']) {
    if (!fs.existsSync(`output/${variant}.svg`)) continue;
    let svg = fs.readFileSync(`output/${variant}.svg`, 'utf8');
    const font = fs.readFileSync(variant === 'metrics-deep' ? 'tests/fixtures/metrics-deep.ttf' : 'tests/fixtures/metrics.ttf').toString('base64');
    const semibold = fs.readFileSync('tests/fixtures/metrics-semibold.ttf').toString('base64');
    const style = `<defs><style>@font-face{font-family:'Sen Metrics Fixture';src:url(data:font/ttf;base64,${font}) format('truetype');font-weight:400;}@font-face{font-family:'Sen Metrics Fixture';src:url(data:font/ttf;base64,${semibold}) format('truetype');font-weight:600;}</style></defs>`;
    svg = svg.replace(/(<svg[^>]+>)/, '$1' + style);
    fs.writeFileSync(`tests/fixtures/${variant}.svg`, svg);
    await page.setContent(svg);
    await page.evaluate(() => document.fonts.ready);
    await page.evaluate(() => document.fonts.load('16px "Sen Metrics Fixture"'));
    const expected = fs.readFileSync(`output/${variant}.tsv`,'utf8').trimEnd().split('\n').map(row => {
      const [text, width] = row.split('\t'); return {text, width: Number(width)};
    });
    const inspected = await page.evaluate(() => {
      const root = document.querySelector('svg');
      return [...root.querySelectorAll('text')].map(el => {
        const box = el.getBBox(), transform = el.getCTM();
        const points = [[box.x,box.y],[box.x+box.width,box.y],[box.x,box.y+box.height],[box.x+box.width,box.y+box.height]].map(([x,y]) => new DOMPoint(x,y).matrixTransform(transform));
        return {text: el.textContent, width: el.getComputedTextLength(),
          inViewport: points.every(p => p.x >= -0.05 && p.y >= -0.05 && p.x <= root.width.baseVal.value+0.05 && p.y <= root.height.baseVal.value+0.05)};
      });
    });
    if (inspected.length !== expected.length) throw new Error('Text count mismatch');
    inspected.forEach((actual,i) => {
      if (actual.text !== expected[i].text || Math.abs(actual.width - expected[i].width)>Math.max(0.06, expected[i].width*0.001) || !actual.inViewport)
        throw new Error('Measured font bounds mismatch: '+JSON.stringify({actual, expected:expected[i]}));
    });
    fs.mkdirSync('docs/images',{recursive:true});
    await page.locator('svg').first().screenshot({path:`docs/images/${variant}.png`});
    fs.writeFileSync(`output/${variant}-inspection.json`, JSON.stringify(inspected,null,2)+'\n');
    console.log(`Chromium verified ${variant}: ${inspected.length} font measurements and in-canvas glyph bounds.`);
  }
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
