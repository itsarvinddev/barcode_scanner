## 8.2.0

Clearer feedback when a scan is rejected, self-hosting the web decoder without
giving up the one-line scanner, and a rewritten README. No API breaks; the SDK
floor stays at Dart 3.7 / Flutter 3.29.

### Fixed

- **`ScannerLabels.invalidBarcode`, `noBarcodeFoundInImage` and
  `galleryUnsupported` had no effect.** They were added in 8.0.0 but never
  shown, so translating them changed nothing, and a rejected scan or an empty
  image got only a red flash and a haptic. Each now replaces the scan hint for
  a couple of seconds, in the same pill and colours, and is announced to screen
  readers. `invalidBarcode` appears when `validator` rejects a capture from the
  camera or a picked image, together with the rejection haptic and throttled by
  `scanCooldown` like it; a scan that reaches `onDetect` clears it at once.
  `noBarcodeFoundInImage` appears when a picked image yields `null` or an empty
  capture, from the built-in decoder or `galleryImageAnalyzer`, but not for a
  cancelled pick. `galleryUnsupported` appears when picking or analysing an
  image throws `UnsupportedError` (`UnimplementedError` included), as a
  `galleryImagePicker`, `galleryImageAnalyzer` or platform implementation
  without still-image support may; the error still reaches
  `onGalleryScanError` (or `FlutterError.reportError`) as before. Other gallery
  errors, such as an unreadable file, show no message. Set a label to `''` to
  turn that one message off.

  The messages follow `showScanHint`: they appear only where the hint does, so
  a scanner with `showScanHint: false`, and `AiBarcodeScanner.embedded`, whose
  hint is off by default, look exactly as they did. Flashes, haptics,
  callbacks and the idle hint are unchanged, and the usual guidance returns
  when a message clears.

### Added

- **`webBarcodeReader` and `webBarcodeLibraryScriptUrl` on
  `showAiBarcodeScanner` and `showAiBarcodeScannerBatch`**, forwarded to the
  scanner as-is. A web app whose Content Security Policy rules out jsDelivr can
  now self-host the detection library and keep the one-liner, instead of
  pushing `AiBarcodeScanner` itself.
- **`AiBarcodeScannerController.setWebImageDecoderScriptUrl`** — points the
  built-in web image decoder at a self-hosted copy of zxing-wasm without a
  scanner on the page, for apps that only scan images they already have with
  `analyzeScannerImage` or `analyzeImage`. Until now such an app always loaded
  zxing-wasm from jsDelivr, because only a mounted `AiBarcodeScanner` with
  `webBarcodeLibraryScriptUrl` could change that. Like that parameter, the
  setting is page-wide and the first URL wins; call it before the first scan,
  such as in `main`. It does nothing outside the web, and does not change where
  the camera loads its library from.
- **`ScanHint.announce`** — an optional flag (default `false`) that marks the
  message as a live region, so screen readers read it out when it appears.

### Documentation

- **Rewritten README** with a quick start up front, real screenshots of the
  8.x UI rendered from the package's widgets (replacing an illustration and
  photos of the pre-8.0 interface), and a **Build with AI assistants** section
  with copy-paste prompts.
- **`llms.txt`** — an integration brief for AI coding assistants, now shipped in
  the package: exact signatures and defaults, platform setup, compile-checked
  recipes, testing guidance and pitfalls.
- Corrected the iOS and macOS minimums (iOS 12.0 / macOS 10.14, from
  `mobile_scanner`; new Flutter 3.47 projects target iOS 15.0 / macOS 12.0), and
  documented that a plain `AiBarcodeScanner` shows a close button only when
  `ScannerAction.close` is enabled.
- The pubspec description no longer says the scanner is based on ML Kit, which
  is not true on the web.

## 8.1.0

