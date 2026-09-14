import { chromium } from 'playwright';

/**
 * Launches headless Chromium.
 *
 * Uses Playwright's own browser download (`npx playwright install chromium`)
 * unless CHROMIUM_PATH points at a specific Chromium or Chrome binary.
 */
export function launchBrowser() {
  const executablePath = process.env.CHROMIUM_PATH || undefined;
  return chromium.launch({
    executablePath,
    args: ['--font-render-hinting=none', '--force-color-profile=srgb'],
  });
}
