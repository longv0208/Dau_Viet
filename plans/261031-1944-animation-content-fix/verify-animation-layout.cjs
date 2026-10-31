const { chromium, expect } = require('../../dau-viet-admin/node_modules/@playwright/test');
const { pathToFileURL } = require('node:url');
const path = require('node:path');
const fs = require('node:fs');
const assert = require('node:assert/strict');

(async () => {
  const root = path.resolve(__dirname, '../..');
  const browser = await chromium.launch({ headless: true, channel: 'chrome' });
  const results = [];
  try {
    for (const viewport of [{ width: 360, height: 800 }, { width: 390, height: 844 }, { width: 1280, height: 840 }]) {
      const page = await browser.newPage({ viewport });
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.goto(pathToFileURL(path.join(root, 'demo/html-animations/bach-dang-938-demo.html')).href);
      await page.locator('#dv-stage').waitFor();
      const bounds = await page.evaluate(() => {
        const box = selector => {
          const element = document.querySelector(selector);
          const r = element.getBoundingClientRect();
          return { x: r.x, y: r.y, width: r.width, height: r.height, bottom: r.bottom, position: getComputedStyle(element).position };
        };
        return { left: box('.tide-header__left'), subtitle: box('#dv-sub'), actions: box('.tide-header__actions'), canvas: box('.tide-canvas-wrap'), caption: box('.dv-cap-wrap'), legend: box('.tide-scene-legend'), bodyWidth: document.body.scrollWidth };
      });
      if (viewport.width <= 768) {
        assert.ok(bounds.actions.y - bounds.subtitle.bottom >= 0);
        assert.ok(bounds.actions.y - bounds.subtitle.bottom <= 12, JSON.stringify(bounds));
        assert.ok(bounds.left.height < 150);
        assert.ok(bounds.caption.y >= bounds.canvas.bottom - 1);
        assert.ok(bounds.legend.y >= bounds.caption.bottom - 1);
        assert.ok(bounds.bodyWidth <= viewport.width);
      }
      await page.locator('.tide-scene-legend').scrollIntoViewIfNeeded();
      assert.equal(await page.locator('.tide-legend-pill').count(), 3);
      assert.ok((await page.locator('#dv-caption').innerText()).length > 30);
      await page.locator('[data-phase-btn="ebb"]').click();
      await expect(page.locator('[data-phase-btn="ebb"]')).toHaveAttribute('aria-pressed', 'true');
      await page.locator('[data-phase-btn="high"]').click();
      assert.deepEqual(errors, []);
      await page.evaluate(() => window.scrollTo(0, 0));
      const screenshot = `layout-${viewport.width}x${viewport.height}.png`;
      await page.screenshot({ path: path.join(__dirname, screenshot), fullPage: true });
      results.push({ viewport, bounds, errors, screenshot });
      await page.close();
    }
    const output = { browser: browser.version(), results };
    fs.writeFileSync(path.join(__dirname, 'layout-results.json'), JSON.stringify(output, null, 2));
    console.log(JSON.stringify(output));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
