// Renders the camera scenes the Flutter renderer uses as its fake camera feed.
//
//   node scenes.mjs            # every scene
//   node scenes.mjs label      # just one
//
// For each scenes/<name>.html this:
//   1. generates the barcodes it needs with zxing-wasm's writer,
//   2. screenshots the page in Chromium as a 1080x1920 camera frame (1.5x),
//   3. decodes the screenshot with zxing-wasm's reader — so every code in the
//      scene is proven scannable — and records each code's corner points,
//   4. writes ../assets/scene_<name>.jpg and ../assets/scene_<name>.json.
//
// The JSON corners are in the 1080x1920 camera-frame coordinate space that
// mobile_scanner reports, which is what the scanner's barcode highlight
// overlay expects.

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { readBarcodes, writeBarcode } from 'zxing-wasm/full';

import { launchBrowser } from './lib/browser.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const assetsDir = path.resolve(here, '..', 'assets');

export const FRAME = { width: 1080, height: 1920 };
const SCALE = 1.5;

/** Appends the GS1 check digit to a 12-digit EAN-13 body. */
function ean13(body) {
  const digits = [...body].map(Number);
  const sum = digits.reduce((acc, d, i) => acc + d * (i % 2 === 0 ? 1 : 3), 0);
  return body + String((10 - (sum % 10)) % 10);
}

// Codes printed in the scenes. The 200–299 GS1 prefix is reserved for
// in-store use, so these EANs cannot collide with a real product.
export const CODES = {
  url: 'https://pub.dev/packages/ai_barcode_scanner',
  labelEan: ean13('200417240317'),
  boxEan: ean13('200512730048'),
  serial: 'AH40-7Q2K9X31',
};

async function svg(text, format, options = {}) {
  const result = await writeBarcode(text, { format, ...options });
  if (result.error) throw new Error(`${format} ${text}: ${result.error}`);
  // Drop the XML prolog and doctype so the SVG can be inlined in HTML.
  // Zint emits a fixed width/height with no viewBox, which would stop CSS from
  // scaling the symbol; give it one.
  return result.svg
    .replace(/<\?xml[^>]*>\s*/, '')
    .replace(/<!DOCTYPE[^>]*>\s*/, '')
    .replace(
      /<svg width="(\d+(?:\.\d+)?)" height="(\d+(?:\.\d+)?)"/,
      '<svg viewBox="0 0 $1 $2"',
    )
    // Print straight onto the label stock: no white backing rectangle, and
    // ink that is a touch softer than pure black.
    .replace(/<rect x="0" y="0" width="[^"]*" height="[^"]*" fill="#FFFFFF"\/>/, '')
    .replace('fill="#000000"', 'fill="#18181a"');
}

const SCENES = {
  label: {
    placeholders: async () => ({
      QR_SVG: await svg(CODES.url, 'QRCode', { ecLevel: 'M' }),
      EAN_SVG: await svg(CODES.labelEan, 'EAN13', { withHRT: true }),
    }),
    expect: [
      { format: 'QRCode', text: CODES.url },
      { format: 'EAN13', text: CODES.labelEan },
    ],
  },
  box: {
    placeholders: async () => ({
      EAN_SVG: await svg(CODES.boxEan, 'EAN13', { withHRT: true }),
      SERIAL_SVG: await svg(CODES.serial, 'Code128'),
      SERIAL: CODES.serial,
    }),
    expect: [
      { format: 'EAN13', text: CODES.boxEan },
      { format: 'Code128', text: CODES.serial },
    ],
  },
};

async function renderScene(browser, name) {
  const scene = SCENES[name];
  let html = await readFile(path.join(here, 'scenes', `${name}.html`), 'utf8');
  for (const [key, value] of Object.entries(await scene.placeholders())) {
    html = html.replaceAll(`{{${key}}}`, value);
  }

  const page = await browser.newPage({
    viewport: FRAME,
    deviceScaleFactor: SCALE,
  });
  await page.setContent(html, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  const png = await page.screenshot({ type: 'png' });
  const jpg = await page.screenshot({ type: 'jpeg', quality: 90 });
  await page.close();

  const found = await readBarcodes(png, { tryHarder: true, maxNumberOfSymbols: 8 });
  const barcodes = [];
  for (const want of scene.expect) {
    const hit = found.find((b) => b.format === want.format && b.text === want.text);
    if (!hit) {
      const seen = found.map((b) => `${b.format}:${b.text}`).join(', ') || 'nothing';
      throw new Error(`scene ${name}: ${want.format} "${want.text}" did not decode (saw ${seen})`);
    }
    const p = hit.position;
    barcodes.push({
      format: want.format,
      text: want.text,
      // Clockwise from top-left, scaled back to camera-frame coordinates.
      corners: [p.topLeft, p.topRight, p.bottomRight, p.bottomLeft].map((c) => [
        +(c.x / SCALE).toFixed(1),
        +(c.y / SCALE).toFixed(1),
      ]),
    });
  }

  await writeFile(path.join(assetsDir, `scene_${name}.jpg`), jpg);
  await writeFile(
    path.join(assetsDir, `scene_${name}.json`),
    `${JSON.stringify({ width: FRAME.width, height: FRAME.height, barcodes }, null, 2)}\n`,
  );
  console.log(`scene ${name}: ${barcodes.map((b) => b.format).join(' + ')} decoded`);
}

const wanted = process.argv.slice(2);
const names = wanted.length ? wanted : Object.keys(SCENES);
await mkdir(assetsDir, { recursive: true });
const browser = await launchBrowser();
try {
  for (const name of names) await renderScene(browser, name);
} finally {
  await browser.close();
}
