# AI Barcode Scanner

<p>
  <a href="https://pub.dev/packages/ai_barcode_scanner"><img src="https://img.shields.io/pub/v/ai_barcode_scanner.svg" alt="Pub Version"></a>
  <a href="https://github.com/sponsors/juliansteenbakker"><img src="https://img.shields.io/github/sponsors/juliansteenbakker?label=Sponsor%20mobile_scanner" alt="Sponsor"></a>
  <a href="https://github.com/itsarvinddev/barcode_scanner/blob/master/LICENSE"><img src="https://img.shields.io/github/license/itsarvinddev/barcode_scanner" alt="License"></a>
</p>

A complete, production-ready barcode scanner screen for Flutter, built on
[`mobile_scanner`](https://pub.dev/packages/mobile_scanner). Every camera
capability the underlying plugin has is exposed as a plain widget parameter, and
on top of that sits a scanner UI you would otherwise spend a sprint building:
a responsive reticle, capability-aware controls, haptics, permission recovery,
structured result rendering and full theming.

<img src="https://raw.githubusercontent.com/itsarvinddev/barcode_scanner/master/assets/ai_barcode_scanner.png" alt="">

```dart
final capture = await showAiBarcodeScanner(context);
print(capture?.barcodes.first.rawValue);
```

---

## Contents

- [Platform support](#platform-support)
- [Setup](#setup)
- [Usage](#usage)
- [Scan modes](#scan-modes)
- [The scan window](#the-scan-window)
- [Theming](#theming)
- [Localisation](#localisation)
- [Controls](#controls)
- [Feedback](#feedback)
- [Reading the result](#reading-the-result)
- [Permissions and errors](#permissions-and-errors)
- [Driving the scanner](#driving-the-scanner-programmatically)
- [Web](#web)
- [Using with material_ui (Flutter 3.47+)](#using-with-material_ui-flutter-347)
- [Full API](#full-api)
- [Troubleshooting](#troubleshooting)

---

## Platform support

| Android | iOS | macOS | Web | Windows | Linux |
| :-----: | :-: | :---: | :-: | :-----: | :---: |
|   ✅    | ✅  |  ✅   | ✅  |   ❌    |  ❌   |

Windows and Linux get a built-in "not supported on this platform" screen rather
than a crash. You can replace it with `unsupportedBuilder`.

Capabilities differ per platform, and the scanner **hides controls it cannot
back**: no torch button on macOS, no camera-flip on a single-camera device, no
zoom slider on the web. Query the matrix yourself with
`ScannerPlatformSupport.current`.

| Capability | Android | iOS | macOS | Web |
| --- | :-: | :-: | :-: | :-: |
| Camera scanning | ✅ | ✅ | ✅ | ✅ |
| Scan from gallery | ✅ | ✅¹ | ✅ | ✅³ |
| Scan window restriction | ✅ | ✅ | ✅ | ✅ |
| Torch | ✅ | ✅ | ❌ | ❌ |
| Zoom (pinch / slider) | ✅ | ✅ | ✅ | ❌ |
| Tap to focus | ✅ | ✅ | ❌ | ❌ |
| Lens selection | ✅² | ✅ | ❌ | ❌ |
| Auto zoom | ✅ | ❌ | ❌ | ❌ |
| Invert image | ✅ | ❌ | ❌ | ❌ |
| Frame bytes (`returnImage`) | ✅ | ✅ | ✅ | ❌ |
| Barcode geometry / highlights | ✅ | ✅ | ✅ | ✅ |
| Choose web detection backend | ❌ | ❌ | ❌ | ✅ |

¹ Not on the iOS Simulator — a simulator restriction, not a platform one.
² Android reports lens types but CameraX cannot select physical sub-cameras, so
`useCloseRangeLens()` always resolves to the normal lens there; use
`autoZoom: true` instead.
³ Since 8.1.0, through a built-in zxing-wasm decoder that is downloaded the
first time an image is scanned; see [Scanning images on the web](#scanning-images-on-the-web).

### Minimum versions

| | Minimum |
| --- | --- |
| Dart | 3.7.0 |
| Flutter | 3.29.0 |
| Android | minSdk 23, compileSdk 36, Android Gradle Plugin 8.9.1+, Kotlin Gradle Plugin 2.x |
| iOS | 15.0 |
| macOS | 12.0 |

The Android row is set by `mobile_scanner` 7.4: CameraX 1.6 refuses to build
with an older Android Gradle Plugin or compileSdk, and the plugin configures
Kotlin through the Kotlin Gradle Plugin 2 DSL. Apps created from an older
Flutter template — Flutter 3.29's uses AGP 8.7, Kotlin 1.8 and minSdk 21 — have
to raise these in `android/settings.gradle(.kts)` and
`android/app/build.gradle(.kts)`.

---

## Setup

### Install

```yaml
dependencies:
  ai_barcode_scanner: ^8.1.0
```

The whole of `mobile_scanner` is re-exported, so one import is enough:

```dart
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
```

### iOS — `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan barcodes.</string>
<!-- Only if you keep the gallery button. -->
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to scan barcodes from images.</string>
```

### macOS

Tick **Camera** under Signing & Capabilities, or add to both `.entitlements`
files:

```xml
<key>com.apple.security.device.camera</key>
<true/>
<!-- Only if you keep the gallery button. -->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

### Android

Nothing required — `mobile_scanner` declares the camera permission itself. Two
optional knobs in `android/gradle.properties`:

```properties
# Download the ML Kit model on first use instead of bundling it.
# Saves 3–10 MB of app size.
dev.steenbakker.mobile_scanner.useUnbundled=true
```

### Web

Nothing required. The detection library is fetched on first use; see
[Web](#web) to choose a backend, host it yourself, or set up a Content Security
Policy.

---

## Usage

### The one-liner

```dart
final capture = await showAiBarcodeScanner(context);
if (capture != null) {
  print(capture.barcodes.first.rawValue);
}
```

Returns `null` if the user backs out. `showAiBarcodeScannerBatch` is the
equivalent for collecting several codes.

### The widget

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => AiBarcodeScanner(
      onDetect: (capture) {
        final barcode = capture.barcodes.first;
        Navigator.of(context).pop(barcode.rawValue);
      },
    ),
  ),
);
```

### Camera options are plain parameters

You do not need a controller to configure the camera:

```dart
AiBarcodeScanner(
  formats: const [BarcodeFormat.qrCode, BarcodeFormat.ean13],
  detectionSpeed: DetectionSpeed.noDuplicates,
  facing: CameraFacing.back,
  torchEnabled: false,
  autoZoom: true,          // Android
  invertImage: false,      // Android — reads white-on-black codes
  initialZoom: 0.2,
  cameraResolution: const Size(1920, 1080), // Android
  returnImage: false,
  onDetect: handle,
)
```

**Naming your formats is the single cheapest accuracy and battery win
available** — an unrestricted detector runs every decoder over every frame.
There are presets:

```dart
AiBarcodeScanner(formats: BarcodeFormatSets.retail)   // EAN, UPC, Code 128, DataBar
AiBarcodeScanner(formats: BarcodeFormatSets.qrOnly)
AiBarcodeScanner(formats: BarcodeFormatSets.logistics)
AiBarcodeScanner(formats: BarcodeFormatSets.documents) // PDF417, QR, Aztec, DataMatrix
```

### Validating a scan

A rejected barcode flashes the reticle red, fires the rejection haptic, and
never reaches `onDetect`:

```dart
AiBarcodeScanner(
  validator: ScanValidators.all([
    ScanValidators.formats({BarcodeFormat.qrCode}),
    ScanValidators.url(allowedHosts: {'example.com'}),
  ]),
  onDetect: handle,
)
```

Built-in validators: `formats`, `types`, `contains`, `startsWith`, `matches`,
`url`, `length`, plus `all` / `either` to combine them. Or write your own —
it is just `bool Function(BarcodeCapture)`.

### Embedding in your own page

```dart
SizedBox(
  height: 320,
  child: AiBarcodeScanner.embedded(
    onDetect: handle,
  ),
)
```

No `Scaffold`, no app bar, no default chrome — the surrounding page owns the
layout.

---

## Scan modes

```dart
AiBarcodeScanner(scanMode: ScanMode.single)      // default
AiBarcodeScanner(scanMode: ScanMode.continuous)
AiBarcodeScanner(scanMode: ScanMode.batch)
```

- **`single`** — report the first accepted barcode, then stop detecting. The
  preview keeps running so the screen does not go black while you navigate or
  validate. Call `controller.resumeScanning()` to scan again.
- **`continuous`** — report every accepted barcode, throttled by `scanCooldown`
  (default 1.2 s).
- **`batch`** — collect distinct barcodes until the user is done or `maxScans`
  is reached, then fire `onScanComplete` with the lot.

```dart
AiBarcodeScanner(
  scanMode: ScanMode.batch,
  maxScans: 10,
  onScanComplete: (barcodes) => Navigator.pop(context, barcodes),
)
```

---

## The scan window

The reticle is **guidance, not a filter**. By default a barcode is accepted
wherever it appears in the preview, because restricting detection has sharp
edges on Android: the barcode must be *entirely* inside the rectangle, and any
barcode for which ML Kit reports no corner points is dropped outright.

Opt in when several codes are visible and the user should aim at one:

```dart
AiBarcodeScanner(restrictDetectionToScanWindow: true)
```

The window is computed from the **preview's** box — not the screen — so an app
bar, a bottom sheet or a notch can never push the reticle out of alignment with
the area being read.

```dart
AiBarcodeScanner(
  scanWindowConfig: const ScanWindowConfig(
    shape: ScanWindowShape.wide,     // auto | square | wide | tall | fullPreview
    widthFactor: 0.9,
    maxWidth: 420,                   // keeps it sane on tablets and desktop
    alignment: Alignment(0, -0.08),
    padding: EdgeInsets.all(24),
  ),
)
```

`ScanWindowShape.auto` (the default) picks a square when only 2D symbologies are
enabled and a landscape rectangle otherwise. For anything the config cannot
describe:

```dart
scanWindowConfig: ScanWindowConfig.builder(
  (context, constraints) => Rect.fromLTWH(0, 0, constraints.maxWidth, 200),
)
```

---

## Theming

```dart
AiBarcodeScanner(
  theme: ScannerTheme.fromColorScheme(Theme.of(context).colorScheme),
)
```

`ScannerTheme.fromColors(primary: …, surface: …)` derives the same theme from
individual colours — the way to theme the scanner in an app built on
[`material_ui`](#using-with-material_ui-flutter-347), whose `ColorScheme`
`fromColorScheme` cannot accept.

Or set tokens individually. Anything left `null` keeps a built-in default that
is tuned for legibility over a live camera feed:

```dart
AiBarcodeScanner(
  theme: const ScannerTheme(
    reticleColor: Color(0xFFFFFFFF),
    reticleSuccessColor: Color(0xFF32D74B),
    reticleErrorColor: Color(0xFFFF453A),
    controlBackgroundColor: Color(0x59FFFFFF),
    controlActiveBackgroundColor: Color(0xFFFFD60A),
    controlSize: 48,
    overlayBlurSigma: 4,
    borderRadius: 20,
  ),
)
```

The reticle's own geometry and animation live in `ScannerOverlayConfig`:

```dart
AiBarcodeScanner(
  overlayConfig: const ScannerOverlayConfig(
    scannerBorder: ScannerBorder.corner,          // corner | full | none
    scannerAnimation: ScannerAnimation.center,    // center | fullWidth | none
    scannerOverlayBackground: ScannerOverlayBackground.blur, // blur | dim | none
    cornerLength: 44,
    borderRadius: 24,
    animationDuration: Duration(milliseconds: 1500),
    showBarcodeHighlights: true,   // outline every detected barcode
    respectReduceMotion: true,     // drop the sweep when the OS asks
  ),
)
```

`ScannerOverlayConfig.minimal()` is the cheapest configuration to render — no
blur, no animation — and the right choice for an embedded scanner or a low-end
device.

---

## Localisation

Every user-visible string is overridable, with English defaults, and no `intl`
dependency:

```dart
AiBarcodeScanner(
  labels: ScannerLabels(
    scanHint: context.l10n.pointAtBarcode,
    galleryButton: context.l10n.pickFromGallery,
    permissionDeniedTitle: context.l10n.cameraNeeded,
    permissionDeniedMessage: context.l10n.cameraNeededBody,
    openSettingsButton: context.l10n.openSettings,
    barcodeFieldLabels: {'wifi.ssid': context.l10n.network},
  ),
)
```

Anything you leave out keeps its default, so partial translations are fine.

---

## Controls

```dart
AiBarcodeScanner(
  enabledActionButtons: const {
    ScannerAction.torch,
    ScannerAction.cameraSwitch,
    ScannerAction.gallery,
    ScannerAction.lens,     // cycle normal / wide / zoom lenses
    ScannerAction.zoom,     // zoom slider
    ScannerAction.close,
  },
  galleryButtonType: GalleryButtonType.filled,  // filled | icon | none
)
```

The controls lay themselves out along the preview's long axis: a row beneath the
scan window when the preview is portrait, a column pinned to the trailing edge
when it is landscape or on desktop. Each button carries a semantics label and a
tooltip, and the whole strip scrolls rather than overflowing at large text
scales.

Gestures, all on by default:

```dart
AiBarcodeScanner(
  tapToFocus: true,            // with an animated focus ring
  enablePinchToZoom: true,
  pinchZoomSensitivity: 1.0,
  doubleTapToResetZoom: true,
)
```

### Scanning from the gallery

The gallery button opens `image_picker` and reads the picked image with the
platform's own decoder — ML Kit on Android, Vision on iOS and macOS, and a
built-in zxing-wasm decoder on the web (see
[Scanning images on the web](#scanning-images-on-the-web)). A picked image runs
through the same `validator`, feedback and overlay flash as a camera detection.

To choose the image yourself, pass `galleryImagePicker`. You override only *how
the image is chosen*: return it as a `ScannerImage`, or `null` if the user
cancelled. Wrap whatever your picker hands you — an `XFile`, a path, or bytes:

```dart
// An XFile — from image_picker, file_selector, camera, desktop_drop, … Here, a
// photo taken on the spot instead of one from the gallery.
AiBarcodeScanner(
  galleryImagePicker: (context) async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    return file == null ? null : ScannerImage.xFile(file);
  },
)

// A file path.
AiBarcodeScanner(
  galleryImagePicker: (context) async {
    final String? path = await myFilePicker();
    return path == null ? null : ScannerImage.path(path);
  },
)

// Encoded bytes: a web file input, the clipboard, a download, an asset.
// (Uint8List is from dart:typed_data.)
AiBarcodeScanner(
  galleryImagePicker: (context) async {
    final Uint8List? bytes = await myBytesPicker();
    return bytes == null ? null : ScannerImage.bytes(bytes, name: 'code.png');
  },
)
```

Bytes are an **encoded image file** — any format the platform can decode (PNG,
JPEG, WebP; HEIC on Android, iOS, macOS and Safari) — not raw pixels, and they
work on every platform, the web included. On Android, iOS and macOS,
whose decoders only open files, they are written to a temporary file for the
analysis and deleted straight afterwards. (`ImagePicker` and `XFile` come from
`package:image_picker/image_picker.dart`; add `image_picker` to your own
`pubspec.yaml` to import it.)

To hear about picks and failures:

```dart
AiBarcodeScanner(
  onGalleryImagePick: (image) => debugPrint('Picked $image'), // null = cancelled
  onGalleryScanError: (error, stack) => report(error),
)
```

To replace the *decoding* as well — a web app whose Content Security Policy
cannot allow jsDelivr, an offline deployment, a server-side decoder — pass
`galleryImageAnalyzer`. It is used for every picked image on every platform,
receives the formats the scanner is restricted to (empty means all), and
returns `null` or an empty capture when nothing was found. What it returns
still goes through `validator` and feedback:

```dart
AiBarcodeScanner(
  galleryImageAnalyzer: (image, formats) async {
    final bytes = await image.readAsBytes();
    return myDecoder.decode(bytes, formats);
  },
)
```

> `imagePicker` and `onImagePick` from 8.0 still work, but are deprecated in
> favour of `galleryImagePicker` and `onGalleryImagePick` and will be removed in
> 9.0.0. See the
> [migration guide](https://github.com/itsarvinddev/barcode_scanner/blob/master/MIGRATION_GUIDE.md#80--81-optional).

---

## Feedback

```dart
AiBarcodeScanner(
  feedback: const ScannerFeedbackConfig(
    detectHaptic: ScannerHaptic.medium,
    rejectHaptic: ScannerHaptic.heavy,
    controlHaptic: ScannerHaptic.selection,
    playSystemSound: true,
  ),
)
```

For a real scanner beep, silence the built-ins and hook up your own player:

```dart
AiBarcodeScanner(
  feedback: ScannerFeedbackConfig.silent(
    onFeedback: (event) {
      if (event == ScannerFeedbackEvent.detect) audioPlayer.play(beep);
    },
  ),
)
```

---

## Reading the result

`mobile_scanner` returns a rich, typed payload — Wi-Fi networks, contacts,
calendar events, driver licences — and this package makes it presentable:

```dart
onDetect: (capture) {
  final barcode = capture.barcodes.first;

  barcode.bestValue;          // displayValue, falling back to rawValue
  barcode.typeLabel;          // "Wi-Fi", "Contact", "Link", …
  barcode.typeIcon;           // a matching Material icon
  barcode.format.displayName; // "QR Code", "EAN-13", …
  barcode.actionUri;          // mailto:, tel:, sms:, geo:, https: — or null
  barcode.boundingBox;        // extent of Barcode.corners, in camera space

  for (final field in barcode.fields) {
    print('${field.label}: ${field.value}');   // Network: Home
  }
}
```

There is a ready-made sheet too:

```dart
onDetect: (capture) => BarcodeResultSheet.show(
  context,
  barcode: capture.barcodes.first,
  onOpen: (uri) => launchUrl(uri),   // your launcher; no dependency added here
),
```

---

## Permissions and errors

The scanner distinguishes the three failures a user can act on — permission
denied, no usable camera, and everything else — and offers retry plus an
"Open settings" hook. The package deliberately has no permissions dependency:

```dart
AiBarcodeScanner(
  onOpenSettings: () => openAppSettings(), // e.g. from permission_handler
  onError: (error) => report(error),
)
```

Replace the screen entirely with `errorBuilder` if you prefer.

---

## Driving the scanner programmatically

```dart
final controller = AiBarcodeScannerController(
  formats: const [BarcodeFormat.qrCode],
);

AiBarcodeScanner(
  controller: controller,
  onDetect: (capture) async {
    controller.pauseScanning();          // freeze detection, keep the preview
    final ok = await verifyOnServer(capture);
    if (!ok) controller.resumeScanning();
  },
);
```

The facade covers `start` / `stop` / `pause`, `toggleTorch` / `setTorch`,
`switchCamera` / `switchLens` / `useCloseRangeLens`, `setZoomScale` /
`resetZoomScale`, `setFocusPoint`, `analyzeImage` / `analyzeScannerImage`,
batch `collect` / `clearCollected`, and exposes `state` (a
`ValueListenable<MobileScannerState>`) and the `barcodes` stream.
`controller.raw` is the underlying `MobileScannerController` for anything not
wrapped.

To scan an image your app already has — from a share intent, the clipboard, a
download — without going through the gallery button:

```dart
final capture = await controller.analyzeScannerImage(
  ScannerImage.bytes(pngBytes),
  formats: const [BarcodeFormat.qrCode],
);
```

It accepts any `ScannerImage` and works on the web too; `null` and an empty
capture both mean nothing was found. `analyzeImage(path)` is the path-only
form.

Already have a `MobileScannerController`?

```dart
AiBarcodeScannerController.fromMobileScanner(existing)
```

---

## Web

The detection backend is selectable:

```dart
AiBarcodeScanner(
  webBarcodeReader: WebBarcodeReader.auto, // auto | barcodeDetector | zxingWasm | zxingJs
)
```

- `auto` (default) uses the browser's native `BarcodeDetector` where available
  (Chrome/Edge 83+, Safari 17+) and falls back to zxing-wasm.
- `zxingWasm` works everywhere modern, including Firefox, and fetches about
  1.1 MB of WebAssembly (roughly 460 KB compressed) on first use.

If a content security policy or an air-gapped deployment forbids the CDN, host
the script yourself:

```dart
AiBarcodeScanner(
  webBarcodeReader: WebBarcodeReader.zxingWasm,
  webBarcodeLibraryScriptUrl: '/assets/zxing-wasm/index.js',
)
```

With `auto` or `zxingWasm`, that is zxing-wasm's IIFE reader build
(`dist/iife/reader/index.js` from the `zxing-wasm@3.1.3` package), and the same
copy is used to [scan picked images](#scanning-images-on-the-web). zxing-wasm
still downloads its WebAssembly binary from `fastly.jsdelivr.net`, for the
camera and picked images alike. A `zxingJs` mirror is a different library that
cannot read picked images, so with one the gallery button stays hidden on the
web unless you pass `galleryImageAnalyzer`.

### Scanning images on the web

Since 8.1.0 the gallery button works in the browser too, and appears there by
default. `mobile_scanner` cannot read still images on the web yet
([juliansteenbakker/mobile_scanner#1494](https://github.com/juliansteenbakker/mobile_scanner/issues/1494)),
so this package does it itself: the browser decodes the picked file — any format
it can display, with EXIF orientation applied — and zxing-wasm reads the pixels.

- **The first scanned image downloads the decoder.** zxing-wasm 3.1.3 is loaded
  from jsDelivr: a 38 KB script (13 KB compressed) from `cdn.jsdelivr.net` (or
  from `webBarcodeLibraryScriptUrl`, if you [host it yourself](#web)), then its
  WebAssembly binary from `fastly.jsdelivr.net` — roughly 460 KB compressed,
  1.1 MB uncompressed, cached by the browser afterwards. Nothing is fetched
  until an image is scanned, and nothing at all if the camera has already
  loaded zxing-wasm (`WebBarcodeReader.zxingWasm`, or `auto` in a browser
  without `BarcodeDetector`). If a download fails — the connection drops
  during the first scan — that scan fails, and the next one tries again.
- **A Content Security Policy has to allow it:**

  ```text
  script-src  https://cdn.jsdelivr.net 'wasm-unsafe-eval';
  connect-src https://fastly.jsdelivr.net blob:;
  ```

  `blob:` is how a picked file is read back — in the browser, `XFile.path` is a
  `blob:` URL. If you pass `data:` URLs to `analyzeImage` or
  `ScannerImage.path`, add `data:` to `connect-src` as well, and the origin of
  any `http(s)` image URL you pass. When the decoder cannot load, or the image
  cannot be read, the scan fails with a `MobileScannerBarcodeException` that
  says what to allow, reported to `onGalleryScanError`.
- **Offline, self-hosted or locked-down apps** can pass
  [`galleryImageAnalyzer`](#scanning-from-the-gallery) to decode images their
  own way — a server endpoint, a decoder of their own. The built-in decoder is
  then never loaded. The camera may still need zxing-wasm, though: in a
  browser without `BarcodeDetector`, such as Firefox, `auto` falls back to it,
  so point `webBarcodeLibraryScriptUrl` at a copy you host as well.
- **The gallery button is part of the live scanner.** It appears once the
  camera has started, and not over the error screen that replaces the
  preview when the camera cannot start — on a computer without a webcam, or
  when camera access is denied. For a flow that has to work without a camera,
  call `AiBarcodeScannerController.analyzeScannerImage` from a button of your
  own: it does not need a running camera.
- **Pickers that return bytes work.** A browser never exposes a file path, so a
  custom `galleryImagePicker` should return `ScannerImage.bytes` or
  `ScannerImage.xFile`.
- **The controller works too.** `analyzeScannerImage` accepts any
  `ScannerImage`, and `analyzeImage(path)` accepts a `blob:` or `data:` URL, or
  an `http(s):` URL the page is allowed to fetch. Only `controller.raw.analyzeImage`
  — `mobile_scanner`'s own — still throws `UnsupportedError`.

Not wanted on the web? Hide the button there:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

AiBarcodeScanner(
  galleryButtonType: kIsWeb ? GalleryButtonType.none : GalleryButtonType.filled,
)
```

---

## Using with material_ui (Flutter 3.47+)

Flutter now publishes Material and Cupertino as the separate
[`material_ui`](https://pub.dev/packages/material_ui) and
[`cupertino_ui`](https://pub.dev/packages/cupertino_ui) packages (usable from
Flutter 3.44), while `package:flutter/material.dart` still ships in the SDK.
The 8.x line of this package still imports `package:flutter/material.dart`, and
works with both kinds of app:

- **Apps on `flutter/material`** — any app that has not migrated — need nothing,
  and see no change.
- **Apps on `material_ui`** work **without `MaterialUiCompatibilityBridge`**,
  in any locale. The scanner supplies the `flutter/material` localizations it
  needs to its own subtree when your app does not, keeping your app's locale and
  text direction. `BarcodeResultSheet.show` presents the sheet on a route of its
  own, and confirms a copy on the button itself when there is no
  `ScaffoldMessenger` to show a snack bar. As with the bridge, supplying those
  localizations loads your app's `LocalizationsDelegate`s once more when the
  scanner mounts; a delegate whose `load` is truly asynchronous delays the
  scanner's first frame until it completes.

What the scanner cannot see in a `material_ui` app is your `Theme` — its
`ThemeData` is a different type from `flutter/material`'s. Without a
`ScannerTheme` the scanner uses its built-in palette, which is tuned for a
camera feed. To match your brand, pass your colours to `ScannerTheme.fromColors`,
which derives the same theme `ScannerTheme.fromColorScheme` would:

```dart
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:material_ui/material_ui.dart';

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme; // material_ui's ColorScheme
    return AiBarcodeScanner(
      theme: ScannerTheme.fromColors(
        primary: scheme.primary,
        onPrimary: scheme.onPrimary,
        surface: scheme.surface,
        onSurface: scheme.onSurface,
        error: scheme.error,
      ),
      onDetect: (capture) => Navigator.of(context).pop(capture),
    );
  }
}
```

Every string the scanner renders comes from `ScannerLabels`, including the
result sheet's barrier label, `dismissSheetLabel`. The few that come from the
framework instead — the text selection toolbar, and some built-in tooltips —
use the SDK's English defaults in a `material_ui` app. If you would rather the
scanner followed your `Theme` and your app's Material localizations
automatically, `MaterialUiCompatibilityBridge` still works: with it in place,
the scanner picks up the theme and localizations it maps across.

**The package is planned to migrate to `material_ui` in 9.0.0.** That takes
theme and localizations away from apps still on `flutter/material` — there is
no reverse bridge — and `material_ui` needs Flutter 3.44 or later, so, as
Flutter advises for this migration, it waits for a major version.

---

## Full API

| Parameter | Type | Default | Notes |
| --- | --- | --- | --- |
| `onDetect` | `void Function(BarcodeCapture)?` | — | Fired for accepted detections |
| `validator` | `bool Function(BarcodeCapture)?` | — | Return `false` to reject |
| `onScanComplete` | `void Function(List<Barcode>)?` | — | Batch mode only |
| `onDetectError` | `void Function(Object, StackTrace)?` | — | |
| `controller` | `AiBarcodeScannerController?` | — | Camera options are ignored when set |
| `formats` | `List<BarcodeFormat>` | `[]` | Empty = every format |
| `detectionSpeed` | `DetectionSpeed` | `noDuplicates` | |
| `detectionTimeoutMs` | `int` | `250` | Ignored unless `detectionSpeed` is `normal` |
| `facing` | `CameraFacing` | `back` | |
| `lensType` | `CameraLensType` | `any` | |
| `cameraResolution` | `Size?` | — | Android |
| `torchEnabled` / `autoStart` | `bool` | `false` / `true` | |
| `autoZoom` / `invertImage` | `bool` | `false` | Android |
| `initialZoom` | `double?` | — | `0`–`1` |
| `returnImage` | `bool` | `false` | Frame bytes on `BarcodeCapture.image` |
| `webBarcodeReader` | `WebBarcodeReader?` | — | Web |
| `webBarcodeLibraryScriptUrl` | `String?` | — | Web |
| `scanMode` | `ScanMode` | `single` | |
| `maxScans` | `int?` | — | Batch mode |
| `scanCooldown` | `Duration` | `1200 ms` | Continuous mode |
| `resultFlashDuration` | `Duration` | `1000 ms` | |
| `useAppLifecycleState` | `bool` | `true` | Stops/restarts with the app |
| `preferredOrientations` | `List<DeviceOrientation>?` | `null` | `null` leaves your app's policy alone |
| `restoreOrientationsOnDispose` | `List<DeviceOrientation>?` | all | Only if `preferredOrientations` is set |
| `tapToFocus` / `enablePinchToZoom` / `doubleTapToResetZoom` | `bool` | `true` | |
| `pinchZoomSensitivity` | `double` | `1.0` | |
| `showScanHint` / `idleHintDelay` | `bool` / `Duration` | `true` / `6 s` | |
| `theme` | `ScannerTheme?` | — | |
| `labels` | `ScannerLabels` | English | |
| `overlayConfig` | `ScannerOverlayConfig` | default | |
| `scanWindowConfig` | `ScanWindowConfig` | `auto` | |
| `restrictDetectionToScanWindow` | `bool` | `false` | |
| `scanWindow` | `Rect?` | — | Overrides `scanWindowConfig` |
| `feedback` | `ScannerFeedbackConfig` | default | |
| `enabledActionButtons` | `Set<ScannerAction>` | gallery, flip, torch | |
| `galleryButtonType` | `GalleryButtonType` | `filled` | |
| `galleryIcon` / `cameraSwitchIcon` / `flashOnIcon` / `flashOffIcon` / `lensIcon` / `closeIcon` | `IconData` | Material | |
| `fit` | `BoxFit` | `cover` | |
| `appBarBuilder` / `bottomSheetBuilder` / `bottomNavigationBarBuilder` | builders | — | Full-screen only |
| `overlayBuilder` / `errorBuilder` / `placeholderBuilder` / `unsupportedBuilder` | builders | — | |
| `actions` / `child` | `List<Widget>?` / `Widget?` | — | `child` adds to the controls |
| `galleryImagePicker` | `Future<ScannerImage?> Function(BuildContext)?` | `image_picker` | Return a path, bytes or `XFile` as a `ScannerImage`; `null` = cancelled |
| `onGalleryImagePick` | `void Function(ScannerImage?)?` | — | Every pick; `null` = cancelled |
| `galleryImageAnalyzer` | `Future<BarcodeCapture?> Function(ScannerImage, List<BarcodeFormat>)?` | built-in | Replaces image decoding on every platform |
| `onGalleryScanError` | `void Function(Object, StackTrace)?` | — | |
| `imagePicker` / `onImagePick` | callbacks | — | Deprecated in 8.1.0: use `galleryImagePicker` / `onGalleryImagePick` |
| `onDispose` / `onClose` / `onScannerStarted` / `onError` / `onOpenSettings` | callbacks | — | |
| `onZoomChanged` / `onTorchChanged` | callbacks | — | |

---

## Troubleshooting

### "App must support 16 KB memory page sizes" from the Play Console

That warning is about **ELF segment alignment**, not file size — every `.so` in
a 64-bit ABI must have `p_align >= 16384`. It applies to apps targeting Android
15 (API 35) and above, and Google Play blocks non-compliant updates from
**1 February 2027**.

The native code in your APK comes from `mobile_scanner`, not from this package
(which has none). `com.google.mlkit:barcode-scanning:17.3.0` — used by every
`mobile_scanner` from 6.0.11 onward — is 16 KB aligned on `arm64-v8a` and
`x86_64`; the 17.2.0 that older versions pulled in was not. So:

1. Make sure you resolve `mobile_scanner >= 7.4.0`. A stale lockfile or pub
   cache is the usual culprit:
   ```bash
   flutter clean
   rm -rf ~/.pub-cache/hosted/pub.dev/mobile_scanner-*
   flutter pub get
   ```
2. Build with **AGP 8.9.1+** (required by `mobile_scanner` 7.4) and **NDK
   r27+** (r28 is the Flutter 3.29+ default), which align everything the
   toolchain produces; see [Minimum versions](#minimum-versions).
3. `armeabi-v7a` and `x86` staying at 4 KB is expected and irrelevant — the
   requirement is 64-bit only.

### "Your app uses plugins that apply Kotlin Gradle Plugin (KGP): mobile_scanner"

Fixed upstream in `mobile_scanner` 7.4.1, which this package requires — so a
fresh `flutter pub get` resolves it and the warning is gone. If you have a
lockfile pinning an older version, run `flutter pub upgrade mobile_scanner`.

**Run `flutter clean` after that upgrade.** 7.4.1 moved the plugin's Gradle
files from Groovy to the Kotlin DSL, and a build directory left over from 7.4.0
fails with `cannot find symbol: class MobileScannerPlugin` — the stale outputs
are reused and the plugin's Kotlin sources are never recompiled. It looks like a
broken release; it is just a dirty build.

For the curious: it was always a false positive. The guarded
`apply plugin: 'kotlin-android'` never actually ran on AGP 9, but Flutter
detects KGP usage by *text-scanning* the plugin's `build.gradle` with a regex,
so a line-initial `apply plugin` matched whether or not its enclosing `if` was
taken. 7.4.1 converts those files to the Kotlin DSL, which the Groovy regex no
longer matches.

### Black preview, or the camera never comes back from the background

Leave `useAppLifecycleState: true` (the default). This package handles the
lifecycle itself — `MobileScanner` only does so for a controller it created,
and a wrapper always supplies one, which is why 7.x never actually paused.

### A barcode is clearly inside the reticle but does not scan

Check you have not set `restrictDetectionToScanWindow: true`. Android requires
the barcode to be *entirely* inside the window and drops barcodes with no
reported corner points. The default is not to restrict.

### Scans are slow or wrong

Name your formats (`formats:` or a `BarcodeFormatSets` preset). Poor light,
glare and distance are ML Kit limitations; `autoZoom: true` helps on Android and
`controller.useCloseRangeLens()` helps on iOS.

### Icons render as empty boxes

Fixed in 8.0.0 — the defaults are Material icons now. If you pass
`CupertinoIcons.*` yourself, add `cupertino_icons` to your own `pubspec.yaml`,
since icon fonts are only bundled from your app's direct dependencies.

### "Could not load the zxing-wasm barcode decoder" when scanning an image on the web

The page could not download the decoder: it is offline, or its Content Security
Policy blocks jsDelivr. Allow the hosts listed under
[Scanning images on the web](#scanning-images-on-the-web), or pass
`galleryImageAnalyzer` to decode images without it. "zxing-wasm could not load
its WebAssembly binary" is the same problem one step later, with
`fastly.jsdelivr.net`; the next scan downloads it again.

### "Could not read the picked image" or "Could not read the image at …" on the web

The browser refused to read the image. In the browser a picked file is a
`blob:` URL, so a Content Security Policy has to allow `blob:` in
`connect-src`. An image passed to `analyzeImage` or `ScannerImage.path` as a
`data:` URL needs `data:` there too, and one at an `http(s)` URL needs that
URL's origin; the message names the source to allow. The same message also
appears when the URL is simply unreachable, or an object URL was revoked.

### "No MaterialLocalizations found" in an app built on `material_ui`

Upgrade to 8.1.0 or later, which works in `material_ui` apps without
`MaterialUiCompatibilityBridge`; see
[Using with material_ui](#using-with-material_ui-flutter-347).

### CocoaPods conflicts on iOS

```bash
flutter clean
cd ios && rm Podfile.lock && pod install --repo-update
```

---

## Under the hood

This package is a wrapper around
[`mobile_scanner`](https://pub.dev/packages/mobile_scanner) by Julian
Steenbakker, which does the actual work: CameraX + ML Kit on Android,
AVFoundation + Vision on iOS and macOS, and `BarcodeDetector`/zxing on the web.
For platform-specific behaviour and the raw data model, its documentation is the
reference — and everything it exports is available through this package's single
import.

## Contributing

Issues and pull requests are welcome.

<a href="https://github.com/itsarvinddev/barcode_scanner/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=itsarvinddev/barcode_scanner" />
</a>

## Acknowledgements

Built on the excellent `mobile_scanner` package. A huge thanks to Julian
Steenbakker and everyone who contributes to it.
