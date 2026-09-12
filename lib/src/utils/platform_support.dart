import 'package:flutter/foundation.dart';

/// Static, compile-time-ish description of what the underlying `mobile_scanner`
/// implementation can actually do on the platform the app is running on.
///
/// The wrapper uses this to hide controls that would be dead buttons — a torch
/// toggle on the macOS build, an "invert image" switch on iOS — instead of
/// letting the user tap something that silently does nothing.
///
/// The values mirror the support matrix published by `mobile_scanner` 7.4.x.
/// They are deliberately conservative: when a capability is only partially
/// supported, it is reported as unsupported.
@immutable
class ScannerPlatformSupport {
  const ScannerPlatformSupport._({
    required this.isSupported,
    required this.analyzeImage,
    required this.returnImage,
    required this.scanWindow,
    required this.torch,
    required this.zoom,
    required this.tapToFocus,
    required this.lensType,
    required this.autoZoom,
    required this.invertImage,
    required this.cameraResolution,
    required this.barcodeCorners,
    required this.webBarcodeReader,
  });

  /// Whether `mobile_scanner` has a camera implementation for this platform at
  /// all. `false` on Windows and Linux.
  final bool isSupported;

  /// Whether [MobileScannerController.analyzeImage] works, which is what backs
  /// the "scan from gallery" button.
  ///
  /// Note that this is `true` for iOS as a platform but always fails on the
  /// iOS *Simulator*, which is a simulator restriction rather than a platform
  /// one and therefore cannot be detected here.
  final bool analyzeImage;

  /// Whether `BarcodeCapture.image` can contain the camera frame bytes.
  final bool returnImage;

  /// Whether restricting detection to a sub-rectangle of the preview works.
  final bool scanWindow;

  /// Whether a torch/flashlight can be toggled.
  ///
  /// Even where this is `true`, the individual device may not have a torch;
  /// use `MobileScannerState.torchState == TorchState.unavailable` for that.
  final bool torch;

  /// Whether zoom (pinch, slider, programmatic) is available.
  final bool zoom;

  /// Whether tapping the preview can set a focus/exposure point.
  final bool tapToFocus;

  /// Whether specific lenses (wide / normal / zoom) can be selected.
  final bool lensType;

  /// Whether the camera can automatically zoom towards a distant barcode.
  final bool autoZoom;

  /// Whether frames can be colour-inverted to read white-on-black codes.
  final bool invertImage;

  /// Whether a desired camera resolution can be requested.
  final bool cameraResolution;

  /// Whether `Barcode.corners` is populated, which is what the detected-barcode
  /// highlight overlay is drawn from.
  ///
  /// True on every supported platform; kept as a capability because the value
  /// is what gates the highlight overlay, and an unsupported platform reports
  /// false along with everything else.
  final bool barcodeCorners;

  /// Whether the web detection backend can be chosen.
  final bool webBarcodeReader;

  static const _unsupported = ScannerPlatformSupport._(
    isSupported: false,
    analyzeImage: false,
    returnImage: false,
    scanWindow: false,
    torch: false,
    zoom: false,
    tapToFocus: false,
    lensType: false,
    autoZoom: false,
    invertImage: false,
    cameraResolution: false,
    barcodeCorners: false,
    webBarcodeReader: false,
  );

  static const _android = ScannerPlatformSupport._(
    isSupported: true,
    analyzeImage: true,
    returnImage: true,
    scanWindow: true,
    torch: true,
    zoom: true,
    tapToFocus: true,
    lensType: true,
    autoZoom: true,
    invertImage: true,
    cameraResolution: true,
    barcodeCorners: true,
    webBarcodeReader: false,
  );

  static const _ios = ScannerPlatformSupport._(
    isSupported: true,
    analyzeImage: true,
    returnImage: true,
    scanWindow: true,
    torch: true,
    zoom: true,
    tapToFocus: true,
    lensType: true,
    autoZoom: false,
    invertImage: false,
    cameraResolution: false,
    barcodeCorners: true,
    webBarcodeReader: false,
  );

  static const _macos = ScannerPlatformSupport._(
    isSupported: true,
    analyzeImage: true,
    returnImage: true,
    scanWindow: true,
    torch: false,
    zoom: true,
    tapToFocus: false,
    lensType: false,
    autoZoom: false,
    invertImage: false,
    cameraResolution: false,
    barcodeCorners: true,
    webBarcodeReader: false,
  );

  static const _web = ScannerPlatformSupport._(
    isSupported: true,
    // `analyzeImage` is not implemented by the web backend.
    analyzeImage: false,
    returnImage: false,
    // Supported since mobile_scanner 7.2.1: the web backend filters detections
    // to the scan window in Dart, using the corner points below.
    scanWindow: true,
    torch: false,
    zoom: false,
    tapToFocus: false,
    lensType: false,
    autoZoom: false,
    invertImage: false,
    cameraResolution: true,
    // The zxing-wasm and BarcodeDetector backends both report corner points —
    // that is what the web scan-window filter is built on.
    barcodeCorners: true,
    webBarcodeReader: true,
  );

  /// The capabilities of the platform this app is currently running on.
  static ScannerPlatformSupport get current {
    if (kIsWeb) return _web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _android;
      case TargetPlatform.iOS:
        return _ios;
      case TargetPlatform.macOS:
        return _macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return _unsupported;
    }
  }

  /// A human readable name for the current platform, used in the
  /// "not supported" screen.
  static String get currentPlatformName {
    if (kIsWeb) return 'Web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  /// Whether the current platform is a desktop platform.
  ///
  /// Desktop gets a different control layout: larger hit targets are
  /// unnecessary, and there is no "flip camera" affordance worth showing.
  static bool get isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Whether the current platform is a touch-first mobile platform.
  static bool get isMobile {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Whether device orientation can be locked.
  ///
  /// `SystemChrome.setPreferredOrientations` is a no-op outside Android and
  /// iOS, so the scanner does not attempt it elsewhere.
  static bool get supportsOrientationLock => isMobile;
}
