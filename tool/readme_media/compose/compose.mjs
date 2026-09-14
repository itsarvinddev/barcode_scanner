// Frames the screens rendered by ../test/render_test.dart into the README and
// pub.dev imagery.
//
//   node compose.mjs                  # everything
//   node compose.mjs hero gallery     # or any of: hero, gallery, pubdev, demo
//
// Reads  ../build/screens/*.png   (run `flutter test test/render_test.dart`)
// Writes ../../../assets/readme/*.webp
//
// Each page in templates/ is opened in headless Chromium, screenshotted to a
// PNG, and encoded with cwebp. Nothing here draws any part of the app: the
// phones show the rendered PNGs, and only the device frame, status bar,
// background and captions come from the templates.

import { execFileSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { launchBrowser } from './lib/browser.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const buildDir = path.resolve(here, '..', 'build');
const screensDir = path.join(buildDir, 'screens');
const pagesDir = path.join(buildDir, 'compose');
const framesDir = path.join(buildDir, 'framed');
const outDir = path.resolve(here, '..', '..', '..', 'assets', 'readme');

const CWEBP = process.env.CWEBP || 'cwebp';
const IMG2WEBP = process.env.IMG2WEBP || 'img2webp';

/** Every rendered screen, and whether its status bar sits on a dark app. */
export const SCREENS = {
  scan: { status: 'light' },
  detected: { status: 'light' },
  result: { status: 'light' },
  batch: { status: 'light' },
  themed: { status: 'light' },
  embedded: { status: 'dark' },
  permission: { status: 'light' },
};

/** The pub.dev carousel: one screen per image, with a caption. */
const PUBDEV = [
  { screen: 'scan', title: 'Scan any barcode or QR code', body: 'A full-screen scanner in one line of code.' },
  { screen: 'result', title: 'Results you can act on', body: 'Links, Wi-Fi, contacts and more, parsed and ready.' },
  { screen: 'themed', title: 'Make it yours', body: 'Brand colours, copy, scan window and controls.' },
  { screen: 'embedded', title: 'Embed it anywhere', body: 'Drop the scanner into your own screens and forms.' },
];

function encodeWebp(png, webp, quality) {
  execFileSync(CWEBP, ['-quiet', '-q', String(quality), '-m', '6', '-alpha_q', '100', png, '-o', webp]);
  const kb = (statSync(webp).size / 1024).toFixed(0);
  console.log(`  ${path.relative(path.resolve(here, '..', '..', '..'), webp)}  ${kb} KB`);
}

async function shoot(browser, page, query, { width, height, name, quality, scale = 2 }) {
  const tab = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: scale });
  const url = pathToFileURL(path.join(pagesDir, page));
  url.search = new URLSearchParams(query).toString();
  await tab.goto(url.href);
  await tab.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map((img) => img.decode()));
  });
  const png = path.join(framesDir, `${name}.png`);
  await tab.locator('#canvas').screenshot({ path: png, omitBackground: true });
  await tab.close();
  encodeWebp(png, path.join(outDir, `${name}.webp`), quality);
}

/**
 * Frames every PNG in build/screens/flow/ in turn and assembles them into an
 * animated WebP. One tab is reused, swapping the screen image per frame.
 */
async function animate(browser, { name, fps, scale, quality }) {
  const frames = readdirSync(path.join(screensDir, 'flow'))
    .filter((f) => f.endsWith('.png'))
    .sort();
  const dir = path.join(framesDir, name);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });

  const tab = await browser.newPage({ viewport: { width: 330, height: 666 }, deviceScaleFactor: scale });
  const url = pathToFileURL(path.join(pagesDir, 'screen.html'));
  // shadow=0: lossy animated WebP encodes each frame as a sub-rectangle blended
  // over the last, and the screen's bounding box reaches past the phone's
  // rounded corners into the soft drop shadow, where the semi-transparent
  // pixels compound into visible dark blocks. Without the shadow those corners
  // are fully transparent and the animation stays clean.
  url.search = new URLSearchParams({
    screen: `flow/${frames[0].replace('.png', '')}`,
    status: 'light',
    shadow: '0',
  }).toString();
  await tab.goto(url.href);
  const pngs = [];
  for (const frame of frames) {
    await tab.evaluate(async (src) => {
      const img = document.querySelector('.screen > img');
      img.src = src;
      await img.decode();
    }, `../screens/flow/${frame}`);
    const png = path.join(dir, frame);
    await tab.locator('#canvas').screenshot({ path: png, omitBackground: true });
    pngs.push(png);
  }
  await tab.close();

  const webp = path.join(outDir, `${name}.webp`);
  // -m 4 without -min_size encodes the whole loop in about a second. -min_size
  // and -m 6 search far harder (minutes for 120 frames) for a few percent.
  const args = ['-loop', '0', '-lossy', '-q', String(quality), '-m', '4', '-d', String(Math.round(1000 / fps))];
  execFileSync(IMG2WEBP, [...args, ...pngs, '-o', webp]);
  const kb = (statSync(webp).size / 1024).toFixed(0);
  console.log(`  ${path.relative(path.resolve(here, '..', '..', '..'), webp)}  ${kb} KB (${pngs.length} frames)`);
}

const missing = Object.keys(SCREENS).filter((n) => !existsSync(path.join(screensDir, `${n}.png`)));
if (missing.length) {
  console.error(`Missing rendered screens: ${missing.join(', ')}.\nRun \`flutter test test/render_test.dart\` in tool/readme_media first.`);
  process.exit(1);
}

rmSync(pagesDir, { recursive: true, force: true });
cpSync(path.join(here, 'templates'), pagesDir, { recursive: true });
mkdirSync(framesDir, { recursive: true });
mkdirSync(outDir, { recursive: true });

const parts = new Set(process.argv.slice(2));
const want = (part) => parts.size === 0 || parts.has(part);

const browser = await launchBrowser();
try {
  if (want('hero')) {
    console.log('hero');
    await shoot(browser, 'hero.html', {}, { width: 880, height: 440, name: 'hero', quality: 90 });
  }

  if (want('gallery')) {
    console.log('gallery');
    for (const [screen, { status }] of Object.entries(SCREENS)) {
      await shoot(browser, 'screen.html', { screen, status }, { width: 330, height: 666, name: `screen_${screen}`, quality: 90 });
    }
  }

  if (want('pubdev')) {
    console.log('pub.dev');
    for (const [i, shot] of PUBDEV.entries()) {
      await shoot(
        browser,
        'pubdev.html',
        { ...shot, status: SCREENS[shot.screen].status },
        { width: 540, height: 675, name: `pubdev_${i + 1}`, quality: 88 },
      );
    }
  }

  if (want('demo')) {
    console.log('demo');
    await animate(browser, { name: 'demo', fps: 20, scale: 2, quality: 82 });
  }
} finally {
  await browser.close();
}