Scanning from the gallery now works on the web, and the scanner works inside
apps built on Flutter 3.47's `material_ui`. No API breaks, the SDK floor stays
at Dart 3.7 / Flutter 3.29, and two gallery callbacks are deprecated in favour
of more capable ones. See the
[migration guide](https://github.com/itsarvinddev/barcode_scanner/blob/master/MIGRATION_GUIDE.md#80--81-optional)
— moving over is optional until 9.0.0.

### Added

- **Scan from gallery on the web**
  ([#199](https://github.com/itsarvinddev/barcode_scanner/issues/199)).
  `mobile_scanner`'s web backend still throws `UnsupportedError` from
  `analyzeImage`
  ([juliansteenbakker/mobile_scanner#1494](https://github.com/juliansteenbakker/mobile_scanner/issues/1494)),
  which is why the gallery button used to hide itself in the browser. The
  package now brings its own still-image decoder there: the browser decodes the
  picked file — any format it can display, with EXIF orientation applied — and
  zxing-wasm 3.1.3, the same build `mobile_scanner` uses for the camera, reads
  the pixels. Large photos are read downscaled first, and at full size only if
  that finds nothing — never above 16,777,216 pixels, iOS Safari's canvas
  limit. **The gallery button now appears on the web by default**,
  and `ScannerPlatformSupport.current.analyzeImage` is `true` there. It loads
  zxing-wasm from `webBarcodeLibraryScriptUrl` when an app hosts the library
  itself; with a `WebBarcodeReader.zxingJs` mirror, which it cannot use, the
  button stays hidden on the web unless `galleryImageAnalyzer` is given.
- **`ScannerImage`** — a still image to scan, given as a file path
  (`ScannerImage.path`), encoded bytes (`ScannerImage.bytes`) or an `XFile`
  (`ScannerImage.xFile`), with `readAsBytes()` to read any of them. Bytes work
  on every platform: on Android, iOS and macOS, whose decoders only open files,
  they are written to a temporary file for the analysis and deleted straight
  afterwards.
- **`galleryImagePicker`** on `AiBarcodeScanner`, `AiBarcodeScanner.embedded`
  and `showAiBarcodeScanner`. It replaces the built-in `image_picker` call and
  returns a `ScannerImage`, so a picker that only hands out bytes — a web file
  input, the clipboard, a download — can feed the scanner. The picked image
  still runs through `validator`, feedback and the overlay flash.
- **`onGalleryImagePick`** — called with every picked `ScannerImage`, or
  `null` when the user cancelled, before the image is analysed.
- **`galleryImageAnalyzer`** — replaces the scanner's own decoding of picked
  images, on every platform. It receives the image and the formats the scanner
  is restricted to, and returns a `BarcodeCapture`. Use it for a web app whose
  Content Security Policy cannot allow jsDelivr, an offline or self-hosted
  deployment, or a decoder of your own; the built-in web decoder is then never
  loaded.
- **`AiBarcodeScannerController.analyzeScannerImage`** — scans a
  `ScannerImage` your app obtained some other way, such as from a share intent
  or the clipboard. It is what the gallery button uses.
- **`AiBarcodeScannerController.analyzeImage` works on the web.** The path
  there is a URL the page can fetch: a `blob:` URL (which is what `XFile.path`
  is in the browser), a `data:` URL, or an `http(s):` URL the page is allowed
  to read. `mobile_scanner` is still asked first, so its own implementation
  takes over the day it ships one. `controller.raw.analyzeImage` — the
  unwrapped `mobile_scanner` call — still throws on the web.
- `showAiBarcodeScanner` also accepts `onGalleryScanError`.
- The example app has a "Scan image bytes" demo: a gallery picker that returns
  bytes, which works on the web too.
- CI runs the web decoder's tests in Chrome under both dart2js and dart2wasm,
  whose JS interop differs.

### Flutter 3.47 and `material_ui`

Flutter now publishes Material and Cupertino as the separate `material_ui` and
`cupertino_ui` packages (usable from Flutter 3.44), while
`package:flutter/material.dart` still ships in the SDK. A `material_ui`
`MaterialApp` provides its own `Theme`, `MaterialLocalizations` and
`ScaffoldMessenger`: types that the
`flutter/material` widgets this package is built from cannot see. Without
`MaterialUiCompatibilityBridge`, the scanner threw "No MaterialLocalizations
found" whenever it showed its app bar (as `showAiBarcodeScanner` does by
default), and `BarcodeResultSheet.show` threw from `showModalBottomSheet`
([#198](https://github.com/itsarvinddev/barcode_scanner/issues/198)).

- **The scanner works inside `material_ui` apps without
  `MaterialUiCompatibilityBridge`**, in any locale — and in a bare `WidgetsApp`.
  The `flutter/material` localizations it needs are supplied to its own subtree
  only when missing, layered over the app's so the app's locale and text
  direction still apply.
- **`BarcodeResultSheet.show` opens in those apps** on a lightweight route of its
  own, with the same slide-up entrance, a dimmed barrier that dismisses it, and
  drag-down to dismiss. The barrier's screen-reader label is the new
  `ScannerLabels.dismissSheetLabel`.
- **Copying from the result sheet is confirmed without a `ScaffoldMessenger`.**
  Where there is none to show the "Copied" snack bar, the copy button itself
  briefly shows the confirmation and announces it to screen readers; the
  confirmation used to be skipped silently.
- **The embedded scanner's zoom slider** no longer throws "No Material widget
  found" on a page without a `flutter/material` `Material` — which includes a
  `material_ui` `Scaffold`, even with the bridge installed.
- **Controls that follow the app's `Theme`** — the retry and open buttons, the
  disabled batch "Done" button, the disabled copy and share actions — take
  their colours from the `ScannerTheme` when there is no `flutter/material`
  `Theme`, instead of the SDK's baseline purple and near-black.
- **`ScannerTheme.fromColors`** derives a scanner theme from individual colours
  — only `primary` is required — so a `material_ui` `ColorScheme`, which
  `ScannerTheme.fromColorScheme` cannot accept, can still theme the scanner.
  Given the same five colours both produce an identical theme;
  `fromColorScheme` now delegates to it.
- **Nothing changes in a classic `MaterialApp`.** The result sheet is still
  `showModalBottomSheet`, copying still shows a `SnackBar`, the controls still
  follow the app's `ColorScheme`, and the scanner inserts no localizations or
  `Material` of its own.
- The package keeps importing `flutter/material` throughout 8.x. Moving to
  `material_ui` would take theme and localizations away from every app that
  has not migrated — there is no reverse bridge — and would raise the Flutter
  floor to 3.44, so, as Flutter advises for this migration, it is being treated
  as a breaking change. **The full migration is planned for 9.0.0.**

### Deprecated

- **`imagePicker`** → `galleryImagePicker`. Return
  `ScannerImage.path(path)` for the same behaviour as before. Passing both
  trips an assertion.
- **`onImagePick`** → `onGalleryImagePick`. It is still called, after
  `onGalleryImagePick`, for a cancelled pick and for any image with a path, but
  not for an image picked as bytes, which has none.
- Both keep working throughout 8.x and are planned for removal in 9.0.0.
  Passing either to `AiBarcodeScanner` or `AiBarcodeScanner.embedded` now
  produces a `deprecated_member_use` info in the analyzer, which
  `flutter analyze --fatal-infos` treats as a failure.

### Notes

- **On the web, the first scanned image downloads zxing-wasm from jsDelivr**: a
  38 KB script (13 KB compressed) from `cdn.jsdelivr.net`, then its WebAssembly
  binary from `fastly.jsdelivr.net` — roughly 460 KB compressed, 1.1 MB
  uncompressed, and cached by the browser afterwards. Nothing is downloaded
  until an image is scanned, and nothing at all when `mobile_scanner` has
  already loaded zxing-wasm for the camera.
- **A Content Security Policy has to allow it**: `https://cdn.jsdelivr.net` and
  `'wasm-unsafe-eval'` in `script-src`, and `https://fastly.jsdelivr.net` in
  `connect-src` — plus `blob:`, through which a picked file is read back, and
  `data:` if you pass `data:` URLs to `analyzeImage` or `ScannerImage.path`.
  When the decoder cannot load, or the image cannot be read, the scan fails
  with a `MobileScannerBarcodeException` that says what to allow. A failed
  download is not remembered — not even one that failed under the camera's
  zxing-wasm reader — so the next scan tries again. Apps that cannot allow
  these hosts, or that work offline, can pass `galleryImageAnalyzer`.
- The gallery button is part of the live scanner's controls, so it does not
  appear over the error screen shown when the camera cannot start. To scan
  images without a camera, call `analyzeScannerImage` from your own UI.
- `AiBarcodeScannerController.analyzeImage` and `analyzeScannerImage` now run
  one analysis at a time per controller on Android, iOS and macOS. On Android,
  `mobile_scanner` tracks only one: a call that overlapped another used to
  leave the earlier one waiting forever.
- In a `material_ui` app, the few strings the scanner does not render itself —
  the text selection toolbar and some framework tooltips — use the SDK's English
  defaults. Everything in `ScannerLabels` is unaffected.
- The README's Android minimums were understated: `mobile_scanner` 7.4.1 needs
  Android Gradle Plugin 8.9.1+, compileSdk 36, minSdk 23 and Kotlin Gradle
  Plugin 2.x, which apps created from Flutter 3.29-era templates have to raise.
  Nothing changed in 8.1.0 itself.
- `web: ^1.0.0` is now a direct dependency, for the web decoder. It was already
  required by `mobile_scanner` with the same constraint, so resolution does not
  change.

## 8.0.1

- Raised the floor to `mobile_scanner >= 7.4.1`, published a few hours after
  8.0.0's dependency audit. It fixes the false-positive
  `plugins that apply Kotlin Gradle Plugin (KGP): mobile_scanner` warning on
  AGP 9 by moving the plugin's Gradle files to the Kotlin DSL, and — more
  importantly — barcode scanning permanently stalling after a leaked camera
  frame, a host-app crash when CameraX fails to initialise, and an
  `EXC_BAD_ACCESS` on iOS when the app is terminated with the camera running.
  8.0.0's `>=7.4.0` constraint already resolved 7.4.1 for a fresh `pub get`;
  this stops an existing lockfile from holding anyone on 7.4.0.
- Corrected the README's troubleshooting entry for that warning, which said it
  could not be fixed and would keep printing.
- Documented that upgrading across 7.4.0 -> 7.4.1 needs a `flutter clean`.
  That release moved the plugin's Gradle files from Groovy to the Kotlin DSL,
  and a build directory left over from 7.4.0 fails with
  `cannot find symbol: class MobileScannerPlugin`. Verified: the build fails
  incrementally and succeeds after a clean.

## 8.0.0

A rewrite. Every camera capability of `mobile_scanner` 7.4.0 is now a plain
widget parameter, on top of a scanner UI that is responsive, capability-aware,
themeable and localisable. See the
[migration guide](https://github.com/itsarvinddev/barcode_scanner/blob/master/MIGRATION_GUIDE.md)
— most apps need a one-line change or none at all.

### Fixed

- **`GalleryButtonType.none` hid every control**, not just the gallery button
  ([#176](https://github.com/itsarvinddev/barcode_scanner/issues/176)). Gallery
  visibility and control visibility are now independent. A custom
  `appBarBuilder` or a `child` no longer removes the controls either.
- **`Null check operator used on a null value`** when the scanner was popped
  while a camera flip or torch toggle was in flight
  ([#187](https://github.com/itsarvinddev/barcode_scanner/issues/187)). The
  chrome no longer calls `setState` after an `await`; it listens to the
  controller instead, so it also picks up torch and zoom changes the platform
  reports on its own.
- **Barcodes inside the reticle would not scan**
  ([#166](https://github.com/itsarvinddev/barcode_scanner/issues/166)). Two
  causes: the scan window was computed from the *screen* rather than the camera
  preview's box, so an app bar or bottom sheet pushed it out of alignment; and
  Android requires a barcode to be *entirely* inside the window and drops any
  barcode with no reported corner points. The window is now derived from the
  preview's constraints, and detection is no longer restricted to it by default
  (`restrictDetectionToScanWindow: false`).
- **Empty boxes instead of icons on iOS**
  ([#188](https://github.com/itsarvinddev/barcode_scanner/issues/188)). The
  default icons were `CupertinoIcons`, whose font is only bundled when the app
  itself depends on `cupertino_icons`. Defaults are now Material icons, which
  every app with `uses-material-design: true` already ships.
- **16 KB page size compliance**
  ([#168](https://github.com/itsarvinddev/barcode_scanner/issues/168),
  [#171](https://github.com/itsarvinddev/barcode_scanner/issues/171)). Requires
  `mobile_scanner >= 7.4.0`, which pulls ML Kit 17.3.0 — 16 KB aligned on both
  64-bit ABIs. The README documents the AGP/NDK requirements and how to clear a
  stale pub cache.
- **The camera never paused with the app lifecycle.** `useAppLifecycleState` was
  inert, because `MobileScanner` only manages the lifecycle for a controller it
  created and this package always supplied one. The scanner now observes the
  lifecycle itself.
- **Disposing the scanner unlocked every device orientation**, clobbering an
  orientation policy set by the host app. Orientation is now left alone unless
  you set `preferredOrientations`.
- **A failed gallery scan gave no feedback** and escaped as an unhandled async
  error. It now flashes the overlay and reports through `onGalleryScanError`.
- **Permission denials rendered as "An unknown error occurred."** The error view
  now distinguishes permission denied, no usable camera, and everything else,
  with retry and an `onOpenSettings` hook.
- **Pinch-to-zoom was neither symmetric nor proportional** — a gentle spread
  saturated the zoom while the matching pinch barely moved it — and it rebuilt
  the entire tree on every gesture frame.
- **`ScannerCornerPainter` and `ScanningLinePainter` under-reported repaints**,
  so animating `cornerLength`, `lineThickness` or the colours did nothing.
- **`ScannerOverlayConfig.animation` was accepted and ignored.** It is honoured
  now, and the overlay's ticker stops entirely when no animation is drawn.
- **`key` was forwarded to the inner `MobileScanner`**, so
  `AiBarcodeScanner(key: GlobalKey())` threw "Multiple widgets used the same
  GlobalKey".
- **A controller swapped in via `didUpdateWidget` leaked or was wrongly
  disposed.** Ownership is now recorded once, at creation.
- **`galleryIcon` was ignored** by the icon-style gallery button.
- The success/error `ValueNotifier` and its timer are disposed; every write is
  guarded by `mounted`.
- Controls are no longer swallowed by the preview's gesture recogniser — with
  tap-to-focus on (the default), tapping the torch previously did nothing.

### Fixed after internal review

A multi-agent adversarial review of the rewrite, before release, turned up a
further set of defects; all are fixed and pinned by tests.

- **The scanner crashed in any preview smaller than about 188x144 logical
  pixels.** `ScanWindowConfig.resolve` passed an unclamped `minWidth` as the
  lower limit of a `num.clamp` whose upper limit was the available width.
  `clamp` throws `ArgumentError` — not a debug-only assert — when the lower
  limit is the larger, so the whole scanner was replaced by an error widget.
  Triggered by an embedded scanner in a card or list tile, a desktop or web
  window narrowed past that threshold, Android split-screen, or a large
  horizontal safe area.
- **Swapping `controller` left the preview driving the disposed one.**
  `MobileScanner` captures its controller in a `late final` field, so it never
  saw the new one. The preview now remounts on a controller swap.
- **Every control became untappable when the scan window reached the bottom of
  the preview** — a short landscape screen, or `ScanWindowShape.fullPreview`.
  The control cluster was pinned below the window, so it collapsed to zero
  height. It is now anchored to the bottom and sized to its own content.
- **The overlay threw when its animation configuration changed.**
  `SingleTickerProviderStateMixin` does not release its claim when a ticker is
  disposed, so rebuilding the controller asserted.
- **Batch mode overshot `maxScans`** when one capture carried more barcodes
  than the remaining budget, and `onScanComplete` could fire more than once
  per session.
- **`ScanValidators.matches` rejected values its pattern did match.**
  `matchAsPrefix` takes the first alternative that fits and never backtracks,
  so `RegExp('a|ab')` rejected `ab`. The pattern is now properly anchored, and
  its flags are preserved.
- **A gallery pick was silently discarded** when the session was paused or
  inside the continuous-mode cooldown, and it analysed with the wrong barcode
  formats when the caller supplied a controller.
- **A rejected barcode held in frame fired the rejection haptic on every
  detection callback** — a continuous buzz. Rejections are now throttled by
  `scanCooldown`.
- **`mailto:` and `sms:` URIs were form-encoded**, so a space reached the mail
  or SMS client as a literal `+`.
- **`actionUri` returned an unopenable relative URI** for a URL payload with
  no scheme, so the result sheet offered an "Open" action that could not work.
- **Two stacked scanner routes both reclaimed the camera on resume.** Only the
  visible route does now.
- The lens control went stale after a camera flip; it re-probes when the
  camera direction changes.
- A long plain-text payload pushed the result sheet's action buttons off
  screen.
- The control strip no longer swallows tap-to-focus in the gaps between
  buttons, and wraps instead of overflowing at large text scales.
- `ScanWindowConfig.copyWith` could not clear a `builder`, so a builder-based
  config could never go back to a shape. Added `clearBuilder`.
- Corrected the capability matrix: the web backend **does** report barcode
  corners (that is what its scan-window filter is built on), so
  `showBarcodeHighlights` works there. Also corrected doc comments on
  `AiBarcodeScanner.embedded`, `appBarBuilder` and `analyzeImage`.

### Added

- **`AiBarcodeScannerController`** — a facade over the camera and the scan
  session: `start`/`stop`/`pause`, `pauseScanning`/`resumeScanning`,
  `toggleTorch`/`setTorch`, `switchCamera`/`switchLens`/`useCloseRangeLens`,
  `setZoomScale`/`resetZoomScale`, `setFocusPoint`, `analyzeImage`, batch
  `collect`/`clearCollected`, plus `state` and the `barcodes` stream.
  `.raw` reaches the underlying `MobileScannerController`.
- **Full `mobile_scanner` parity as widget parameters**: `formats`,
  `detectionSpeed`, `detectionTimeoutMs`, `facing`, `lensType`,
  `cameraResolution`, `torchEnabled`, `autoStart`, `autoZoom`, `invertImage`,
  `initialZoom`, `returnImage`, `webBarcodeReader`,
  `webBarcodeLibraryScriptUrl`.
- **`showAiBarcodeScanner` and `showAiBarcodeScannerBatch`** — open a scanner
  and get the result back in one line.
- **`AiBarcodeScanner.embedded`** — the scanner without a `Scaffold`, for
  dropping into a page you already have.
- **Scan modes**: `single`, `continuous` (with `scanCooldown`) and `batch`
  (with `maxScans` and `onScanComplete`).
- **`ScannerTheme`** — a palette for the scanner chrome, with
  `ScannerTheme.fromColorScheme` for brand matching. Overlay colours are now
  nullable and fall back to it.
- **`ScannerLabels`** — every user-visible string, overridable, with English
  defaults and no `intl` dependency.
- **`ScanWindowConfig`** — declarative scan window sizing: `auto`, `square`,
  `wide`, `tall`, `fullPreview` or a builder, with min/max bounds that keep the
  reticle sane on tablets and desktop.
- **`ScannerFeedbackConfig`** — configurable haptics and sound, a
  `ScannerFeedbackConfig.silent` preset, and an `onFeedback` hook for your own
  scanner beep.
- **`ScanValidators`** — `formats`, `types`, `contains`, `startsWith`,
  `matches`, `url`, `length`, combined with `all` / `either`.
- **`BarcodeFormatSets`** — curated presets: `qrOnly`, `twoDimensional`,
  `retail`, `logistics`, `documents`.
- **`ScannerPlatformSupport`** — the per-platform capability matrix. Controls
  the platform or device cannot back now hide themselves: no torch on macOS, no
  camera flip on a single-camera device, no gallery on the web, no lens button
  unless the device reports more than one lens.
- **Barcode presentation helpers** — `bestValue`, `typeLabel`, `typeIcon`,
  `actionUri`, `boundingBox`, `fields` (structured Wi-Fi, contact, calendar,
  geo, SMS, email and driver-licence payloads), and `BarcodeFormat.displayName`.
- **`BarcodeResultSheet`** — a ready-made sheet that renders the structured
  payload with copy, open and share actions.
- **Tap-to-focus with an animated focus ring**, implemented against the
  preview's own box rather than the screen.
- **Zoom slider**, **lens switching** and a **close** control, as
  `ScannerAction.zoom`, `.lens` and `.close`.
- **Detected-barcode highlights** (`showBarcodeHighlights`).
- **On-screen guidance** that changes after `idleHintDelay` when nothing has
  been detected.
- **Accessibility**: semantics labels and tooltips on every control, reduced
  motion honoured, scrollable control strip at large text scales.
- **Responsive layout**: controls form a row under the reticle on a portrait
  preview and a trailing column on a landscape or desktop one.
- `onScannerStarted`, `onError`, `onOpenSettings`, `onZoomChanged`,
  `onTorchChanged`, `onClose`, `onGalleryScanError` callbacks.
- A test suite (102 tests) covering the control-visibility regression, the
  detection pipeline, batch limits, rejection throttling, the scan-window
  coordinate space and its degenerate cases, small and landscape layouts,
  large text scales, capability gating, controller swapping, lifecycle and
  ownership.

### Changed

- **Breaking:** `controller` takes an `AiBarcodeScannerController`. Use
  `AiBarcodeScannerController.fromMobileScanner(existing)` to wrap one you
  already have, or drop the controller entirely and pass the camera options to
  the widget.
- **Breaking:** `galleryButtonText` → `labels: ScannerLabels(galleryButton: …)`.
- **Breaking:** `setPortraitOrientation` → `preferredOrientations`.
- **Breaking:** `onCustomImagePicker` → `imagePicker`, which only chooses the
  file.
- **Breaking:** `child` is drawn *in addition to* the controls, not instead of
  them.
- **Breaking:** `overlayBuilder` receives the resolved `scanWindow`.
- **Breaking:** `ScannerOverlayConfig.backgroundBlurColor` →
  `backgroundColor`; colour fields are nullable.
- **Breaking:** the default `detectionSpeed` is `noDuplicates`, which suits a
  scanner screen that closes on the first result.
- Default icons are Material rather than Cupertino.
- `ErrorBuilder` → `ScannerErrorView`.
- The dropped `universal_platform` dependency is replaced by `kIsWeb` and
  `defaultTargetPlatform`.
- `mobile_scanner` `>=7.4.0 <8.0.0`; `image_picker` `>=1.1.2 <2.0.0` (a loose
  lower bound so the package still resolves on Flutter 3.29–3.37).
- SDK floor: Dart 3.7.0, Flutter 3.29.0, iOS 15.0, macOS 12.0.
- The example app is rewritten and its Android project modernised to the current
  Flutter template (Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, compileSdk 36, NDK
  r28, Kotlin DSL).
- CI now analyses with `--fatal-infos`, checks formatting with `dart format`
  (`flutter format` no longer exists), runs the tests, scores with `pana`, and
  builds the example for Android, Web, iOS and macOS.

## 7.1.0

- Added child parameter to AiBarcodeScanner
- Bump version to 7.1.0 and update dependencies: mobile_scanner to ^7.1.2 and image_picker to ^1.2.0.
- Introduce a new GalleryButtonType.none option for the gallery button.
- Add support for custom image picker functionality in AiBarcodeScanner and GalleryButton.
- Update your iOS deployment target from 12.0 to 13.0 across multiple files.

## 7.0.0

**Improvements:**

- Added comprehensive documentation for supported barcode formats including PDF417
- Updated example to demonstrate PDF417 format configuration
- Enhanced README with format configuration examples
- Added Windows platform support documentation and runtime checks
- Added scanning accuracy and best practices documentation
- Added troubleshooting sections for common issues:
  - iOS CocoaPods dependency conflicts
  - Scanner crashes and black screen issues
  - Web mobile compatibility limitations
  - Distance scanning accuracy limitations
- Updated example to show proper navigation patterns for auto-closing scanner
- Added orientation handling improvements with `restoreOrientationsOnClose` parameter
- Fixed RenderFlex overflow in DraggableSheet widget

**Documentation:**

- Added comprehensive troubleshooting guide
- Added platform support limitations documentation
- Enhanced usage examples with best practices
- Added known limitations section for dependency-related issues
- [Major changes in AiBarcodeScanner class with new parameters and ui improvements, read the migration guide for more details](https://github.com/itsarvinddev/barcode_scanner/blob/master/MIGRATION_GUIDE.md).

## 6.0.1

**BREAKING CHANGES BY [MOBILE_SCANNER](https://pub.dev/packages/mobile_scanner):**

```
- [iOS] iOS 15.5.0 is now the minimum supported iOS version.
- [iOS] Updates MLKit to version 7.0.0.
- [iOS] Updates the minimum supported XCode version to 15.3.0.

Improvements:

- [MacOS] Added the corners and size information to barcode results.
- [MacOS] Added support for `analyzeImage`.
- [MacOS] Added a Privacy Manifest.
- [web] Added the size information to barcode results.
- [web] Added the video output size information to barcode capture.
- Added support for barcode formats to image analysis.
- Updated the scanner to report any scanning errors that were encountered during processing.
- Introduced a new getter `hasCameraPermission` for the `MobileScannerState`.
- Fixed a bug in the lifecycle handling sample. Now instead of checking `isInitialized`,
  the sample recommends using `hasCameraPermission`, which also guards against camera permission errors.
- Updated the behavior of `returnImage` to only determine if the camera output bytes should be sent.
- Updated the behavior of `BarcodeCapture.size` to always be provided when available, regardless of `returnImage`.
- [iOS] Excluded the `armv7` architecture, which is unsupported by MLKit 7.0.0.
- Added a new `onDetectError` error handler to the `MobileScanner` widget, for use with `onDetect`.

Bugs fixed:

- Fixed a bug that would cause the scanner to emit an error when it was already started. Now it ignores any calls to start while it is starting.
- [MacOS] Fixed a bug that prevented the `anaylzeImage()` sample from working properly.
- Fixed a bug that would cause onDetect to not handle errors.
```

## 6.0.0

- Dependency updates
- mobile_scanner: ^6.0.1
- setPortraitOrientation bool added. Now you can set the orientation.

## 5.2.2

- dependency updates

## 5.2.1

- dependency updates

## 5.1.1+1

- Readme updated
- gallery button hide option added

## 5.1.1

**BREAKING CHANGES:**

- mobile_scanner: ^5.1.1

## 3.4.1

- Jump to 3.4.1 to match the version of mobile_scanner
- Dependency updates
- mobile_scanner: ^3.4.1
- readme updated
- topics added
- Major changes in AiBarcodeScanner class
- allowDuplicates, hintMargin, hintPadding, hintBackgroundColor, errorText and successText removed
- hintWidget => bottomBar
- hintText => bottomBarText
- hintTextStyle => bottomBarTextStyle
- appBar added

## 0.0.7-dev.1

- error widget fixed

## 0.0.7

- Dependency updates
- validateText and validateType deprecated removed

## 0.0.6

- Readme updated

## 0.0.5

- [#43](https://github.com/mohesu/barcode_scanner/pull/43) added, Thanks to @MahmoudKhalid
- Readme updated
- mobile_scanner: ^3.2.0 added
- Added validator property, Deprecated validateText and validateType by @MahmoudKhalid
- Added onDispose property by @MahmoudKhalid

## 0.0.4

- mobile_scanner: ^3.0.0 added
- [#25](https://github.com/mohesu/barcode_scanner/issues/25) fixed
- [#32](https://github.com/mohesu/barcode_scanner/issues/32) added, Thanks to @Abhinav-Satija

## 0.0.2+1

- multi scan bug fixed

## 0.0.2

- Dependency updates
- mobile_scanner: ^3.0.0-beta.1

## 0.0.1+1

- Documentation updated

## 0.0.1

- Initial release.
- Added a button to turn the LED on and off.
- Added a button to flip the camera.
- Added a hint text.
- Added a barcode validator.
- Added a QR overlay.
