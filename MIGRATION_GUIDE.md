# Migration Guide

## 7.x → 8.0.0

Version 8 is a rewrite. Almost every fix in it required changing behaviour that
7.x got wrong, so the breaks are deliberate — but the common path got *shorter*,
not longer, and most apps need a one-line change or none at all.

If you only ever wrote this, nothing changes:

```dart
AiBarcodeScanner(
  onDetect: (capture) => handle(capture),
)
```

### At a glance

| 7.x | 8.0.0 |
| --- | --- |
| `controller: MobileScannerController(...)` | `controller: AiBarcodeScannerController(...)`, or pass the camera options directly to `AiBarcodeScanner` |
| `galleryButtonText: '…'` | `labels: ScannerLabels(galleryButton: '…')` |
| `setPortraitOrientation: true` | `preferredOrientations: [DeviceOrientation.portraitUp]` |
| `onCustomImagePicker: (validator, onDetect, controller) async {…}` | `imagePicker: (context) async => path` |
| `galleryIcon: CupertinoIcons.photo` (default) | `galleryIcon: Icons.photo_library_outlined` (default) |
| `child:` replaced the built-in controls | `child:` is drawn *in addition to* them |
| `ScannerOverlayConfig(backgroundBlurColor: …)` | `ScannerOverlayConfig(backgroundColor: …)` |
| overlay colours were non-nullable | overlay colours are nullable and fall back to `ScannerTheme` |
| `overlayBuilder: (context, constraints, controller, isSuccess)` | `overlayBuilder: (context, constraints, controller, scanWindow, isSuccess)` |
| scan window always restricted detection | `restrictDetectionToScanWindow` (default `false`) |
| `errorBuilder`'s default widget was `ErrorBuilder` | `ScannerErrorView` |

---

### 1. The controller is now `AiBarcodeScannerController`

7.x took a raw `MobileScannerController`. 8.0.0 takes a facade that adds the
operations a scanner screen actually needs — pausing *detection* without
stopping the camera, cycling lenses, batch collection — and keeps the raw
controller reachable at `.raw`.

**Most of the time you no longer need a controller at all.** Every camera option
is a parameter on the widget:

```dart
// Before
AiBarcodeScanner(
  controller: MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    torchEnabled: true,
  ),
  onDetect: handle,
)

// After
AiBarcodeScanner(
  formats: const [BarcodeFormat.qrCode],
  detectionSpeed: DetectionSpeed.noDuplicates,
  torchEnabled: true,
  onDetect: handle,
)
```

When you do want to hold a controller:

```dart
final controller = AiBarcodeScannerController(
  formats: const [BarcodeFormat.qrCode],
);

AiBarcodeScanner(controller: controller, onDetect: handle);
```

And if you already have a `MobileScannerController` from elsewhere:

```dart
AiBarcodeScanner(
  controller: AiBarcodeScannerController.fromMobileScanner(existing),
  onDetect: handle,
)
```

> Passing both a `controller` and camera options such as `formats` now trips an
> assertion in debug builds, because 7.x silently discarded them.

### 2. Strings moved to `ScannerLabels`

```dart
// Before
AiBarcodeScanner(galleryButtonText: 'Choose a photo')

// After
AiBarcodeScanner(
  labels: ScannerLabels(galleryButton: 'Choose a photo'),
)
```

`ScannerLabels` covers every user-visible string — tooltips, hints, error copy,
permission copy — and each field has an English default, so partial translations
are fine.

### 3. Orientation is no longer touched by default

7.x locked portrait by default and, on dispose, called
`SystemChrome.setPreferredOrientations(DeviceOrientation.values)` — which
**unlocked every orientation for the whole app**, permanently clobbering a lock
set in `main()`.

8.0.0 does nothing unless you ask:

```dart
// Before
AiBarcodeScanner(setPortraitOrientation: true)

// After
AiBarcodeScanner(
  preferredOrientations: const [DeviceOrientation.portraitUp],
  // Only applied because preferredOrientations was set.
  restoreOrientationsOnDispose: DeviceOrientation.values,
)
```

### 4. The custom image picker got simpler

You now override only *how the file is chosen*; the scanner still runs the
picked image through the same validation, feedback and overlay pipeline.

```dart
// Before
AiBarcodeScanner(
  onCustomImagePicker: (validator, onDetect, controller) async {
    final path = await myPicker();
    final capture = await controller.analyzeImage(path);
    if (capture != null && (validator?.call(capture) ?? true)) {
      onDetect?.call(capture);
    }
  },
)

// After
AiBarcodeScanner(
  imagePicker: (context) async => myPicker(),
  onGalleryScanError: (error, stack) => report(error),
)
```

