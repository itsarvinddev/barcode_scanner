/// How the scanner behaves once it detects a valid barcode.
enum ScanMode {
  /// Report the first accepted barcode, then stop detecting.
  ///
  /// The preview keeps running so the screen does not go black while you
  /// navigate away or validate the result. Call
  /// `AiBarcodeScannerController.resumeScanning` to scan again.
  single,

  /// Report every accepted barcode, throttled by
  /// `AiBarcodeScanner.scanCooldown`.
  continuous,

  /// Collect distinct barcodes until the user is done, or until
  /// `AiBarcodeScanner.maxScans` is reached, then report them all at once
  /// through `AiBarcodeScanner.onScanComplete`.
  batch,
}
