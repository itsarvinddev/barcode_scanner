/// How the "scan an image from the gallery" affordance is presented.
enum GalleryButtonType {
  /// Do not show a gallery affordance.
  ///
  /// This only hides the gallery button. The other controls — torch, camera
  /// flip, lens, close — are unaffected; use
  /// `AiBarcodeScanner.enabledActionButtons` to control those.
  none,

  /// A round icon button, shown alongside the other controls.
  icon,

  /// A wide filled button with a label, shown below the scan window.
  filled,
}
