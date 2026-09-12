import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';

/// Shows how far the look can be pushed without writing a custom overlay:
/// a brand palette, translated copy, a full-border reticle and a slower sweep.
class ThemedScannerPage extends StatelessWidget {
  const ThemedScannerPage({required this.onResult, super.key});

  final void Function(Barcode? barcode, {String? note}) onResult;

  @override
  Widget build(BuildContext context) {
    return AiBarcodeScanner(
      // Derive the scanner palette from the app's own colour scheme.
      theme: ScannerTheme.fromColorScheme(
        Theme.of(context).colorScheme,
      ).copyWith(controlSize: 56, borderRadius: 28),
      overlayConfig: const ScannerOverlayConfig(
        scannerBorder: ScannerBorder.full,
        borderRadius: 28,
        lineThickness: 3,
        animationDuration: Duration(milliseconds: 2200),
        blurSigma: 6,
      ),
      scanWindowConfig: const ScanWindowConfig(
        shape: ScanWindowShape.square,
        widthFactor: 0.72,
        maxWidth: 320,
      ),
      labels: const ScannerLabels(
        scanHint: 'Line the code up inside the frame',
        scanHintIdle: 'Still nothing — try moving a little closer',
        galleryButton: 'Choose a photo',
        closeTooltip: 'Back',
      ),
      enabledActionButtons: const <ScannerAction>{
        ScannerAction.torch,
        ScannerAction.cameraSwitch,
        ScannerAction.gallery,
        ScannerAction.close,
      },
      galleryButtonType: GalleryButtonType.filled,
      onDetect: (capture) {
        onResult(capture.firstBarcode);
        Navigator.of(context).pop();
      },
    );
  }
}
