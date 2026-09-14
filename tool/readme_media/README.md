# README media

Generates the screenshots, banner and animation in
[`assets/readme/`](../../assets/readme) that the package README and pub.dev
page use.

Every phone screen is the package's **real widgets**: `AiBarcodeScanner`,
`AiBarcodeScanner.embedded`, `BarcodeResultSheet` and the permission view,
mounted exactly as an app would mount them and rendered to PNG by a Flutter
widget test. Nothing is repainted or mocked up. Only the device frame, status
bar, backgrounds and captions are added afterwards. This keeps the imagery in
step with the UI: when the UI changes, run the script again.

This directory is a private Flutter package (`publish_to: none`) plus a small
Node project. It is not meant to ship in the published `ai_barcode_scanner`
archive, and the root `analysis_options.yaml` excludes it.

## Regenerate

```sh
tool/readme_media/generate.sh
```

This runs stages 2 and 3 below and writes `assets/readme/*.webp`. It takes
about a minute and a half. Useful variants:

```sh
tool/readme_media/generate.sh --scenes      # also rebuild the camera scenes first
tool/readme_media/generate.sh hero pubdev   # re-compose only some outputs
```

### Prerequisites

| Tool | Used for | Notes |
| --- | --- | --- |
| Flutter (stable) | rendering the screens | `flutter` on `PATH`, or set `FLUTTER` |
| Node.js 18+ and npm | the compositor | `npm ci` runs automatically |
| Playwright Chromium | framing, and the camera scenes | `npx playwright install chromium` runs automatically. Set `CHROMIUM_PATH` to use an existing Chromium or Chrome, or `SKIP_BROWSER_INSTALL=1` to skip the install. `PLAYWRIGHT_BROWSERS_PATH` is honoured. |
| libwebp: `cwebp`, `img2webp` | WebP encoding | `brew install webp` or `apt install webp`. Override with `CWEBP` / `IMG2WEBP`. |

Fonts need no setup. The renderer loads Roboto and Material Icons from the
running Flutter SDK's `bin/cache/artifacts/material_fonts`, so text and icons
are real glyphs, not the test font.

## How it works

### 1. Camera scenes (`compose/scenes.mjs`, optional)

`compose/scenes/label.html` (a product label with a QR code and an EAN-13, on a
desk) and `compose/scenes/box.html` (a headphone box with an EAN-13 and a Code
128 serial) are staged in HTML with real barcodes from zxing-wasm's writer.
Each scene is screenshotted as a 1080x1920 camera frame and then decoded with
zxing-wasm's reader, which proves every code in it scans. The reader's corner
points are saved alongside.

Output: `assets/scene_<name>.jpg` and `assets/scene_<name>.json`. Both are
committed, so this stage only needs to run when a scene changes:

```sh
cd tool/readme_media/compose && npm ci && node scenes.mjs
```

The QR code encodes `https://pub.dev/packages/ai_barcode_scanner`. The EANs use
the GS1 in-store prefix (200–299), so they can never match a real product.

### 2. Screens (`test/render_test.dart`)

```sh
cd tool/readme_media
flutter pub get
flutter test test/render_test.dart
```

Each test sets up a 393x852 pt iPhone viewport (3x, with the notch and
home-indicator safe areas) and targets iOS. `FakeCameraPlatform`
(`test/src/fake_camera.dart`, adapted from the package's
`test/fake_mobile_scanner_platform.dart`) stands in for `mobile_scanner`. Its
camera view is the scene JPEG, and detections are pushed through the real
detection pipeline with the corner points decoded in stage 1. The test pumps
the clock to the right moment and reads the frame back from a
`RepaintBoundary`.

Output: `build/screens/<scene>.png` at 1179x2556, plus `build/screens/flow/`,
the 120 frames of the animation (6 s at 20 fps, rendered at 2x).

| Scene | What is mounted |
| --- | --- |
| `scan` | `AiBarcodeScanner` with the full-screen controls `showAiBarcodeScanner` enables, scanning a label |
| `detected` | The same scanner, 600 ms after a QR detection, in its success colours |
| `result` | `BarcodeResultSheet.show` for the detected URL, over the scanner |
| `batch` | `ScanMode.batch` with three codes collected (count badge on Done) |
| `themed` | `ScannerTheme.fromColors`, a full-border `ScannerOverlayConfig`, custom `ScannerLabels`, zoom slider and torch on |
| `embedded` | `AiBarcodeScanner.embedded` inside a Material 3 "Receive stock" form (`test/src/receive_stock_page.dart`) |
| `permission` | The scanner after the camera fails with `permissionDenied`, showing Try again and Open settings |
| `flow/` | Scan, QR detected, result sheet up, sheet dismissed, back to scanning. The scan line makes two full sweeps, so the loop is seamless. |

### 3. Compositing (`compose/compose.mjs`)

```sh
cd tool/readme_media/compose
npm ci
node compose.mjs                    # or: node compose.mjs hero gallery pubdev demo
```

The HTML templates in `compose/templates/` put the rendered PNGs inside a CSS
phone frame (`phone.css`, `phone.js`: rounded titanium band, Dynamic Island,
9:41 status bar, home indicator). Headless Chromium screenshots them and
`cwebp` / `img2webp` encode the results:

| Output | Size | Template |
| --- | --- | --- |
| `hero.webp` | 1760x880 | `hero.html`: title, tagline, platform chips, three phones (scan, result, themed) |
| `screen_<scene>.webp` | 660x1332 | `screen.html`: one framed phone on a transparent background |
| `pubdev_<n>.webp` | 1080x1350 | `pubdev.html`: caption and phone on a soft background (scan, result, themed, embedded) |
| `demo.webp` | 660x1332, 120 frames | `screen.html?shadow=0`: every `build/screens/flow/` frame, 20 fps, infinite loop |

The animation's phone has no drop shadow. Lossy animated WebP encodes each
frame as a rectangle blended over the previous one. The screen's rectangle
reaches past the phone's rounded corners into the shadow, and blending those
semi-transparent pixels again leaves dark blocks. `img2webp` runs with `-m 4`
and no `-min_size`, which encodes all 120 frames in about a second. The slower
settings take minutes and save only a few percent.

## Layout

```
tool/readme_media/
├── generate.sh              one-command regeneration
├── pubspec.yaml             private Flutter package (path dependency on ../..)
├── analysis_options.yaml
├── assets/                  committed camera scenes + decoded corner points
├── test/
│   ├── render_test.dart     the scenes
│   └── src/                 fake camera, harness (phone viewport, fonts, capture), demo app page
├── compose/
│   ├── package.json         playwright, zxing-wasm
│   ├── scenes.mjs           stage 1
│   ├── compose.mjs          stage 3
│   ├── lib/browser.mjs      Chromium launcher (honours CHROMIUM_PATH)
│   ├── scenes/              scene HTML
│   └── templates/           phone frame, hero, gallery and pub.dev layouts
└── build/                   generated, git-ignored
```

To check the Dart code:

```sh
cd tool/readme_media && flutter analyze --fatal-infos
```
