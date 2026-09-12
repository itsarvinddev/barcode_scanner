/// The quick-action controls the scanner can show.
///
/// Pass the ones you want to `AiBarcodeScanner.enabledActionButtons`. Controls
/// that the current platform or device cannot support are hidden even when
/// they are listed here, so a macOS build never shows a torch button.
enum ScannerAction {
  /// Flip between the front and back camera.
  cameraSwitch,

  /// Toggle the flashlight.
  torch,

  /// Pick an image from the gallery and scan it.
  gallery,

  /// Cycle through the device's lenses (normal, wide, zoom).
  ///
  /// Only shown when the device actually reports more than one lens.
  lens,

  /// A slider for the camera zoom.
  zoom,

  /// Dismiss the scanner.
  ///
  /// Only meaningful for the full-screen scanner; it pops the current route,
  /// or calls `AiBarcodeScanner.onClose` when you provide one.
  close,
}