### 5. `child` no longer replaces the controls

In 7.x, passing `child` removed the torch and camera-flip buttons. In 8.0.0 it
is simply stacked over the preview. To remove controls, say so:

```dart
AiBarcodeScanner(
  enabledActionButtons: const {},
  galleryButtonType: GalleryButtonType.none,
  child: myOverlay,
)
```

### 6. `GalleryButtonType.none` hides only the gallery button

This was [#176](https://github.com/itsarvinddev/barcode_scanner/issues/176): in
7.x it hid the torch and camera-flip buttons too. Gallery visibility and control
visibility are now independent.

### 7. The scan window is guidance, not a filter, by default

7.x always passed the scan window to the platform. On Android that means a
barcode must be **entirely** inside the rectangle — and any barcode for which ML
Kit reports no corner points is dropped outright. That is why
[#166](https://github.com/itsarvinddev/barcode_scanner/issues/166) could not scan
a barcode that was plainly visible in the reticle.

8.0.0 draws the reticle but does not restrict detection. Opt back in when you
need the user to aim at one of several visible codes:

```dart
AiBarcodeScanner(restrictDetectionToScanWindow: true)
```

The window itself is now described declaratively and computed from the
**preview's** box rather than the screen:

```dart
AiBarcodeScanner(
  scanWindowConfig: const ScanWindowConfig(
    shape: ScanWindowShape.wide,   // auto | square | wide | tall | fullPreview
    maxWidth: 420,                 // keeps the reticle sane on tablets
    alignment: Alignment(0, -0.1),
  ),
)
```

An explicit `scanWindow: Rect` still works and still overrides the config.

### 8. Overlay colours are nullable, and there is a theme

`ScannerOverlayConfig`'s colour fields are now `Color?`. `null` means "take it
from the `ScannerTheme`", which is what makes a single top-level theme
consistent. Setting them works exactly as before.

One rename: `backgroundBlurColor` → `backgroundColor` (it also applies when the
blur is off).

```dart
AiBarcodeScanner(
  theme: ScannerTheme.fromColorScheme(Theme.of(context).colorScheme),
  overlayConfig: const ScannerOverlayConfig(
    scannerBorder: ScannerBorder.full,
    blurSigma: 0, // cheaper on low-end devices
  ),
)
```

### 9. `overlayBuilder` gained the scan window

```dart
// Before
overlayBuilder: (context, constraints, controller, isSuccess) => …

// After
overlayBuilder: (context, constraints, controller, scanWindow, isSuccess) => …
```

`scanWindow` is the exact rectangle the scanner is using, so a custom overlay
can never drift out of sync with it.

### 10. Icons default to Material, not Cupertino

7.x defaulted to `CupertinoIcons.*` without depending on `cupertino_icons`, so
apps that did not declare that package got tofu boxes
([#188](https://github.com/itsarvinddev/barcode_scanner/issues/188)). The
defaults are now `Icons.*`, which every app with `uses-material-design: true`
already bundles. Pass `galleryIcon`, `flashOnIcon` and friends to restore the
old glyphs — and add `cupertino_icons` to your own `pubspec.yaml` if you do.

### 11. SDK floor

`sdk: >=3.7.0 <4.0.0`, `flutter: >=3.29.0` — set by `mobile_scanner` 7.4.0.
iOS 15.0 and macOS 12.0 are the minimum deployment targets, set by Flutter 3.29+.

---

## 6.x → 7.x

The 7.x line consolidated the individual overlay styling parameters
(`borderColor`, `borderWidth`, `overlayColor`, `borderRadius`, `borderLength`,
`cutOutSize`, …) into a single `ScannerOverlayConfig` passed as `overlayConfig`,
removed the built-in `DraggableSheet` in favour of `bottomSheetBuilder`, and
replaced `hideGalleryButton`/`hideGalleryIcon` with the `galleryButtonType`
enum.

```dart
// 6.x
AiBarcodeScanner(
  borderColor: Colors.amber,
  borderWidth: 8,
  borderRadius: 20,
  successColor: Colors.greenAccent,
)

// 7.x and later
AiBarcodeScanner(
  overlayConfig: const ScannerOverlayConfig(
    borderColor: Colors.amber,
    borderRadius: 20,
    successColor: Colors.greenAccent,
  ),
)
```
